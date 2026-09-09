import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../data/support_repository.dart';
import '../data/support_ticket.dart';

class SupportTicketDetailScreen extends ConsumerWidget {
  const SupportTicketDetailScreen({required this.ticketId, super.key});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanTicketId = ticketId.trim();
    final hasValidTicketId =
        cleanTicketId.isNotEmpty &&
        cleanTicketId != '-' &&
        cleanTicketId.toLowerCase() != 'null' &&
        cleanTicketId.toLowerCase() != 'undefined';

    if (!hasValidTicketId) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBackHeader(title: 'Support'),
        body: Padding(
          padding: EdgeInsets.all(20),
          child: AppEmptyState(
            icon: Icons.support_agent_outlined,
            title: 'Ticket unavailable',
            message: 'This support ticket has no valid reference.',
          ),
        ),
      );
    }

    final ticketAsync = ref.watch(supportTicketDetailProvider(cleanTicketId));
    final loadedTicket = ticketAsync.asData?.value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBackHeader(
        title: 'Support conversation',
        subtitle: loadedTicket == null ? cleanTicketId : loadedTicket.id,
        action: loadedTicket == null
            ? null
            : OmcStatusBadge(label: loadedTicket.status),
      ),
      body: ticketAsync.when(
        data: (ticket) {
          if (ticket == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: AppEmptyState(
                icon: Icons.support_agent_outlined,
                title: 'Ticket unavailable',
                message:
                    'This support ticket may have been removed or is no longer available.',
              ),
            );
          }

          return _SupportTicketChatBody(ticket: ticket);
        },
        loading: () => const _TicketDetailLoadingView(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: AppErrorState.fromError(
            error: error,
            fallbackTitle: 'Ticket unavailable',
            fallbackMessage:
                'Support ticket details could not be loaded right now.',
            onRetry: () =>
                ref.invalidate(supportTicketDetailProvider(cleanTicketId)),
          ),
        ),
      ),
    );
  }
}

class _SupportTicketChatBody extends ConsumerStatefulWidget {
  const _SupportTicketChatBody({required this.ticket});

  final SupportTicket ticket;

  @override
  ConsumerState<_SupportTicketChatBody> createState() =>
      _SupportTicketChatBodyState();
}

class _SupportTicketChatBodyState
    extends ConsumerState<_SupportTicketChatBody> {
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  final _dirtyFormController = DirtyFormController();

  static const _refreshInterval = Duration(seconds: 4);

  bool _isSendingReply = false;
  bool _isUpdatingStatus = false;
  Timer? _refreshTimer;
  _PickedSupportAttachment? _pickedAttachment;
  String? _uploadedAttachmentUrlForRetry;

  SupportTicket get ticket => widget.ticket;

  @override
  void initState() {
    super.initState();
    _replyController.addListener(_markReplyDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markTicketRead();
      _scrollToBottomSoon();
    });
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refreshTicket());
  }

  void _markReplyDirty() => _dirtyFormController.markDirty();

  void _refreshTicket() {
    if (!mounted || _isSendingReply || _isUpdatingStatus) return;
    ref.invalidate(supportTicketDetailProvider(ticket.id));
    ref.invalidate(supportTicketsProvider);
    ref.invalidate(supportUnreadCountProvider);
  }

  Future<void> _markTicketRead() async {
    try {
      await ref
          .read(supportRepositoryProvider)
          .markSupportTicketRead(ticket.id);
      ref.invalidate(supportUnreadCountProvider);
      ref.invalidate(supportTicketsProvider);
    } catch (_) {
      // Read-state acknowledgement must not block ticket access.
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _replyController.removeListener(_markReplyDirty);
    _replyController.dispose();
    _scrollController.dispose();
    _dirtyFormController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(authControllerProvider).capabilities;
    final isInternal = capabilities.isInternal;
    final canReply =
        ticket.canReply && (!isInternal || capabilities.canReplySupportTickets);
    final canUpdateStatus =
        ticket.canUpdateStatus && capabilities.canUpdateSupportTicketStatus;
    final canViewInternalDetails =
        isInternal && capabilities.canViewInternalNotes;

    return UnsavedChangesGuard(
      controller: _dirtyFormController,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(supportTicketDetailProvider(ticket.id));
                ref.invalidate(supportTicketsProvider);
                await _markTicketRead();
              },
              child: ListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  _TicketInfoCard(ticket: ticket),
                  if (canViewInternalDetails) ...[
                    const SizedBox(height: 12),
                    _CustomerInformationCard(ticket: ticket),
                  ],
                  if (canUpdateStatus) ...[
                    const SizedBox(height: 12),
                    _SupportAdminStatusCard(
                      ticket: ticket,
                      isUpdating: _isUpdatingStatus,
                      onStatusSelected: _isUpdatingStatus
                          ? null
                          : (status) => _updateTicketStatus(context, status),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Semantics(
                    header: true,
                    child: Text(
                      'Conversation',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (ticket.messages.isEmpty)
                    const _EmptyConversationBubble()
                  else
                    for (final message in ticket.messages) ...[
                      _ChatBubble(
                        message: message,
                        isMine: isInternal
                            ? !message.isFromCustomer
                            : message.isFromCustomer,
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
          _SupportChatComposer(
            controller: _replyController,
            attachment: _pickedAttachment,
            enabled: canReply && !ticket.isClosed && !_isSendingReply,
            isSending: _isSendingReply,
            isClosed: ticket.isClosed,
            onPickAttachment: _pickAttachment,
            onRemoveAttachment: () {
              _dirtyFormController.markDirty();
              setState(() {
                _pickedAttachment = null;
                _uploadedAttachmentUrlForRetry = null;
              });
            },
            onSend: () => _sendReply(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachment() async {
    if (_isSendingReply) return;

    final messenger = ScaffoldMessenger.of(context);
    final capabilities = ref.read(authControllerProvider).capabilities;
    final canReply =
        ticket.canReply &&
        (!capabilities.isInternal || capabilities.canReplySupportTickets);

    if (!canReply) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your role cannot reply to this support ticket.'),
        ),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );

      if (!mounted) return;

      final file = result?.files.single;
      if (file == null) return;

      if (file.size <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Selected file is empty.')),
        );
        return;
      }

      if (file.size > 10 * 1024 * 1024) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Attachment must be 10 MB or smaller.')),
        );
        return;
      }

      if ((file.path == null || file.path!.trim().isEmpty) &&
          (file.bytes == null || file.bytes!.isEmpty)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Selected file data is unavailable. Choose it again.',
            ),
          ),
        );
        return;
      }

      _dirtyFormController.markDirty();
      setState(() {
        _uploadedAttachmentUrlForRetry = null;
        _pickedAttachment = _PickedSupportAttachment(
          name: file.name,
          sizeInBytes: file.size,
          path: file.path,
          bytes: file.bytes,
          extension: _extensionFor(file.name),
        );
      });
    } catch (error) {
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Attachment unavailable',
        fallbackMessage: 'Attachment could not be selected right now.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _sendReply(BuildContext context) async {
    if (_isSendingReply) return;

    final message = _replyController.text.trim();
    final attachment = _pickedAttachment;
    final messenger = ScaffoldMessenger.of(context);

    final capabilities = ref.read(authControllerProvider).capabilities;
    final canReply =
        ticket.canReply &&
        (!capabilities.isInternal || capabilities.canReplySupportTickets);

    if (!canReply) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your role cannot reply to this support ticket.'),
        ),
      );
      return;
    }

    if (ticket.isClosed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Closed tickets cannot receive replies.')),
      );
      return;
    }

    if (message.isEmpty && attachment == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Write a message or attach a file first.'),
        ),
      );
      return;
    }

    final repository = ref.read(supportRepositoryProvider);

    _dirtyFormController.beginSubmitting();
    setState(() => _isSendingReply = true);

    try {
      String? attachmentUrl = _uploadedAttachmentUrlForRetry;
      if (attachment != null && attachmentUrl == null) {
        attachmentUrl = await repository.uploadSupportTicketAttachment(
          ticketId: ticket.id,
          filePath: attachment.path,
          fileBytes: attachment.bytes,
          fileName: attachment.name,
          sizeBytes: attachment.sizeInBytes,
        );
        _uploadedAttachmentUrlForRetry = attachmentUrl;
      }

      await repository.addSupportTicketReply(
        ticketId: ticket.id,
        message: message,
        attachmentUrl: attachmentUrl,
        attachmentName: attachment?.name,
        attachmentType: attachment?.extension,
      );

      if (!context.mounted) return;

      _replyController.clear();
      setState(() {
        _pickedAttachment = null;
        _uploadedAttachmentUrlForRetry = null;
      });
      _dirtyFormController.submissionSucceeded();
      ref.invalidate(supportTicketDetailProvider(ticket.id));
      ref.invalidate(supportTicketsProvider);
      ref.invalidate(supportUnreadCountProvider);
      await ref.read(supportTicketDetailProvider(ticket.id).future);
      if (!mounted) return;
      _markTicketRead();
      _scrollToBottomSoon();
    } catch (error) {
      _dirtyFormController.submissionFailed();
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Message not sent',
        fallbackMessage:
            'Message could not be sent right now. Your text and attachment were retained.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isSendingReply = false);
    }
  }

  Future<void> _updateTicketStatus(BuildContext context, String status) async {
    if (_isUpdatingStatus) return;

    final messenger = ScaffoldMessenger.of(context);
    final capabilities = ref.read(authControllerProvider).capabilities;

    if (!ticket.canUpdateStatus || !capabilities.canUpdateSupportTicketStatus) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your role cannot update support ticket status.'),
        ),
      );
      return;
    }

    final repository = ref.read(supportRepositoryProvider);
    setState(() => _isUpdatingStatus = true);

    try {
      await repository.updateSupportTicketStatus(
        ticketId: ticket.id,
        status: status,
      );

      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text('Support ticket marked as $status.')),
      );
      ref.invalidate(supportTicketDetailProvider(ticket.id));
      ref.invalidate(supportTicketsProvider);
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Status not updated',
        fallbackMessage:
            'Support ticket status could not be updated right now.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _TicketInfoCard extends StatelessWidget {
  const _TicketInfoCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final linkedCase = ticket.referenceServiceRequest?.trim();

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 350 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      ticket.subject,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${ticket.id} · ${ticket.priority} priority',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
              final status = OmcStatusBadge(label: ticket.status);

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 10), status],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  status,
                ],
              );
            },
          ),
          if (ticket.message.trim().isNotEmpty && ticket.message.trim() != '-') ...[
            const SizedBox(height: 14),
            Text(
              ticket.message.trim(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (linkedCase != null && linkedCase.isNotEmpty) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => context.push(
                '/my-services/${Uri.encodeComponent(linkedCase)}',
              ),
              icon: const Icon(Icons.link_rounded),
              label: Text('Open linked case · $linkedCase'),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              if (ticket.raisedOnLabel?.trim().isNotEmpty == true)
                _MetaText(label: 'Opened', value: ticket.raisedOnLabel!.trim()),
              if (ticket.updatedAtLabel?.trim().isNotEmpty == true)
                _MetaText(label: 'Updated', value: ticket.updatedAtLabel!.trim()),
              if (ticket.assignedTo?.trim().isNotEmpty == true)
                _MetaText(label: 'Assigned', value: ticket.assignedTo!.trim()),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _CustomerInformationCard extends StatelessWidget {
  const _CustomerInformationCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final identity = _customerIdentity(ticket);
    final email = ticket.contactEmail?.trim();
    final phone = ticket.contactPhone?.trim();

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Semantics(
            header: true,
            child: Text(
              'Customer context',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppTheme.info.withValues(alpha: 0.08),
                child: Text(
                  _initials(identity),
                  style: const TextStyle(
                    color: AppTheme.info,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (email != null && email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      SelectableText(
                        email,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (phone != null && phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      SelectableText(
                        phone,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          _ContextRow(
            label: 'Case',
            value: ticket.referenceServiceRequest ?? 'Not linked',
          ),
          _ContextRow(
            label: 'Opened',
            value: ticket.raisedOnLabel ?? ticket.createdAtLabel ?? '—',
          ),
          _ContextRow(label: 'Updated', value: ticket.updatedAtLabel ?? '—'),
          _ContextRow(label: 'Ticket', value: ticket.id),
        ],
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;
          final labelWidget = Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          );
          final valueWidget = Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 3), valueWidget],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 82, child: labelWidget),
              const SizedBox(width: 10),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyConversationBubble extends StatelessWidget {
  const _EmptyConversationBubble();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: const Text(
        'No messages yet. Start the conversation from the reply box below.',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isMine});

  final SupportTicketMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    final maxWidth = largeText
        ? screenWidth * 0.94
        : (screenWidth * 0.84).clamp(220.0, 620.0);
    final bubbleColor = isMine
        ? AppTheme.info.withValues(alpha: 0.07)
        : Theme.of(context).colorScheme.surfaceContainerLow;
    final borderColor = isMine
        ? AppTheme.info.withValues(alpha: 0.16)
        : AppTheme.border;

    return Semantics(
      label:
          '${_authorLabel(message)}, ${message.createdAtLabel}. ${message.message}',
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      message.isFromCustomer
                          ? Icons.person_outline_rounded
                          : Icons.support_agent_rounded,
                      color: isMine ? AppTheme.info : AppTheme.textSecondary,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _authorLabel(message),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (message.createdAtLabel.trim().isNotEmpty &&
                        message.createdAtLabel != '-') ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.createdAtLabel,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (message.message.trim().isNotEmpty &&
                    message.message != '-') ...[
                  const SizedBox(height: 9),
                  Text(
                    message.message,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (message.hasAttachment) ...[
                  const SizedBox(height: 10),
                  _AttachmentTile(message: message),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _authorLabel(SupportTicketMessage message) {
    final author = message.author.trim();
    if (author.isEmpty || author == '-') {
      return message.isFromCustomer ? 'Customer' : 'OMC Team';
    }
    if (!message.isFromCustomer) return 'OMC Team';
    return author;
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.message});

  final SupportTicketMessage message;

  @override
  Widget build(BuildContext context) {
    final name = message.attachmentName ?? 'Attachment';
    final url = message.attachmentUrl ?? '';

    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: url.isEmpty ? null : () => _openAttachment(context, url),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.attach_file_rounded,
                color: AppTheme.info,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (message.attachmentType?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        message.attachmentType!.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (url.isNotEmpty)
                const Icon(
                  Icons.open_in_new_rounded,
                  color: AppTheme.textSecondary,
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAttachment(BuildContext context, String rawUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(_absoluteUrl(rawUrl));
    if (uri == null || !_isAllowedWebScheme(uri.scheme)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Attachment link is invalid.')),
      );
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;
      if (!opened) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Attachment could not be opened.')),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Attachment unavailable',
        fallbackMessage: 'Attachment could not be opened right now.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  bool _isAllowedWebScheme(String scheme) {
    final normalized = scheme.toLowerCase();
    return normalized == 'https' || normalized == 'http';
  }

  String _absoluteUrl(String value) {
    final clean = value.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    if (clean.startsWith('/')) return '${ApiConfig.baseUrl}$clean';
    return clean;
  }
}

class _SupportChatComposer extends StatelessWidget {
  const _SupportChatComposer({
    required this.controller,
    required this.attachment,
    required this.enabled,
    required this.isSending,
    required this.isClosed,
    required this.onPickAttachment,
    required this.onRemoveAttachment,
    required this.onSend,
  });

  final TextEditingController controller;
  final _PickedSupportAttachment? attachment;
  final bool enabled;
  final bool isSending;
  final bool isClosed;
  final VoidCallback onPickAttachment;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (attachment != null) ...[
              _PickedAttachmentPreview(
                attachment: attachment!,
                onRemove: enabled ? onRemoveAttachment : null,
              ),
              const SizedBox(height: 10),
            ],
            if (isClosed)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'This ticket is closed. Reopen it before adding a reply.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton.outlined(
                    onPressed: enabled ? onPickAttachment : null,
                    icon: const Icon(Icons.attach_file_rounded),
                    tooltip: 'Attach file',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Write a message…',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final canSend =
                          enabled &&
                          !isSending &&
                          (value.text.trim().isNotEmpty || attachment != null);

                      return Semantics(
                        button: true,
                        label: isSending ? 'Sending reply' : 'Send reply',
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: FilledButton(
                            onPressed: canSend ? onSend : null,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSending
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 21),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Text(
                'PDF, JPG, PNG, DOC or DOCX · Maximum 10 MB',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickedAttachmentPreview extends StatelessWidget {
  const _PickedAttachmentPreview({
    required this.attachment,
    required this.onRemove,
  });

  final _PickedSupportAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.attach_file_rounded,
            color: AppTheme.info,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _sizeLabel(attachment.sizeInBytes),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove attachment',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SupportAdminStatusCard extends StatelessWidget {
  const _SupportAdminStatusCard({
    required this.ticket,
    required this.isUpdating,
    required this.onStatusSelected,
  });

  final SupportTicket ticket;
  final bool isUpdating;
  final ValueChanged<String>? onStatusSelected;

  static const _statuses = <String>[
    'Open',
    'In Progress',
    'Waiting for Customer',
    'Resolved',
    'Closed',
  ];

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 350 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operational status',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              OmcStatusBadge(label: ticket.status),
            ],
          );
          final action = OutlinedButton.icon(
            onPressed: isUpdating || onStatusSelected == null
                ? null
                : () => _openStatusSheet(context),
            icon: isUpdating
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.tune_rounded),
            label: Text(isUpdating ? 'Updating' : 'Update status'),
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [identity, const SizedBox(height: 12), action],
            );
          }

          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }

  Future<void> _openStatusSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Semantics(
                header: true,
                child: Text(
                  'Update ticket status',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the current stage of this conversation.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              for (final status in _statuses)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  leading: Icon(
                    _statusIcon(status),
                    color: _statusColor(status),
                  ),
                  title: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing:
                      status.toLowerCase() == ticket.status.trim().toLowerCase()
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: _statusColor(status),
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(status),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null &&
        selected.trim().toLowerCase() != ticket.status.trim().toLowerCase()) {
      onStatusSelected?.call(selected);
    }
  }
}

class _TicketDetailLoadingView extends StatelessWidget {
  const _TicketDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 46,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Loading support conversation...',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickedSupportAttachment {
  const _PickedSupportAttachment({
    required this.name,
    required this.sizeInBytes,
    required this.path,
    required this.bytes,
    required this.extension,
  });

  final String name;
  final int sizeInBytes;
  final String? path;
  final Uint8List? bytes;
  final String extension;
}

IconData _statusIcon(String status) {
  final value = status.trim().toLowerCase();
  if (value.contains('progress')) return Icons.play_circle_outline_rounded;
  if (value.contains('waiting')) return Icons.hourglass_bottom_rounded;
  if (value.contains('resolved')) return Icons.verified_rounded;
  if (value.contains('closed')) return Icons.lock_outline_rounded;
  return Icons.radio_button_checked_rounded;
}

Color _statusColor(String status) {
  final value = status.trim().toLowerCase();
  if (value.contains('progress')) return AppTheme.info;
  if (value.contains('waiting')) return AppTheme.warning;
  if (value.contains('resolved') ||
      value.contains('closed') ||
      value.contains('complete')) {
    return AppTheme.success;
  }
  if (value.contains('cancel')) return AppTheme.textSecondary;
  return AppTheme.info;
}

String _customerIdentity(SupportTicket ticket) {
  for (final message in ticket.messages) {
    final author = message.author.trim();
    if (message.isFromCustomer &&
        author.isNotEmpty &&
        author != '-' &&
        !author.contains('@')) {
      return author;
    }
  }

  final email = ticket.contactEmail?.trim();
  if (email != null && email.isNotEmpty) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    return local
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}',
        )
        .join(' ');
  }

  return 'Customer';
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final initials = parts.map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'CU' : initials;
}

String _extensionFor(String fileName) {
  final clean = fileName.trim();
  if (!clean.contains('.')) return '';
  return clean.split('.').last.toLowerCase();
}

String _sizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

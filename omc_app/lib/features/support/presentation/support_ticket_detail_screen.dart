import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../data/support_repository.dart';
import '../data/support_ticket.dart';

class SupportTicketDetailScreen extends ConsumerWidget {
  const SupportTicketDetailScreen({required this.ticketId, super.key});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketAsync = ref.watch(supportTicketDetailProvider(ticketId));

    final loadedTicket = ticketAsync.asData?.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBackHeader(
        title: 'Support',
        subtitle: loadedTicket == null
            ? ticketId
            : '${loadedTicket.subject} • ${loadedTicket.id}',
        action: loadedTicket == null
            ? null
            : _StatusPill(status: loadedTicket.status, compact: true),
      ),
      body: ticketAsync.when(
        data: (ticket) {
          if (ticket == null) {
            return PremiumEmptyState(
              icon: Icons.support_agent_outlined,
              title: 'Ticket unavailable',
              message:
                  'Support ticket $ticketId could not be loaded right now.',
            );
          }

          return _SupportTicketChatBody(ticket: ticket);
        },
        loading: () => const _TicketDetailLoadingView(),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Ticket unavailable',
          message: _cleanError(error),
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

  bool _isSendingReply = false;
  bool _isUpdatingStatus = false;
  _PickedSupportAttachment? _pickedAttachment;

  SupportTicket get ticket => widget.ticket;

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
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

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(supportTicketDetailProvider(ticket.id));
              ref.invalidate(supportTicketsProvider);
            },
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              children: [
                _TicketInfoCard(ticket: ticket),
                if (canViewInternalDetails) ...[
                  const SizedBox(height: 12),
                  _CustomerInformationCard(ticket: ticket),
                ],
                if (canUpdateStatus) ...[
                  const SizedBox(height: 12),
                  _SupportAdminStatusBar(
                    ticket: ticket,
                    isUpdating: _isUpdatingStatus,
                    onStatusSelected: _isUpdatingStatus
                        ? null
                        : (status) => _updateTicketStatus(context, status),
                  ),
                ],
                const SizedBox(height: 20),
                const _ConversationHeader(),
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
                    const SizedBox(height: 10),
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
          onRemoveAttachment: () => setState(() => _pickedAttachment = null),
          onSend: () => _sendReply(context),
        ),
      ],
    );
  }

  Future<void> _pickAttachment() async {
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

      setState(() {
        _pickedAttachment = _PickedSupportAttachment(
          name: file.name,
          sizeInBytes: file.size,
          path: file.path,
          bytes: file.bytes,
          extension: _extensionFor(file.name),
        );
      });
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Attachment could not be selected right now.'),
        ),
      );
    }
  }

  Future<void> _sendReply(BuildContext context) async {
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

    setState(() => _isSendingReply = true);

    try {
      String? attachmentUrl;
      if (attachment != null) {
        attachmentUrl = await repository.uploadSupportTicketAttachment(
          ticketId: ticket.id,
          filePath: attachment.path,
          fileBytes: attachment.bytes,
          fileName: attachment.name,
        );
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
      setState(() => _pickedAttachment = null);
      ref.invalidate(supportTicketDetailProvider(ticket.id));
      ref.invalidate(supportTicketsProvider);
      _scrollToBottomSoon();
    } on ApiError catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Message could not be sent right now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingReply = false);
    }
  }

  Future<void> _updateTicketStatus(BuildContext context, String status) async {
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
    } on ApiError catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Support ticket status could not be updated right now.',
          ),
        ),
      );
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
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(status: ticket.status, compact: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${ticket.id} • ${ticket.priority} priority',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (ticket.referenceServiceRequest != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => context.push(
                '/my-services/${Uri.encodeComponent(ticket.referenceServiceRequest!)}',
              ),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 17,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Linked case: ${ticket.referenceServiceRequest!}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                child: Text(
                  _initials(identity),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (email != null && email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    if (phone != null && phone.isNotEmpty)
                      Text(
                        phone,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const _CustomerBadge(),
            ],
          ),
          const SizedBox(height: 13),
          const Divider(height: 1),
          const SizedBox(height: 12),
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

class _CustomerBadge extends StatelessWidget {
  const _CustomerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Customer',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
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
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Conversation',
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _EmptyConversationBubble extends StatelessWidget {
  const _EmptyConversationBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'No messages yet. Start the conversation from the box below.',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w600,
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
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final bubbleColor = isMine
        ? AppTheme.primary.withValues(alpha: 0.09)
        : Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.68);
    final borderColor = isMine
        ? AppTheme.primary.withValues(alpha: 0.12)
        : Theme.of(context).dividerColor.withValues(alpha: 0.55);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 5),
              bottomRight: Radius.circular(isMine ? 5 : 18),
            ),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      message.isFromCustomer
                          ? Icons.person_outline_rounded
                          : Icons.support_agent_rounded,
                      color: AppTheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _authorLabel(message),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (message.message.trim().isNotEmpty &&
                    message.message != '-') ...[
                  const SizedBox(height: 8),
                  Text(
                    message.message,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (message.hasAttachment) ...[
                  const SizedBox(height: 10),
                  _AttachmentTile(message: message),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    message.createdAtLabel == '-' ? '' : message.createdAtLabel,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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

    return InkWell(
      onTap: url.isEmpty ? null : () => _openAttachment(context, url),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.attach_file_rounded,
              color: AppTheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (message.attachmentType != null)
                    Text(
                      message.attachmentType!.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(BuildContext context, String rawUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(_absoluteUrl(rawUrl));
    if (uri == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Attachment link is invalid.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Attachment could not be opened.')),
      );
    }
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
        color: const Color(0xFFF2F5F8),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachment != null) ...[
              _PickedAttachmentPreview(
                attachment: attachment!,
                onRemove: enabled ? onRemoveAttachment : null,
              ),
              const SizedBox(height: 8),
            ],
            if (isClosed)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 9),
                child: Text(
                  'This ticket is closed. Reopen it before adding a reply.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: const Color(0xFFE0E5EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A111827),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: enabled ? onPickAttachment : null,
                      icon: const Icon(Icons.attach_file_rounded),
                      tooltip: 'Attach file',
                      color: AppTheme.textSecondary,
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Write a message...',
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final canSend =
                            enabled &&
                            !isSending &&
                            (value.text.trim().isNotEmpty ||
                                attachment != null);

                        return SizedBox(
                          width: 44,
                          height: 44,
                          child: FilledButton(
                            onPressed: canSend ? onSend : null,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                              backgroundColor: AppTheme.primary,
                              disabledBackgroundColor: AppTheme.primary
                                  .withValues(alpha: 0.25),
                            ),
                            child: isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 20),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'PDF, JPG, PNG or DOC • Max 10 MB',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.attach_file_rounded,
            color: AppTheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            _sizeLabel(attachment.sizeInBytes),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

class _SupportAdminStatusBar extends StatelessWidget {
  const _SupportAdminStatusBar({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          _StatusPill(status: ticket.status, compact: true),
          const Spacer(),
          TextButton.icon(
            onPressed: isUpdating || onStatusSelected == null
                ? null
                : () => _openStatusSheet(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: isUpdating
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.tune_rounded, size: 17),
            label: const Text(
              'Update status',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStatusSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update ticket status',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose the current stage of this conversation.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                for (final status in _statuses)
                  _StatusSheetOption(
                    status: status,
                    selected:
                        status.toLowerCase() ==
                        ticket.status.trim().toLowerCase(),
                    onTap: () => Navigator.of(context).pop(status),
                  ),
              ],
            ),
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

class _StatusSheetOption extends StatelessWidget {
  const _StatusSheetOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final String status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.07)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.20)
                    : const Color(0xFFE7EAF0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.09),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon(status), size: 16, color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, size: 19, color: color)
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _statusIcon(String status) {
  final value = status.trim().toLowerCase();

  if (value.contains('progress')) {
    return Icons.play_circle_outline_rounded;
  }

  if (value.contains('waiting')) {
    return Icons.hourglass_bottom_rounded;
  }

  if (value.contains('resolved')) {
    return Icons.verified_rounded;
  }

  if (value.contains('closed')) {
    return Icons.lock_outline_rounded;
  }

  return Icons.radio_button_checked_rounded;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 10,
          vertical: compact ? 5 : 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 7, color: color),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketDetailLoadingView extends StatelessWidget {
  const _TicketDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TicketLoadingBlock(
                width: 52,
                height: 52,
                radius: 18,
                color: color,
              ),
              const SizedBox(height: 18),
              _TicketLoadingBlock(
                width: double.infinity,
                height: 16,
                radius: 999,
                color: color,
              ),
              const SizedBox(height: 10),
              _TicketLoadingBlock(
                width: 220,
                height: 12,
                radius: 999,
                color: color,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _TicketLoadingBlock(
                width: 260,
                height: 58,
                radius: 18,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketLoadingBlock extends StatelessWidget {
  const _TicketLoadingBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
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

Color _statusColor(String status) {
  final value = status.trim().toLowerCase();
  if (value.contains('progress')) return const Color(0xFF356AC3);
  if (value.contains('waiting')) return const Color(0xFFB7791F);
  if (value.contains('resolved') ||
      value.contains('closed') ||
      value.contains('complete')) {
    return const Color(0xFF2F855A);
  }
  if (value.contains('cancel')) return const Color(0xFF718096);
  return AppTheme.primary;
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

String _cleanError(Object error) {
  if (error is ApiError) return error.message;
  final text = error.toString().trim();
  if (text.isEmpty) return 'Something went wrong while loading this ticket.';
  return text.replaceFirst('Exception: ', '');
}

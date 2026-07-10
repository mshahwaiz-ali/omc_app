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
import '../data/support_repository.dart';
import '../data/support_ticket.dart';

class SupportTicketDetailScreen extends ConsumerWidget {
  const SupportTicketDetailScreen({required this.ticketId, super.key});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketAsync = ref.watch(supportTicketDetailProvider(ticketId));

    return Scaffold(
      appBar: const AppBackHeader(title: 'Support Chat'),
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
                if (ticket.canUpdateStatus) ...[
                  const SizedBox(height: 12),
                  _SupportAdminStatusBar(
                    ticket: ticket,
                    isUpdating: _isUpdatingStatus,
                    onStatusSelected: _isUpdatingStatus
                        ? null
                        : (status) => _updateTicketStatus(context, status),
                  ),
                ],
                const SizedBox(height: 18),
                _ConversationHeader(count: ticket.messages.length),
                const SizedBox(height: 12),
                if (ticket.messages.isEmpty)
                  const _EmptyConversationBubble()
                else
                  for (final message in ticket.messages) ...[
                    _ChatBubble(
                      message: message,
                      isMine: ticket.canUpdateStatus
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
          enabled: ticket.canReply && !ticket.isClosed && !_isSendingReply,
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
      messenger.showSnackBar(const SnackBar(content: Text('Message sent.')));
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
    final repository = ref.read(supportRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ticket.id,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(status: ticket.status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallPill(
                label: ticket.priority,
                icon: Icons.flag_outlined,
                color: Colors.blueGrey.shade700,
              ),
              if (ticket.updatedAtLabel != null)
                _SmallPill(
                  label: ticket.updatedAtLabel!,
                  icon: Icons.update_rounded,
                  color: Colors.blueGrey.shade700,
                ),
              if (ticket.referenceServiceRequest != null)
                ActionChip(
                  avatar: const Icon(Icons.assignment_outlined, size: 16),
                  label: Text(ticket.referenceServiceRequest!),
                  onPressed: () => context.push(
                    '/my-services/${Uri.encodeComponent(ticket.referenceServiceRequest!)}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Conversation',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        _SmallPill(
          label: '$count',
          icon: Icons.support_agent_rounded,
          color: Colors.blueGrey.shade700,
        ),
      ],
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
        ? AppTheme.primaryRed.withValues(alpha: 0.09)
        : Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.68);
    final borderColor = isMine
        ? AppTheme.primaryRed.withValues(alpha: 0.12)
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
                      color: AppTheme.primaryRed,
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
          border: Border.all(
            color: AppTheme.primaryRed.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.attach_file_rounded,
              color: AppTheme.primaryRed,
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'This ticket is closed. Reopen it before adding a reply.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton.filledTonal(
                      onPressed: enabled ? onPickAttachment : null,
                      icon: const Icon(Icons.add_rounded),
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
                        decoration: InputDecoration(
                          hintText: 'Write a message',
                          filled: true,
                          prefixIcon: const Icon(Icons.support_agent_rounded),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: enabled ? onSend : null,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(14),
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
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
            ],
          ),
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
        color: AppTheme.primaryRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.attach_file_rounded,
            color: AppTheme.primaryRed,
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

  @override
  Widget build(BuildContext context) {
    final status = ticket.status.trim().toLowerCase();
    final isClosed = status == 'closed' || status == 'cancelled';

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatusActionButton(
            label: 'Progress',
            status: 'In Progress',
            icon: Icons.play_circle_outline_rounded,
            enabled: !isUpdating && !isClosed,
            onStatusSelected: onStatusSelected,
          ),
          _StatusActionButton(
            label: 'Waiting',
            status: 'Waiting for Customer',
            icon: Icons.hourglass_bottom_rounded,
            enabled: !isUpdating && !isClosed,
            onStatusSelected: onStatusSelected,
          ),
          _StatusActionButton(
            label: 'Resolved',
            status: 'Resolved',
            icon: Icons.verified_rounded,
            enabled: !isUpdating && !isClosed,
            onStatusSelected: onStatusSelected,
          ),
          _StatusActionButton(
            label: 'Close',
            status: 'Closed',
            icon: Icons.lock_rounded,
            enabled: !isUpdating && !isClosed,
            onStatusSelected: onStatusSelected,
          ),
          _StatusActionButton(
            label: 'Reopen',
            status: 'Open',
            icon: Icons.refresh_rounded,
            enabled: !isUpdating,
            onStatusSelected: onStatusSelected,
          ),
        ],
      ),
    );
  }
}

class _StatusActionButton extends StatelessWidget {
  const _StatusActionButton({
    required this.label,
    required this.status,
    required this.icon,
    required this.enabled,
    required this.onStatusSelected,
  });

  final String label;
  final String status;
  final IconData icon;
  final bool enabled;
  final ValueChanged<String>? onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled && onStatusSelected != null
          ? () => onStatusSelected!(status)
          : null,
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return _SmallPill(
      label: status,
      icon: Icons.support_agent_rounded,
      color: AppTheme.primaryRed,
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
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

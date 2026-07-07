import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
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
      appBar: const AppBackHeader(title: 'Support Ticket'),
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

          return _SupportTicketDetailBody(ticket: ticket);
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

class _TicketDetailLoadingView extends StatelessWidget {
  const _TicketDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
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
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(
              4,
              (index) => _LoadingDetailTile(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingDetailTile extends StatelessWidget {
  const _LoadingDetailTile({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          _TicketLoadingBlock(width: 42, height: 42, radius: 14, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.38,
                  alignment: Alignment.centerLeft,
                  child: _TicketLoadingBlock(
                    width: double.infinity,
                    height: 10,
                    radius: 999,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.78,
                  alignment: Alignment.centerLeft,
                  child: _TicketLoadingBlock(
                    width: double.infinity,
                    height: 12,
                    radius: 999,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportTicketDetailBody extends ConsumerStatefulWidget {
  const _SupportTicketDetailBody({required this.ticket});

  final SupportTicket ticket;

  @override
  ConsumerState<_SupportTicketDetailBody> createState() =>
      _SupportTicketDetailBodyState();
}

class _SupportTicketDetailBodyState
    extends ConsumerState<_SupportTicketDetailBody> {
  final _replyController = TextEditingController();

  bool _isUpdatingStatus = false;
  bool _isSendingReply = false;

  SupportTicket get ticket => widget.ticket;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: AppTheme.primaryRed,
                      size: 27,
                    ),
                  ),
                  const Spacer(),
                  _StatusPill(status: ticket.status),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                ticket.subject,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                ticket.message,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PriorityPill(priority: ticket.priority),
                  if (ticket.updatedAtLabel != null)
                    _SmallPill(
                      label: ticket.updatedAtLabel!,
                      icon: Icons.update_rounded,
                      color: Colors.blueGrey.shade700,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DetailTile(
                icon: Icons.fingerprint_rounded,
                label: 'Ticket ID',
                value: ticket.id,
              ),
              const Divider(height: 1, indent: 76),
              _DetailTile(
                icon: Icons.schedule_rounded,
                label: 'Raised on',
                value: ticket.raisedOnLabel ?? 'Not available',
              ),
              const Divider(height: 1, indent: 76),
              _DetailTile(
                icon: Icons.update_rounded,
                label: 'Last updated',
                value: ticket.updatedAtLabel ?? 'Not available',
              ),
              const Divider(height: 1, indent: 76),
              _DetailTile(
                icon: Icons.assignment_outlined,
                label: 'Service request',
                value: ticket.referenceServiceRequest ?? 'Not linked',
                onTap: ticket.referenceServiceRequest == null
                    ? null
                    : () => context.push(
                        '/my-services/${Uri.encodeComponent(ticket.referenceServiceRequest!)}',
                      ),
              ),
              const Divider(height: 1, indent: 76),
              _DetailTile(
                icon: Icons.email_outlined,
                label: 'Contact email',
                value: ticket.contactEmail ?? 'Not available',
              ),
              const Divider(height: 1, indent: 76),
              _DetailTile(
                icon: Icons.phone_outlined,
                label: 'Contact phone',
                value: ticket.contactPhone ?? 'Not available',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _TicketConversationCard(ticket: ticket),
        if (ticket.canReply) ...[
          const SizedBox(height: 16),
          _SupportReplyComposer(
            controller: _replyController,
            enabled: !ticket.isClosed && !_isSendingReply,
            isSending: _isSendingReply,
            isClosed: ticket.isClosed,
            onSend: () => _sendReply(context),
          ),
        ],
        if (ticket.canUpdateStatus) ...[
          const SizedBox(height: 16),
          _SupportAdminStatusCard(
            ticket: ticket,
            isUpdating: _isUpdatingStatus,
            onStatusSelected: _isUpdatingStatus
                ? null
                : (status) => _updateTicketStatus(context, status),
          ),
        ],
      ],
    );
  }

  Future<void> _sendReply(BuildContext context) async {
    final message = _replyController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (ticket.isClosed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Closed tickets cannot receive replies.')),
      );
      return;
    }

    if (message.length < 2) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a reply message.')),
      );
      return;
    }

    final repository = ref.read(supportRepositoryProvider);

    setState(() => _isSendingReply = true);

    try {
      await repository.addSupportTicketReply(
        ticketId: ticket.id,
        message: message,
      );

      if (!context.mounted) return;

      _replyController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Reply added to support ticket.')),
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
          content: Text('Reply could not be sent right now. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingReply = false);
      }
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
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }
}

class _SupportReplyComposer extends StatelessWidget {
  const _SupportReplyComposer({
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.isClosed,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final bool isClosed;
  final VoidCallback onSend;

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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.reply_rounded,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Reply',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isClosed) ...[
            const Text(
              'This ticket is closed. Reopen it before adding a reply.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            TextField(
              controller: controller,
              enabled: enabled,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Write a reply',
                prefixIcon: Icon(Icons.message_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: enabled ? onSend : null,
                icon: Icon(
                  isSending ? Icons.hourglass_top_rounded : Icons.send_rounded,
                ),
                label: Text(isSending ? 'Sending...' : 'Send reply'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TicketConversationCard extends StatelessWidget {
  const _TicketConversationCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final messages = ticket.messages;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Conversation',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SmallPill(
                label: messages.length.toString(),
                icon: Icons.chat_bubble_outline_rounded,
                color: Colors.blueGrey.shade700,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (messages.isEmpty)
            const Text(
              'No backend replies are attached to this ticket yet.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (final message in messages) ...[
              _ConversationMessageTile(message: message),
              if (message != messages.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ConversationMessageTile extends StatelessWidget {
  const _ConversationMessageTile({required this.message});

  final SupportTicketMessage message;

  @override
  Widget build(BuildContext context) {
    final isReply = message.isReply;
    final title = message.author == '-'
        ? (isReply ? 'OMC Team' : 'Customer')
        : message.author;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: isReply ? 0.035 : 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReply ? Icons.support_agent_rounded : Icons.person_outline,
                color: AppTheme.primaryRed,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (message.createdAtLabel != '-')
                Text(
                  message.createdAtLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.message,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ticket.status.trim().toLowerCase();
    final isClosed = status == 'closed' || status == 'cancelled';

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Admin ticket controls',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isClosed
                ? 'This ticket is closed. Reopen it before more support action.'
                : 'Update the backend ticket status after reviewing the customer request.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusActionButton(
                label: 'Waiting',
                status: 'Waiting for Customer',
                icon: Icons.hourglass_bottom_rounded,
                enabled: !isUpdating && !isClosed && onStatusSelected != null,
                onStatusSelected: onStatusSelected,
              ),
              _StatusActionButton(
                label: 'Resolved',
                status: 'Resolved',
                icon: Icons.verified_rounded,
                enabled: !isUpdating && !isClosed && onStatusSelected != null,
                onStatusSelected: onStatusSelected,
              ),
              _StatusActionButton(
                label: 'Close',
                status: 'Closed',
                icon: Icons.lock_rounded,
                enabled: !isUpdating && !isClosed && onStatusSelected != null,
                onStatusSelected: onStatusSelected,
              ),
              _StatusActionButton(
                label: 'Reopen',
                status: 'Open',
                icon: Icons.refresh_rounded,
                enabled: !isUpdating && onStatusSelected != null,
                onStatusSelected: onStatusSelected,
              ),
            ],
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
      onPressed: enabled ? () => onStatusSelected?.call(status) : null,
      icon: Icon(icon),
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

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    return _SmallPill(
      label: priority,
      icon: Icons.flag_outlined,
      color: Colors.blueGrey.shade700,
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

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.primaryRed),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ],
        ),
      ),
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

String _cleanError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isEmpty) {
    return 'Support ticket details could not be loaded right now.';
  }
  return message;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
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
      appBar: AppBar(title: const Text('Support Ticket')),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Ticket unavailable',
          message: _cleanError(error),
        ),
      ),
    );
  }
}

class _SupportTicketDetailBody extends StatelessWidget {
  const _SupportTicketDetailBody({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusPill(status: ticket.status),
                  const SizedBox(width: 8),
                  _PriorityPill(priority: ticket.priority),
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
      ],
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
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppTheme.primaryRed),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded),
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

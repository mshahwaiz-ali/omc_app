import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/app_back_header.dart';
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 12,
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(4, (index) => const _LoadingDetailTile()),
          ),
        ),
      ],
    );
  }
}

class _LoadingDetailTile extends StatelessWidget {
  const _LoadingDetailTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.38,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.78,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(99),
                    ),
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

class _SupportTicketDetailBody extends StatelessWidget {
  const _SupportTicketDetailBody({required this.ticket});

  final SupportTicket ticket;

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

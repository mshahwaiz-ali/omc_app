import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/omc_identity_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/data/home_dashboard_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/internal_service_case.dart';
import '../domain/internal_workspace_summary.dart';
import 'internal_workspace_providers.dart';

const EdgeInsets _kShellPagePadding = EdgeInsets.fromLTRB(20, 18, 20, 164);
const Color _ink = Color(0xFF111827);
const Color _slate = Color(0xFF64748B);
const Color _rose = Color(0xFFE11D48);
const Color _orange = Color(0xFFF97316);
const Color _green = Color(0xFF16A34A);
const Color _purple = Color(0xFF7C3AED);

class InternalWorkspaceScreen extends ConsumerWidget {
  const InternalWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(internalWorkspaceSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(internalWorkspaceSummaryProvider);
          ref.invalidate(internalServiceCasesProvider);
          return ref.read(internalWorkspaceSummaryProvider.future);
        },
        child: summaryAsync.when(
          data: (summary) => _InternalWorkspaceContent(summary: summary),
          loading: () => const _InternalWorkspaceLoading(),
          error: (error, _) => _InternalWorkspaceUnavailable(
            message: _backendErrorMessage(error),
            onRetry: () => ref.invalidate(internalWorkspaceSummaryProvider),
          ),
        ),
      ),
    );
  }
}

String _backendErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Could not load internal workspace summary from the backend right now.';
}

class _InternalWorkspaceUnavailable extends StatelessWidget {
  const _InternalWorkspaceUnavailable({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kShellPagePadding,
      children: [
        PremiumEmptyState(
          icon: Icons.dashboard_customize_rounded,
          title: 'Workspace unavailable',
          message: message,
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      ],
    );
  }
}

class _InternalWorkspaceContent extends ConsumerWidget {
  const _InternalWorkspaceContent({required this.summary});

  final InternalWorkspaceSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queueAsync = ref.watch(internalServiceCasesProvider);
    final authState = ref.watch(authControllerProvider);
    final profile = ref.watch(profileSummaryProvider).value;
    final displayName = profile?.displayName ?? authState.displayName ?? 'Administrator';
    final avatarUrl = ApiConfig.resolveFileUrl(profile?.avatarUrl ?? authState.avatarUrl);
    final unreadNotifications =
        ref.watch(homeDashboardSummaryProvider).value?.unreadNotifications ?? 0;
    final totalFocusItems =
        summary.openLeads + summary.pendingTasks + summary.pendingPayments;

    return Stack(
      children: [
        const Positioned.fill(child: _WorkspaceBackdrop()),
        ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: _kShellPagePadding,
          children: [
        OmcIdentityHeader(
          displayName: displayName,
          avatarUrl: avatarUrl,
          unreadNotifications: unreadNotifications,
          onNotifications: () => context.push('/notifications'),
          onAvatar: () => context.push('/profile'),
        ),
        const SizedBox(height: 18),
        _CustomerSearchCard(
          onSearch: (value) {
            final query = value.trim();
            if (query.isEmpty) return;
            ref.read(internalServiceCaseFiltersProvider.notifier).setFilters(
                  InternalServiceCaseFilters(search: query),
                );
            context.go('/internal-workspace/service-cases');
          },
        ),
        const SizedBox(height: 16),
        _FocusStrip(
          totalFocusItems: totalFocusItems,
          leads: summary.openLeads,
          payments: summary.pendingPayments,
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          title: 'Needs Attention',
          actionLabel: 'View all',
          onAction: () => context.go('/internal-workspace/service-cases'),
        ),
        const SizedBox(height: 10),
        queueAsync.when(
          loading: () => const _PriorityQueueLoading(),
          error: (error, _) => _PriorityQueueFallback(message: _backendErrorMessage(error)),
          data: (queue) => _PriorityQueuePreview(
            items: queue.cases.take(3).toList(growable: false),
          ),
        ),
        const SizedBox(height: 22),
        Text('Work Areas', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        _CompactWorkAreas(summary: summary),
        const SizedBox(height: 22),
        Text('Quick Actions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        const _QuickActions(),
          ],
        ),
      ],
    );
  }
}

class _WorkspaceBackdrop extends StatelessWidget {
  const _WorkspaceBackdrop();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDFEFF), Color(0xFFF6F8FC), Color(0xFFFAFBFD)],
          ),
        ),
      );
}

class _CustomerSearchCard extends StatefulWidget {
  const _CustomerSearchCard({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  State<_CustomerSearchCard> createState() => _CustomerSearchCardState();
}

class _CustomerSearchCardState extends State<_CustomerSearchCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSearch,
        decoration: InputDecoration(
          hintText: 'Search customer, phone, CNIC, NTN or service...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            tooltip: 'Search',
            onPressed: () => widget.onSearch(_controller.text),
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
      ),
    );
  }
}

class _FocusStrip extends StatelessWidget {
  const _FocusStrip({
    required this.totalFocusItems,
    required this.leads,
    required this.payments,
  });

  final int totalFocusItems;
  final int leads;
  final int payments;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricChip(
            value: '$totalFocusItems',
            label: 'Needs focus',
            icon: Icons.priority_high_rounded,
            color: _rose,
            background: Color(0xFFFFF1F3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricChip(value: '$payments', label: 'Pending pay', icon: Icons.receipt_long_rounded, color: _orange, background: Color(0xFFFFF7ED)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricChip(value: '$leads', label: 'Open leads', icon: Icons.person_add_alt_1_rounded, color: _green, background: Color(0xFFF0FDF4)),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.value, required this.label, required this.icon, required this.color, required this.background});

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 10, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 31, height: 31, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 17, color: color)),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _ink, fontSize: 24).copyWith(
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11).copyWith(
              color: _slate,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _PriorityQueuePreview extends StatelessWidget {
  const _PriorityQueuePreview({required this.items});

  final List<InternalServiceCase> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _PriorityQueueFallback(
        message: 'No service cases need attention in the current queue.',
      );
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PriorityQueueTile(serviceCase: item),
          ),
      ],
    );
  }
}

class _PriorityQueueTile extends StatelessWidget {
  const _PriorityQueueTile({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsAction = serviceCase.uploadedDocuments > 0
        ? '${serviceCase.uploadedDocuments} documents need review'
        : serviceCase.pendingDocuments > 0
            ? '${serviceCase.pendingDocuments} documents pending'
            : serviceCase.status;

    final tone = serviceCase.uploadedDocuments > 0 ? _rose : _orange;
    return PremiumCard(
      padding: const EdgeInsets.all(13),
      onTap: () => context.go('/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}'),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.bolt_rounded, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${serviceCase.displayCustomer} · ${serviceCase.displayService}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  serviceCase.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.go('/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}'),
            style: FilledButton.styleFrom(backgroundColor: _rose, minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _PriorityQueueLoading extends StatelessWidget {
  const _PriorityQueueLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _LoadingPanel(height: 74),
        SizedBox(height: 10),
        _LoadingPanel(height: 74),
      ],
    );
  }
}

class _PriorityQueueFallback extends StatelessWidget {
  const _PriorityQueueFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactWorkAreas extends StatelessWidget {
  const _CompactWorkAreas({required this.summary});

  final InternalWorkspaceSummary summary;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _CompactWorkAreaTile(
            title: 'Service Requests',
            subtitle: 'All customer service cases',
            icon: Icons.assignment_turned_in_rounded,
            metric: '${summary.activeCustomers} active',
            onTap: () => context.go('/internal-workspace/service-cases'),
          ),
          const _WorkAreaDivider(),
          _CompactWorkAreaTile(
            title: 'Customers',
            subtitle: 'Customer 360 center',
            icon: Icons.groups_2_rounded,
            metric: '${summary.activeCustomers} records',
            onTap: () => context.go('/internal-workspace/customers'),
          ),
          const _WorkAreaDivider(),
          _CompactWorkAreaTile(
            title: 'Documents',
            subtitle: 'Review uploaded files',
            icon: Icons.folder_copy_rounded,
            metric: 'Review queue',
            onTap: () => context.go('/internal-workspace/documents'),
          ),
          const _WorkAreaDivider(),
          _CompactWorkAreaTile(
            title: 'Payments',
            subtitle: 'Receipt and dues control',
            icon: Icons.payments_rounded,
            metric: '${summary.pendingPayments} pending',
            onTap: () => context.go('/internal-workspace/payments'),
          ),
          const _WorkAreaDivider(),
          _CompactWorkAreaTile(
            title: 'Leads',
            subtitle: 'Inquiry follow-up',
            icon: Icons.trending_up_rounded,
            metric: '${summary.openLeads} open',
            onTap: () => context.go('/leads'),
          ),
          const _WorkAreaDivider(),
          _CompactWorkAreaTile(
            title: 'Tasks',
            subtitle: 'Team execution queue',
            icon: Icons.task_alt_rounded,
            metric: '${summary.pendingTasks} pending',
            onTap: () => context.go('/tasks'),
          ),
        ],
      ),
    );
  }
}

class _CompactWorkAreaTile extends StatelessWidget {
  const _CompactWorkAreaTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.metric,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String metric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _workAreaTone(title);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: tone, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                metric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Color _workAreaTone(String value) => switch (value) {
        'Service Requests' => _rose,
        'Customers' => _orange,
        'Documents' => _green,
        'Payments' => _purple,
        'Leads' => const Color(0xFF2563EB),
        _ => const Color(0xFF0F9F8F),
      };
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    final actions = <({String label, IconData icon, String route})>[
      (label: 'New Request', icon: Icons.add_rounded, route: '/services'),
      (label: 'Add Customer', icon: Icons.person_add_alt_1_rounded, route: '/internal-workspace/customers'),
      (label: 'Upload Document', icon: Icons.upload_file_rounded, route: '/internal-workspace/documents'),
      (label: 'Record Payment', icon: Icons.credit_card_rounded, route: '/internal-workspace/payments'),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: PremiumCard(
              onTap: () => context.go(actions[i].route),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
              child: Column(
                children: [
                  Icon(actions[i].icon, size: 20, color: _slate),
                  const SizedBox(height: 8),
                  Text(actions[i].label, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 9.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WorkAreaDivider extends StatelessWidget {
  const _WorkAreaDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
    );
  }
}

class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder({required this.onOpenCases});

  final VoidCallback onOpenCases;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Activity timeline is ready in the UI structure. It will become live when backend activity events are exposed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenCases,
            icon: const Icon(Icons.assignment_rounded),
            label: const Text('Open service cases'),
          ),
        ],
      ),
    );
  }
}

class _InternalWorkspaceLoading extends StatelessWidget {
  const _InternalWorkspaceLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kShellPagePadding,
      children: const [
        _LoadingPanel(height: 92),
        SizedBox(height: 14),
        _LoadingPanel(height: 78),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _LoadingPanel(height: 92)),
            SizedBox(width: 10),
            Expanded(child: _LoadingPanel(height: 92)),
            SizedBox(width: 10),
            Expanded(child: _LoadingPanel(height: 92)),
          ],
        ),
        SizedBox(height: 18),
        _LoadingPanel(height: 74),
        SizedBox(height: 10),
        _LoadingPanel(height: 74),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

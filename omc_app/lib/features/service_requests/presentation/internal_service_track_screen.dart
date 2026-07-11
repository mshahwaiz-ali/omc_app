import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/omc_premium.dart';
import '../data/service_case.dart';
import '../data/service_case_repository.dart';

class InternalServiceTrackScreen extends ConsumerStatefulWidget {
  const InternalServiceTrackScreen({super.key});

  @override
  ConsumerState<InternalServiceTrackScreen> createState() =>
      _InternalServiceTrackScreenState();
}

class _InternalServiceTrackScreenState
    extends ConsumerState<InternalServiceTrackScreen> {
  final _searchController = TextEditingController();
  _CaseFilter _filter = _CaseFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(serviceCasesProvider);
    return Scaffold(
      backgroundColor: OmcPremium.canvas,
      body: SafeArea(
        child: casesAsync.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            message: _cleanError(error),
            onRetry: () => ref.invalidate(serviceCasesProvider),
          ),
          data: (cases) {
            final visible = cases.where((item) {
              if (!_filter.matches(item)) return false;
              if (_query.isEmpty) return true;
              final value = [
                item.displayCustomerName,
                item.title,
                item.displayReference,
                item.category,
                item.status,
              ].join(' ').toLowerCase();
              return value.contains(_query);
            }).toList(growable: false);

            return RefreshIndicator(
              color: OmcPremium.services,
              onRefresh: () async => ref.invalidate(serviceCasesProvider),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                children: [
                  _Header(cases: cases),
                  const SizedBox(height: 20),
                  _SearchField(
                    controller: _searchController,
                    onChanged: (value) => setState(
                      () => _query = value.trim().toLowerCase(),
                    ),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: 16),
                  _FilterBar(
                    selected: _filter,
                    onSelected: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 16),
                  _SummaryStrip(cases: cases),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    _EmptyState(hasQuery: _query.isNotEmpty)
                  else
                    for (var index = 0; index < visible.length; index++) ...[
                      _ServiceRequestCard(serviceCase: visible[index]),
                      if (index != visible.length - 1)
                        const SizedBox(height: 14),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.cases});
  final List<ServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final active = cases.where((item) => !_caseState(item).isDone).length;
    final attention = cases.where(_needsAttention).length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: OmcPremium.soft(OmcPremium.services, .09),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.assignment_outlined,
            color: OmcPremium.services,
            size: 23,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Service Requests',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 25,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.55,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$active active ${active == 1 ? 'case' : 'cases'}  •  '
                '$attention need attention',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: OmcPremium.border),
        boxShadow: OmcPremium.softShadow,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search customer, request ID or service',
          hintStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textSecondary,
          ),
          suffixIcon: controller.text.isEmpty
              ? const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.textSecondary,
                )
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

enum _CaseFilter { all, attention, inProgress, completed }

extension on _CaseFilter {
  String get label => switch (this) {
    _CaseFilter.all => 'All',
    _CaseFilter.attention => 'Attention',
    _CaseFilter.inProgress => 'In Progress',
    _CaseFilter.completed => 'Completed',
  };

  bool matches(ServiceCase item) => switch (this) {
    _CaseFilter.all => true,
    _CaseFilter.attention => _needsAttention(item),
    _CaseFilter.inProgress => _caseState(item).isInProgress,
    _CaseFilter.completed => _caseState(item).isCompleted,
  };
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});
  final _CaseFilter selected;
  final ValueChanged<_CaseFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _CaseFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final item = _CaseFilter.values[index];
          final active = item == selected;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                color: active
                    ? OmcPremium.soft(OmcPremium.services, .13)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active
                      ? OmcPremium.soft(OmcPremium.services, .20)
                      : OmcPremium.border,
                ),
              ),
              child: Row(
                children: [
                  if (active) ...[
                    const Icon(
                      Icons.check_rounded,
                      color: OmcPremium.services,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    item.label,
                    style: TextStyle(
                      color: active
                          ? OmcPremium.services
                          : AppTheme.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.cases});
  final List<ServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final review = cases.where(_needsReview).length;
    final missing = cases.fold<int>(
      0,
      (total, item) => total + _missingCount(item),
    );
    return OmcSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              icon: Icons.folder_open_outlined,
              label: 'Cases',
              value: '${cases.length}',
              color: OmcPremium.documents,
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Metric(
              icon: Icons.error_outline_rounded,
              label: 'Need review',
              value: '$review',
              color: OmcPremium.action,
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Metric(
              icon: Icons.insert_drive_file_outlined,
              label: 'Missing',
              value: '$missing',
              color: OmcPremium.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 56,
    color: OmcPremium.border,
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OmcIconBadge(
          icon: icon,
          color: color,
          size: 38,
          iconSize: 19,
          radius: 13,
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 19,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceRequestCard extends StatelessWidget {
  const _ServiceRequestCard({required this.serviceCase});
  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final state = _caseState(serviceCase);
    final tone = state.color;
    final total = serviceCase.requiredDocumentTotal;
    final received = serviceCase.submittedDocumentsCount ??
        serviceCase.documentDetails.where((item) => item.fileUrl != null).length;
    final progress = total == 0
        ? (state.isCompleted ? 1.0 : 0.0)
        : (received / total).clamp(0, 1).toDouble();
    final missing = _missingCount(serviceCase);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OmcPremium.border),
        boxShadow: OmcPremium.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: tone),
              Expanded(
                child: InkWell(
                  onTap: () => context.go('/my-services/${serviceCase.id}'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 16, 15, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardHeader(serviceCase: serviceCase, state: state),
                        const SizedBox(height: 13),
                        _DocumentProgress(
                          received: received,
                          total: total,
                          missing: missing,
                          progress: progress,
                          color: tone,
                          completed: state.isCompleted,
                        ),
                        const SizedBox(height: 12),
                        _MetaRow(serviceCase: serviceCase, state: state),
                        const SizedBox(height: 12),
                        _NextAction(serviceCase: serviceCase, state: state),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.serviceCase, required this.state});
  final ServiceCase serviceCase;
  final _CaseState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OmcIconBadge(
          icon: Icons.person_outline_rounded,
          color: state.color,
          size: 46,
          iconSize: 22,
          radius: 16,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                serviceCase.displayCustomerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16.5,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                serviceCase.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                serviceCase.displayReference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OmcStatusBadge(label: state.label, color: state.color),
      ],
    );
  }
}

class _DocumentProgress extends StatelessWidget {
  const _DocumentProgress({
    required this.received,
    required this.total,
    required this.missing,
    required this.progress,
    required this.color,
    required this.completed,
  });
  final int received;
  final int total;
  final int missing;
  final double progress;
  final Color color;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return _SuccessPanel(
        text: completed ? 'Service completed successfully' : 'No documents required',
      );
    }
    final percent = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmcPremium.soft(color, .055),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Documents: $received of $total received',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (missing > 0)
                _TinyBadge(label: '$missing missing', color: OmcPremium.danger)
              else
                Text(
                  '$percent%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE7EBF1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              if (missing > 0) ...[
                const SizedBox(width: 9),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.serviceCase, required this.state});
  final ServiceCase serviceCase;
  final _CaseState state;

  @override
  Widget build(BuildContext context) {
    final priority = serviceCase.priority?.trim();
    final missing = _missingCount(serviceCase);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (missing > 0)
          _TinyBadge(
            icon: Icons.description_outlined,
            label: '$missing missing',
            color: OmcPremium.danger,
          )
        else if (!state.isCompleted)
          _TinyBadge(
            icon: Icons.people_outline_rounded,
            label: state.waitingLabel,
            color: state.color,
          ),
        if (priority != null && priority.isNotEmpty)
          _TinyBadge(
            icon: Icons.flag_outlined,
            label: '${_titleCase(priority)} priority',
            color: _priorityColor(priority),
          ),
        _TinyBadge(
          icon: Icons.schedule_rounded,
          label: 'Updated ${serviceCase.updatedAtLabel}',
          color: AppTheme.textSecondary,
          softBackground: false,
        ),
      ],
    );
  }
}

class _NextAction extends StatelessWidget {
  const _NextAction({required this.serviceCase, required this.state});
  final ServiceCase serviceCase;
  final _CaseState state;

  @override
  Widget build(BuildContext context) {
    if (state.isCompleted) {
      return _SuccessPanel(
        text: 'All documents received and approved',
        subtitle: 'Completed ${serviceCase.updatedAtLabel}',
      );
    }
    final next = serviceCase.nextStep?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.arrow_forward_rounded, color: state.color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Next step: ',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(
                  text: next?.isNotEmpty == true ? next : state.defaultNextStep,
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (serviceCase.canReviewDocuments && _needsReview(serviceCase))
          FilledButton.icon(
            onPressed: () => context.go('/my-services/${serviceCase.id}'),
            icon: const Icon(Icons.find_in_page_outlined, size: 17),
            label: const Text('Review'),
            style: FilledButton.styleFrom(
              backgroundColor: OmcPremium.services,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          )
        else
          IconButton(
            tooltip: 'Open request',
            onPressed: () => context.go('/my-services/${serviceCase.id}'),
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppTheme.textSecondary,
          ),
      ],
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({required this.text, this.subtitle});
  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmcPremium.soft(OmcPremium.success, .07),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: OmcPremium.success,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.label,
    required this.color,
    this.icon,
    this.softBackground = true,
  });
  final String label;
  final Color color;
  final IconData? icon;
  final bool softBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: softBackground ? OmcPremium.soft(color, .075) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return OmcSurface(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: Column(
        children: [
          const OmcIconBadge(
            icon: Icons.search_off_rounded,
            color: OmcPremium.services,
            size: 52,
          ),
          const SizedBox(height: 13),
          Text(
            hasQuery ? 'No matching requests' : 'No requests in this view',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hasQuery
                ? 'Try another customer, service or request ID.'
                : 'Change the filter or pull down to refresh.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        for (final height in [60.0, 58.0, 42.0, 84.0, 230.0]) ...[
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: OmcSurface(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OmcIconBadge(
                icon: Icons.cloud_off_rounded,
                color: OmcPremium.danger,
                size: 54,
              ),
              const SizedBox(height: 14),
              const Text(
                'Could not load requests',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseState {
  const _CaseState({
    required this.label,
    required this.color,
    required this.isCompleted,
    required this.isInProgress,
    required this.isDone,
    required this.waitingLabel,
    required this.defaultNextStep,
  });
  final String label;
  final Color color;
  final bool isCompleted;
  final bool isInProgress;
  final bool isDone;
  final String waitingLabel;
  final String defaultNextStep;
}

_CaseState _caseState(ServiceCase item) {
  final status = item.status.trim().toLowerCase();
  if (status.contains('cancel') ||
      status.contains('reject') ||
      status.contains('declin') ||
      status.contains('blocked')) {
    return const _CaseState(
      label: 'Cancelled',
      color: OmcPremium.danger,
      isCompleted: false,
      isInProgress: false,
      isDone: true,
      waitingLabel: 'Cancelled',
      defaultNextStep: 'No further action',
    );
  }
  if (status.contains('complete') ||
      status.contains('closed') ||
      status.contains('done') ||
      status.contains('resolved')) {
    return const _CaseState(
      label: 'Completed',
      color: OmcPremium.success,
      isCompleted: true,
      isInProgress: false,
      isDone: true,
      waitingLabel: 'Completed',
      defaultNextStep: 'Service completed',
    );
  }
  if (status.contains('progress') || status.contains('working')) {
    return const _CaseState(
      label: 'In Progress',
      color: OmcPremium.documents,
      isCompleted: false,
      isInProgress: true,
      isDone: false,
      waitingLabel: 'In progress',
      defaultNextStep: 'Continue processing the service',
    );
  }
  if (status.contains('review') || status.contains('submitted')) {
    return const _CaseState(
      label: 'In Review',
      color: OmcPremium.track,
      isCompleted: false,
      isInProgress: false,
      isDone: false,
      waitingLabel: 'Need review',
      defaultNextStep: 'Review submitted documents',
    );
  }
  return const _CaseState(
    label: 'Open',
    color: OmcPremium.services,
    isCompleted: false,
    isInProgress: false,
    isDone: false,
    waitingLabel: 'Waiting customer',
    defaultNextStep: 'Review request details',
  );
}

int _missingCount(ServiceCase item) =>
    item.missingDocumentsCount ?? item.missingDocuments.length;

bool _needsReview(ServiceCase item) =>
    !item.isClosed &&
    (item.documentDetails.any((doc) => doc.isSubmitted && !doc.isApproved) ||
        item.status.toLowerCase().contains('review'));

bool _needsAttention(ServiceCase item) =>
    !item.isClosed &&
    (_missingCount(item) > 0 ||
        item.rejectedDocumentTotal > 0 ||
        item.rejectedPaymentTotal > 0 ||
        item.customerActionRequired ||
        _needsReview(item));

Color _priorityColor(String value) {
  final key = value.toLowerCase();
  if (key.contains('urgent') || key.contains('high')) return OmcPremium.danger;
  if (key.contains('low')) return OmcPremium.success;
  return OmcPremium.action;
}

String _titleCase(String value) => value.isEmpty
    ? value
    : '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';

String _cleanError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  final value = error.toString().replaceFirst('ApiError:', '').trim();
  return value.isEmpty ? 'Service requests are unavailable right now.' : value;
}

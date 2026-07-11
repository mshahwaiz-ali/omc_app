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
            final visible = cases
                .where((item) {
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
                })
                .toList(growable: false);

            return RefreshIndicator(
              color: OmcPremium.services,
              onRefresh: () async => ref.invalidate(serviceCasesProvider),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  _Header(cases: cases),
                  const SizedBox(height: 18),
                  _SearchField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: 14),
                  _FilterBar(
                    cases: cases,
                    selected: _filter,
                    onSelected: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 16),
                  _SummaryStrip(cases: cases),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Service Requests',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Text(
                        '${visible.length} '
                        '${visible.length == 1 ? 'result' : 'results'}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (visible.isEmpty)
                    _EmptyState(hasQuery: _query.isNotEmpty)
                  else
                    for (var index = 0; index < visible.length; index++) ...[
                      _ServiceRequestCard(serviceCase: visible[index]),
                      if (index != visible.length - 1)
                        const SizedBox(height: 16),
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
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: OmcPremium.border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textPrimary,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Requests',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$active active  •  $attention need attention',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: OmcPremium.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Search customer, request ID or service',
          hintStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textSecondary,
            size: 27,
          ),
          suffixIcon: controller.text.isEmpty
              ? const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.textSecondary,
                  size: 24,
                )
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 19),
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
    _CaseFilter.inProgress => 'Progress',
    _CaseFilter.completed => 'Done',
  };

  bool matches(ServiceCase item) => switch (this) {
    _CaseFilter.all => true,
    _CaseFilter.attention => _needsAttention(item),
    _CaseFilter.inProgress => _caseState(item).isInProgress,
    _CaseFilter.completed => _caseState(item).isCompleted,
  };
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.cases,
    required this.selected,
    required this.onSelected,
  });

  final List<ServiceCase> cases;
  final _CaseFilter selected;
  final ValueChanged<_CaseFilter> onSelected;

  int _countFor(_CaseFilter filter) {
    return cases.where(filter.matches).length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.textPrimary.withValues(alpha: 0.055),
        ),
      ),
      child: Row(
        children: [
          for (final item in _CaseFilter.values)
            Expanded(
              child: _FilterSegment(
                label: item.label,
                count: _countFor(item),
                selected: item == selected,
                showAttentionIndicator:
                    item == _CaseFilter.attention &&
                    _countFor(_CaseFilter.attention) > 0,
                onTap: () => onSelected(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({
    required this.label,
    required this.count,
    required this.selected,
    required this.showAttentionIndicator,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final bool showAttentionIndicator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(
                    color: AppTheme.textPrimary.withValues(alpha: 0.065),
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.045),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showAttentionIndicator) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: OmcPremium.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: selected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary.withValues(alpha: 0.78),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.cases});

  final List<ServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final active = cases.where((item) => !_caseState(item).isDone).length;
    final review = cases.where(_needsReview).length;
    final missing = cases.fold<int>(
      0,
      (total, item) => total + _missingCount(item),
    );
    final completed = cases
        .where((item) => _caseState(item).isCompleted)
        .length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OmcPremium.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.022),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          final width = (constraints.maxWidth - spacing) / 2;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              SizedBox(
                width: width,
                child: _SummaryTile(
                  icon: Icons.trending_up_rounded,
                  label: 'Active Requests',
                  value: active,
                  color: OmcPremium.services,
                ),
              ),
              SizedBox(
                width: width,
                child: _SummaryTile(
                  icon: Icons.rate_review_outlined,
                  label: 'Awaiting Review',
                  value: review,
                  color: OmcPremium.action,
                ),
              ),
              SizedBox(
                width: width,
                child: _SummaryTile(
                  icon: Icons.description_outlined,
                  label: 'Documents Missing',
                  value: missing,
                  color: OmcPremium.danger,
                ),
              ),
              SizedBox(
                width: width,
                child: _SummaryTile(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Completed',
                  value: completed,
                  color: OmcPremium.success,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
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
              ],
            ),
          ),
        ],
      ),
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
    final received =
        serviceCase.submittedDocumentsCount ??
        serviceCase.documentDetails
            .where((item) => item.fileUrl != null)
            .length;
    final progress = total == 0
        ? (state.isCompleted ? 1.0 : 0.0)
        : (received / total).clamp(0, 1).toDouble();
    final missing = _missingCount(serviceCase);
    final percent = (progress * 100).round();
    final route = '/my-services/${Uri.encodeComponent(serviceCase.id)}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tone.withValues(alpha: 0.20)),
            boxShadow: [
              BoxShadow(
                color: tone.withValues(alpha: 0.035),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(serviceCase: serviceCase, state: state),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppTheme.textPrimary.withValues(
                          alpha: 0.06,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(tone),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: tone,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DocumentProgress(
                received: received,
                total: total,
                missing: missing,
                progress: progress,
                color: tone,
                completed: state.isCompleted,
              ),
              const SizedBox(height: 13),
              _MetaRow(serviceCase: serviceCase, state: state),
              const SizedBox(height: 13),
              _NextAction(serviceCase: serviceCase, state: state),
              const SizedBox(height: 15),
              Divider(
                height: 1,
                color: AppTheme.textPrimary.withValues(alpha: 0.07),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      state.isCompleted
                          ? 'View completed request summary'
                          : 'Open request workspace',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    state.isCompleted ? 'View summary' : 'Open',
                    style: TextStyle(
                      color: tone,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: tone, size: 21),
                ],
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
    final reference = serviceCase.displayReference.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: state.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(_requestIcon(serviceCase), color: state.color, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      serviceCase.displayCustomerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OmcStatusBadge(label: state.label, color: state.color),
                ],
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
              if (reference.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: state.color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

IconData _requestIcon(ServiceCase serviceCase) {
  final key = '${serviceCase.title} ${serviceCase.category}'.toLowerCase();

  if (key.contains('tax')) {
    return Icons.business_center_outlined;
  }

  if (key.contains('company') || key.contains('business')) {
    return Icons.account_balance_outlined;
  }

  if (key.contains('gst') || key.contains('registration')) {
    return Icons.verified_user_outlined;
  }

  return Icons.assignment_outlined;
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
        text: completed
            ? 'Service completed successfully'
            : 'No documents required',
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
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textSecondary,
          ),
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
        color: softBackground
            ? OmcPremium.soft(color, .075)
            : Colors.transparent,
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

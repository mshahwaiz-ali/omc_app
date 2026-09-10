from pathlib import Path

SOURCE = Path(
    "omc_app/lib/features/internal_workspace/presentation/internal_operations_center_screen.dart"
)
TEST = Path(
    "omc_app/test/features/internal_workspace/internal_operations_uiux_contract_test.dart"
)


def replace_in_class(text, start_marker, end_marker, old, new, label):
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f"{label}: missing class start {start_marker}")
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f"{label}: missing class end {end_marker}")
    block = text[start:end]
    count = block.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one anchor, found {count}")
    block = block.replace(old, new, 1)
    return text[:start] + block + text[end:]


text = SOURCE.read_text()

# Live E049 loading skeleton: use the Design System V2 card radius.
text = replace_in_class(
    text,
    "class _CaseSkeletonCard",
    "class _CaseDetailsState",
    "borderRadius: BorderRadius.circular(18),",
    "borderRadius: BorderRadius.circular(AppRadius.card),",
    "case skeleton card radius",
)

# Live E049 error/not-in-current-queue state: semantic type scale, token radius,
# normal icon size, responsive primary action, and runtime button theme.
text = replace_in_class(
    text,
    "class _CaseDetailsState",
    "class _CaseProgressState",
    "borderRadius: BorderRadius.circular(17),",
    "borderRadius: BorderRadius.circular(AppRadius.control),",
    "case state icon radius",
)
text = replace_in_class(
    text,
    "class _CaseDetailsState",
    "class _CaseProgressState",
    "child: Icon(icon, size: 25, color: const Color(0xFF667085)),",
    "child: Icon(icon, size: 24, color: AppTheme.textSecondary),",
    "case state icon",
)
text = replace_in_class(
    text,
    "class _CaseDetailsState",
    "class _CaseProgressState",
    """              Text(\n                title,\n                textAlign: TextAlign.center,\n                style: const TextStyle(\n                  color: AppTheme.textPrimary,\n                  fontSize: 17,\n                  fontWeight: FontWeight.w900,\n                ),\n              ),""",
    """              Semantics(\n                header: true,\n                child: Text(\n                  title,\n                  textAlign: TextAlign.center,\n                  style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                    color: AppTheme.textPrimary,\n                  ),\n                ),\n              ),""",
    "case state title",
)
text = replace_in_class(
    text,
    "class _CaseDetailsState",
    "class _CaseProgressState",
    """              Text(\n                message,\n                textAlign: TextAlign.center,\n                style: const TextStyle(\n                  color: AppTheme.textSecondary,\n                  fontSize: 12.5,\n                  height: 1.5,\n                  fontWeight: FontWeight.w600,\n                ),\n              ),""",
    """              Text(\n                message,\n                textAlign: TextAlign.center,\n                style: Theme.of(context).textTheme.bodyMedium?.copyWith(\n                  color: AppTheme.textSecondary,\n                ),\n              ),""",
    "case state message",
)
text = replace_in_class(
    text,
    "class _CaseDetailsState",
    "class _CaseProgressState",
    """              SizedBox(\n                height: 44,\n                child: FilledButton.icon(\n                  onPressed: onAction,\n                  icon: Icon(actionIcon, size: 18),\n                  label: Text(actionLabel),\n                  style: FilledButton.styleFrom(\n                    backgroundColor: const Color(0xFF263244),\n                    foregroundColor: Colors.white,\n                    shape: RoundedRectangleBorder(\n                      borderRadius: BorderRadius.circular(13),\n                    ),\n                    textStyle: const TextStyle(\n                      fontSize: 12.5,\n                      fontWeight: FontWeight.w900,\n                    ),\n                  ),\n                ),\n              ),""",
    """              SizedBox(\n                width: double.infinity,\n                child: FilledButton.icon(\n                  onPressed: onAction,\n                  icon: Icon(actionIcon),\n                  label: Text(actionLabel),\n                ),\n              ),""",
    "case state primary action",
)

# Live E048 loading card follows the bounded-card radius contract.
text = replace_in_class(
    text,
    "class _LoadingCard",
    "class _OperationsError",
    "borderRadius: BorderRadius.circular(24),",
    "borderRadius: BorderRadius.circular(AppRadius.card),",
    "operations loading card radius",
)

# Live E048 error state: important copy uses semantic roles and decorative icon <=32.
text = replace_in_class(
    text,
    "class _OperationsError",
    "class _OperationsEmpty",
    "size: 34,",
    "size: 32,",
    "operations error icon",
)
text = replace_in_class(
    text,
    "class _OperationsError",
    "class _OperationsEmpty",
    """              Text(\n                title,\n                textAlign: TextAlign.center,\n                style: const TextStyle(\n                  color: AppTheme.textPrimary,\n                  fontSize: 18,\n                  fontWeight: FontWeight.w900,\n                ),\n              ),""",
    """              Semantics(\n                header: true,\n                child: Text(\n                  title,\n                  textAlign: TextAlign.center,\n                  style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                    color: AppTheme.textPrimary,\n                  ),\n                ),\n              ),""",
    "operations error title",
)
text = replace_in_class(
    text,
    "class _OperationsError",
    "class _OperationsEmpty",
    """              Text(\n                message,\n                textAlign: TextAlign.center,\n                style: const TextStyle(\n                  color: AppTheme.textSecondary,\n                  fontSize: 13,\n                  height: 1.35,\n                  fontWeight: FontWeight.w600,\n                ),\n              ),""",
    """              Text(\n                message,\n                textAlign: TextAlign.center,\n                style: Theme.of(context).textTheme.bodyMedium?.copyWith(\n                  color: AppTheme.textSecondary,\n                ),\n              ),""",
    "operations error message",
)

# Live E048 empty state: same semantic treatment; no tiny important text.
text = replace_in_class(
    text,
    "class _OperationsEmpty",
    "class _PaymentReviewListView",
    "size: 34",
    "size: 32",
    "operations empty icon",
)
text = replace_in_class(
    text,
    "class _OperationsEmpty",
    "class _PaymentReviewListView",
    """          Text(\n            title,\n            textAlign: TextAlign.center,\n            style: const TextStyle(\n              color: AppTheme.textPrimary,\n              fontSize: 18,\n              fontWeight: FontWeight.w900,\n            ),\n          ),""",
    """          Semantics(\n            header: true,\n            child: Text(\n              title,\n              textAlign: TextAlign.center,\n              style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                color: AppTheme.textPrimary,\n              ),\n            ),\n          ),""",
    "operations empty title",
)
text = replace_in_class(
    text,
    "class _OperationsEmpty",
    "class _PaymentReviewListView",
    """          Text(\n            message,\n            textAlign: TextAlign.center,\n            style: const TextStyle(\n              color: AppTheme.textSecondary,\n              fontSize: 13,\n              height: 1.35,\n              fontWeight: FontWeight.w600,\n            ),\n          ),""",
    """          Text(\n            message,\n            textAlign: TextAlign.center,\n            style: Theme.of(context).textTheme.bodyMedium?.copyWith(\n              color: AppTheme.textSecondary,\n            ),\n          ),""",
    "operations empty message",
)

# Metric labels are required to interpret their values, so use supporting text,
# not caption text. Both containers already grow with content.
text = replace_in_class(
    text,
    "class _PaymentPageMetricView",
    "class _PaymentResultsHeader",
    "style: Theme.of(context).textTheme.bodySmall,",
    "style: Theme.of(context).textTheme.bodyMedium,",
    "payment metric label",
)
text = replace_in_class(
    text,
    "class _CaseEvidenceMetricViewV2",
    "class _CaseOverviewV2",
    "style: Theme.of(context).textTheme.bodySmall,",
    "style: Theme.of(context).textTheme.bodyMedium,",
    "case evidence metric label",
)

# Workflow state is meaningful status information and cannot be caption-sized.
text = replace_in_class(
    text,
    "class _CaseProgressRowV2",
    "class _CaseTimelineV2",
    "style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),",
    "style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),",
    "case progress state label",
)

# Make loading/error standalone lists use the same responsive general-page inset
# and max width as the live V2 content. Empty state is embedded in that V2 list.
state_list = """
class _OperationsStateListView extends StatelessWidget {
  const _OperationsStateListView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageInset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal =
            constraints.maxWidth > AppLayout.generalMaxWidth + AppSpacing.xl * 2
            ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
            : pageInset;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontal,
            12,
            horizontal,
            AppSpacing.xl,
          ),
          children: children,
        );
      },
    );
  }
}

"""
marker = "class _CaseDetailsLoading extends StatelessWidget {"
if state_list.strip() not in text:
    if text.count(marker) != 1:
        raise SystemExit("state list insertion: missing/duplicate marker")
    text = text.replace(marker, state_list + marker, 1)

text = replace_in_class(
    text,
    "class _CaseDetailsLoading",
    "class _CaseSkeletonCard",
    """    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: _kOpsPadding,\n      children: const [""",
    """    return const _OperationsStateListView(\n      children: [""",
    "case details loading responsive list",
)
text = replace_in_class(
    text,
    "class _CaseDetailsState",
    "class _CaseProgressState",
    """    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: _kOpsPadding,\n      children: [""",
    """    return _OperationsStateListView(\n      children: [""",
    "case details state responsive list",
)
text = replace_in_class(
    text,
    "class _OperationsLoading",
    "class _LoadingCard",
    """    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: _kOpsPadding,\n      children: const [""",
    """    return const _OperationsStateListView(\n      children: [""",
    "operations loading responsive list",
)
text = replace_in_class(
    text,
    "class _OperationsError",
    "class _OperationsEmpty",
    """    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: _kOpsPadding,\n      children: [""",
    """    return _OperationsStateListView(\n      children: [""",
    "operations error responsive list",
)

SOURCE.write_text(text)

TEST.parent.mkdir(parents=True, exist_ok=True)
TEST.write_text(
    r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _block(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'missing $start');
  expect(endIndex, greaterThan(startIndex), reason: 'missing $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  final router = File('lib/app/router.dart').readAsStringSync();
  final source = File(
    'lib/features/internal_workspace/presentation/internal_operations_center_screen.dart',
  ).readAsStringSync();

  test('router keeps dedicated customer/document owners and V2 payment owner', () {
    expect(
      router,
      contains("path: '/internal-workspace/customers'"),
    );
    expect(router, contains('const CustomersScreen()'));
    expect(
      router,
      contains("path: '/internal-workspace/documents'"),
    );
    expect(router, contains('const InternalDocumentReviewScreen()'));
    expect(
      router,
      contains('const InternalOperationsCenterScreen(\n            area: InternalOperationArea.payments,'),
    );
  });

  test('live internal operation states use V2 scale, targets and radii', () {
    final caseState = _block(
      source,
      'class _CaseDetailsState',
      'class _CaseProgressState',
    );
    expect(caseState, contains('textTheme.titleMedium'));
    expect(caseState, contains('textTheme.bodyMedium'));
    expect(caseState, contains('width: double.infinity'));
    expect(caseState, contains('BorderRadius.circular(AppRadius.control)'));
    expect(caseState, isNot(contains('height: 44')));
    expect(caseState, isNot(contains('FontWeight.w900')));
    expect(caseState, isNot(contains('fontSize: 12.5')));
    expect(caseState, isNot(contains('backgroundColor: const Color(0xFF263244)')));

    final loadingCard = _block(
      source,
      'class _LoadingCard',
      'class _OperationsError',
    );
    expect(loadingCard, contains('BorderRadius.circular(AppRadius.card)'));

    final skeleton = _block(
      source,
      'class _CaseSkeletonCard',
      'class _CaseDetailsState',
    );
    expect(skeleton, contains('BorderRadius.circular(AppRadius.card)'));
  });

  test('live metrics and workflow state do not use caption typography', () {
    final paymentMetric = _block(
      source,
      'class _PaymentPageMetricView',
      'class _PaymentResultsHeader',
    );
    expect(paymentMetric, contains('textTheme.bodyMedium'));
    expect(paymentMetric, isNot(contains('textTheme.bodySmall')));

    final evidenceMetric = _block(
      source,
      'class _CaseEvidenceMetricViewV2',
      'class _CaseOverviewV2',
    );
    expect(evidenceMetric, contains('textTheme.bodyMedium'));
    expect(evidenceMetric, isNot(contains('textTheme.bodySmall')));

    final progressRow = _block(
      source,
      'class _CaseProgressRowV2',
      'class _CaseTimelineV2',
    );
    expect(progressRow, contains('textTheme.labelMedium?.copyWith(color: color)'));
    expect(
      progressRow,
      isNot(contains('textTheme.bodySmall?.copyWith(color: color)')),
    );
  });

  test('standalone live loading and error states use responsive page layout', () {
    final stateList = _block(
      source,
      'class _OperationsStateListView',
      'class _CaseDetailsLoading',
    );
    expect(stateList, contains('AppLayout.pageInsetFor(constraints.maxWidth)'));
    expect(stateList, contains('AppLayout.generalMaxWidth'));

    for (final pair in const [
      ['class _CaseDetailsLoading', 'class _CaseSkeletonCard'],
      ['class _CaseDetailsState', 'class _CaseProgressState'],
      ['class _OperationsLoading', 'class _LoadingCard'],
      ['class _OperationsError', 'class _OperationsEmpty'],
    ]) {
      final block = _block(source, pair[0], pair[1]);
      expect(block, contains('_OperationsStateListView('));
      expect(block, isNot(contains('padding: _kOpsPadding')));
    }
  });
}
'''
)

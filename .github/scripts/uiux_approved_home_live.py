from pathlib import Path

view_path = Path('omc_app/lib/features/home/presentation/approved_customer_home_view.dart')
service_path = Path('omc_app/lib/features/home/presentation/approved_customer_home_service_widgets.dart')
support_path = Path('omc_app/lib/features/home/presentation/approved_customer_home_support.dart')
test_path = Path('omc_app/test/features/home/approved_home_uiux_contract_test.dart')


def once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, found {count}')
    return text.replace(old, new, 1)


def replace_in_block(text, start_marker, end_marker, old, new, label):
    start = text.index(start_marker)
    end = text.index(end_marker, start)
    block = text[start:end]
    block = once(block, old, new, label)
    return text[:start] + block + text[end:]


view = view_path.read_text()
helper = '''class _CustomerHomeListView extends StatelessWidget {
  const _CustomerHomeListView({required this.children});

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
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            horizontal,
            18,
            horizontal,
            AppSpacing.xl,
          ),
          children: children,
        );
      },
    );
  }
}

'''
marker = 'class _CustomerHomeContent extends StatelessWidget {'
if helper.strip() not in view:
    view = once(view, marker, helper + marker, 'approved home responsive list insertion')

old = '''            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl),
              children: ['''
new = '''            child: _CustomerHomeListView(
              children: ['''
view = once(view, old, new, 'approved home error list')

old = '''    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl),
      children: ['''
new = '''    return _CustomerHomeListView(
      children: ['''
view = once(view, old, new, 'approved home content list')
view_path.write_text(view)

service = service_path.read_text()
service = service.replace(
    'borderRadius: BorderRadius.circular(12),',
    'borderRadius: BorderRadius.circular(AppRadius.control),',
)
service = service.replace(
    'borderRadius: BorderRadius.circular(999),',
    'borderRadius: BorderRadius.circular(AppRadius.pill),',
)
service = once(
    service,
    '''                            fontSize: 10,
                            fontWeight: FontWeight.w700,''',
    '''                            fontSize: 11,
                            fontWeight: FontWeight.w600,''',
    'approved home notification badge typography',
)
service = replace_in_block(
    service,
    'class _CurrentServiceCard',
    'class _ServiceJourneyExpansion',
    'padding: const EdgeInsets.all(18),',
    'padding: const EdgeInsets.all(AppSpacing.lg),',
    'approved home current service card padding',
)
service = replace_in_block(
    service,
    'class _CompactServiceCard',
    'class _NoActiveServiceCard',
    'padding: const EdgeInsets.all(14),',
    'padding: const EdgeInsets.all(AppSpacing.md),',
    'approved home compact service card padding',
)
service_path.write_text(service)

support = support_path.read_text()
old = '''    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl),
      children: const ['''
new = '''    return const _CustomerHomeListView(
      children: ['''
support = once(support, old, new, 'approved home loading responsive list')
support = once(
    support,
    'borderRadius: BorderRadius.circular(22),',
    'borderRadius: BorderRadius.circular(AppRadius.card),',
    'approved home loading radius',
)
support_path.write_text(support)

test_path.parent.mkdir(parents=True, exist_ok=True)
test_path.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dispatcher = File(
    'lib/features/home/presentation/home_screen_dispatcher.dart',
  ).readAsStringSync();
  final view = File(
    'lib/features/home/presentation/approved_customer_home_view.dart',
  ).readAsStringSync();
  final service = File(
    'lib/features/home/presentation/approved_customer_home_service_widgets.dart',
  ).readAsStringSync();
  final support = File(
    'lib/features/home/presentation/approved_customer_home_support.dart',
  ).readAsStringSync();

  test('approved customer home remains the lifecycle customer owner', () {
    expect(dispatcher, contains('ApprovedCustomerHomeView('));
    expect(dispatcher, contains('useLifecycleCustomerHome'));
  });

  test('approved home uses responsive V2 page insets and bounded width', () {
    expect(view, contains('class _CustomerHomeListView'));
    expect(view, contains('AppLayout.pageInsetFor(constraints.maxWidth)'));
    expect(view, contains('AppLayout.generalMaxWidth'));
    expect(view, contains('child: _CustomerHomeListView('));
    expect(view, contains('return _CustomerHomeListView('));
    expect(
      view,
      isNot(contains('padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl)')),
    );
    expect(support, contains('return const _CustomerHomeListView('));
  });

  test('approved home live cards use the V2 badge, spacing and radius tokens', () {
    expect(service, contains('fontSize: 11'));
    expect(service, isNot(contains('fontSize: 10,')));
    expect(service, contains('padding: const EdgeInsets.all(AppSpacing.lg)'));
    expect(service, contains('padding: const EdgeInsets.all(AppSpacing.md)'));
    expect(service, contains('BorderRadius.circular(AppRadius.control)'));
    expect(service, contains('BorderRadius.circular(AppRadius.pill)'));
    expect(support, contains('BorderRadius.circular(AppRadius.card)'));
    expect(support, isNot(contains('BorderRadius.circular(22)')));
  });
}
''')

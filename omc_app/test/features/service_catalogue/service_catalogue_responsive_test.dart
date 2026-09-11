import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/theme.dart';
import 'package:omc_app/core/widgets/premium_card.dart';
import 'package:omc_app/features/auth/application/auth_controller.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/service_catalogue/application/service_catalogue_controller.dart';
import 'package:omc_app/features/service_catalogue/data/service_catalogue_repository.dart';
import 'package:omc_app/features/service_catalogue/data/service_item.dart';
import 'package:omc_app/features/service_catalogue/presentation/service_catalogue_screen_impl.dart';

class _GuestAuthController extends AuthController {
  @override
  AuthState build() => const AuthState.guest();
}

const _services = <ServiceItem>[
  ServiceItem(
    id: 'SERVICE-ALPHA',
    title: 'Income Tax Return Filing',
    category: 'Tax',
    feeLabel: 'PKR 5,000',
    completionTime: '3 days',
    requirements: [],
  ),
  ServiceItem(
    id: 'SERVICE-BETA',
    title: 'Sales Tax Registration',
    category: 'Tax',
    feeLabel: 'PKR 6,000',
    completionTime: '4 days',
    requirements: [],
  ),
  ServiceItem(
    id: 'SERVICE-GAMMA',
    title: 'Company Compliance Review',
    category: 'Corporate',
    feeLabel: 'PKR 7,000',
    completionTime: '5 days',
    requirements: [],
  ),
  ServiceItem(
    id: 'SERVICE-DELTA',
    title:
        'Corporate regulatory compliance and annual filing support for growing businesses',
    category: 'Corporate',
    feeLabel: 'PKR 8,000',
    completionTime: '6 days',
    requirements: [],
  ),
];

void _setView(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 2600);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpCatalogue(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  _setView(tester, width);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_GuestAuthController.new),
        serviceCatalogueCategoriesProvider.overrideWith(
          (ref) async => const ['Corporate', 'Tax'],
        ),
        serviceCataloguePageProvider.overrideWith(
          (ref, query) async => const ServiceCataloguePage(_services, null),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: const Scaffold(body: ServiceCatalogueScreen()),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Offset _position(WidgetTester tester, String title) {
  return tester.getTopLeft(find.text(title));
}

void main() {
  testWidgets('320px catalogue uses one readable column', (tester) async {
    await _pumpCatalogue(tester, width: 320, textScale: 1);

    final first = _position(tester, 'Income Tax Return Filing');
    final second = _position(tester, 'Sales Tax Registration');

    expect((first.dx - second.dx).abs(), lessThan(2));
    expect(second.dy, greaterThan(first.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('standard phone catalogue uses two columns', (tester) async {
    await _pumpCatalogue(tester, width: 390, textScale: 1);

    final first = _position(tester, 'Income Tax Return Filing');
    final second = _position(tester, 'Sales Tax Registration');

    expect((first.dy - second.dy).abs(), lessThan(2));
    expect(second.dx, greaterThan(first.dx));

    final firstTitle = find.text('Income Tax Return Filing');
    expect(
      find.ancestor(of: firstTitle, matching: find.byType(PremiumCard)),
      findsNothing,
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet catalogue allows three columns', (tester) async {
    await _pumpCatalogue(tester, width: 768, textScale: 1);

    final first = _position(tester, 'Income Tax Return Filing');
    final second = _position(tester, 'Sales Tax Registration');
    final third = _position(tester, 'Company Compliance Review');
    final fourth = _position(
      tester,
      'Corporate regulatory compliance and annual filing support for growing businesses',
    );

    expect((first.dy - second.dy).abs(), lessThan(2));
    expect((first.dy - third.dy).abs(), lessThan(2));
    expect(first.dx, lessThan(second.dx));
    expect(second.dx, lessThan(third.dx));
    expect(fourth.dy, greaterThan(first.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'very wide catalogue stays centered and never exceeds three columns',
    (tester) async {
      await _pumpCatalogue(tester, width: 1400, textScale: 1);

      final first = _position(tester, 'Income Tax Return Filing');
      final second = _position(tester, 'Sales Tax Registration');
      final third = _position(tester, 'Company Compliance Review');
      final fourth = _position(
        tester,
        'Corporate regulatory compliance and annual filing support for growing businesses',
      );

      expect(first.dx, greaterThan(250));
      expect((first.dy - second.dy).abs(), lessThan(2));
      expect((first.dy - third.dy).abs(), lessThan(2));
      expect(fourth.dy, greaterThan(first.dy));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text forces one column and preserves full long title', (
    tester,
  ) async {
    await _pumpCatalogue(tester, width: 430, textScale: 2);

    final first = _position(tester, 'Income Tax Return Filing');
    final second = _position(tester, 'Sales Tax Registration');

    expect((first.dx - second.dx).abs(), lessThan(2));
    expect(second.dy, greaterThan(first.dy));
    expect(
      find.text(
        'Corporate regulatory compliance and annual filing support for growing businesses',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

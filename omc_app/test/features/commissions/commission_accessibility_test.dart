import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/commissions/data/commission_repository.dart';
import 'package:omc_app/features/commissions/presentation/my_commissions_screen.dart';

void main() {
  testWidgets('commission list supports 320px width and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<CommissionPage> load({
      int start = 0,
      int limit = 20,
      String? periodMonth,
      String? status,
      String? customerProfile,
      String? service,
    }) async {
      return CommissionPage(
        items: [
          CommissionEarning(
            id: 'OMC-COM-1',
            status: 'Earned',
            customer: 'A customer name intentionally long enough to wrap',
            service: 'Annual income tax preparation and filing assistance',
            request: 'OMC-SR-1',
            currency: 'PKR',
            basis: 10000,
            percent: 10,
            amount: 1000,
            earnedOn: '2026-08-16',
            settlement: '',
            reversalReason: '',
          ),
        ],
        hasMore: false,
        nextStart: 1,
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          commissionPageLoaderProvider.overrideWithValue(load),
          commissionSummaryLoaderProvider.overrideWithValue(
            ({String? periodMonth}) async => const [
              CommissionSummary(
                currency: 'PKR',
                outstanding: 1000,
                settled: 0,
                reversed: 0,
                count: 1,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const MyCommissionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My commissions'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.textContaining('Annual income tax'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

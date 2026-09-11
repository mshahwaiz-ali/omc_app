import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/documents/data/document_attachment.dart';
import 'package:omc_app/features/service_requests/data/service_request_repository.dart';
import 'package:omc_app/features/service_requests/presentation/assisted_customer_card.dart';

class _FakeServiceRequestRepository implements ServiceRequestRepository {
  int selectionCalls = 0;

  @override
  Future<AssistedCustomerSelection> getAssistedCustomerSelection({
    String? customerMode,
    String? search,
    int limitStart = 0,
    int limitPageLength = 50,
  }) async {
    selectionCalls += 1;

    if ((customerMode ?? '').isEmpty) {
      return const AssistedCustomerSelection(modes: ['My Referral'], items: []);
    }

    return const AssistedCustomerSelection(
      modes: ['My Referral'],
      selectedMode: 'My Referral',
      items: [
        AssistedCustomerOption(
          mode: 'My Referral',
          id: 'OMC-CUST-QA-1',
          fullName: 'QA Referral Customer',
          email: 'qa.referral1@example.com',
          phone: '03000000001',
          consentGranted: true,
        ),
      ],
    );
  }

  @override
  Future<ServiceRequestResult> createServiceRequest(
    ServiceRequestPayload payload, {
    String? idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> uploadRequestAttachments({
    required String requestId,
    required List<DocumentAttachment> attachments,
    String? documentTitle,
    String? documentType,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('assisted customer state survives scrolling offscreen and back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 700);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _FakeServiceRequestRepository();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceRequestRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              children: [
                AssistedCustomerCard(onChanged: (_) {}),
                const SizedBox(height: 1800),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(repository.selectionCalls, 2);

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Name, phone, email or customer ID',
    );

    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'preserve this search');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    controller.jumpTo(0);
    await tester.pumpAndSettle();

    expect(repository.selectionCalls, 2);

    final restoredField = tester.widget<TextField>(searchField);
    expect(restoredField.controller?.text, 'preserve this search');

    expect(tester.takeException(), isNull);
  });
}

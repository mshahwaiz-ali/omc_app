import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/omc_widget_keys.dart';

import '../support/e2e_config.dart';
import '../support/e2e_record_finders.dart';
import '../support/e2e_waits.dart';

class CustomerJourneyRobot {
  CustomerJourneyRobot(this.tester, this.waits);

  final WidgetTester tester;
  final E2eWaits waits;

  Future<void> createRequestAndSubmitReceipt(E2eConfig config) async {
    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.navServices),
      destination: find.byKey(OmcWidgetKeys.servicesScreen),
      description: 'Customer journey -> Services',
    );

    final serviceTile = find.bySemanticsLabel(config.serviceTitle.trim());
    await waits.waitFor(
      serviceTile,
      description: 'Published service ${config.serviceTitle}',
      timeout: const Duration(seconds: 20),
    );
    await tester.ensureVisible(serviceTile.first);
    await tester.tap(serviceTile.first.hitTestable());
    await tester.pump();
    await waits.waitFor(
      find.text('Service Details'),
      description: 'Service detail screen',
    );
    await waits.waitForNetworkIdle(description: 'Service detail screen');
    waits.assertHealthy('Service detail screen');

    final startRequest = find.byKey(OmcWidgetKeys.serviceStartRequest);
    await tester.scrollUntilVisible(
      startRequest,
      350,
      scrollable: find.descendant(
        of: find.byKey(OmcWidgetKeys.serviceDetailScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await waits.waitFor(startRequest, description: 'Start request action');
    await tester.ensureVisible(startRequest.first);
    await tester.tap(startRequest.first.hitTestable());
    await tester.pump();

    final startState = await waits.waitForAny({
      'draft': find.text('Client details'),
      'duplicate': find.text('Service already in progress'),
    }, description: 'Start request destination');
    if (startState == 'duplicate') {
      fail(
        'The selected E2E customer already has an active '
        '${config.serviceTitle} request. Use a clean approved customer or '
        'a service that permits a fresh request; the E2E does not bypass '
        'duplicate protection.',
      );
    }

    await _fillRequestForm(config);
    await _submitRequest();
    await _uploadAllRequiredDocuments();
    await _openPaymentAndSubmitReceipt();
  }

  Future<void> verifySettledActivatedRequest(E2eConfig config) async {
    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.navTrack),
      destination: find.byKey(OmcWidgetKeys.trackScreen),
      description: 'Customer verification -> Track',
    );

    final search = find.byType(TextField);
    await waits.waitFor(search, description: 'Track request search');
    await tester.enterText(search.first, config.requestId.trim());
    await tester.pump(const Duration(milliseconds: 400));
    await waits.waitForNetworkIdle(description: 'Filtered request tracking');

    final requestCard = E2eRecordFinders.requestCard(config.requestId);
    await waits.waitFor(
      requestCard,
      description: 'Settled request card ${config.requestId}',
      timeout: const Duration(seconds: 20),
    );
    await tester.ensureVisible(requestCard.first);
    await tester.tap(requestCard.first.hitTestable());
    await tester.pump();

    await waits.waitFor(
      find.text('Service journey'),
      description: 'Settled request detail',
      timeout: const Duration(seconds: 20),
    );
    await waits.waitForNetworkIdle(description: 'Settled request detail');

    expect(
      find.text(config.requestId.trim()),
      findsWidgets,
      reason: 'The request detail must identify the exact settled E2E case.',
    );

    final paymentCard = find.byKey(OmcWidgetKeys.customerCasePayment);
    await tester.scrollUntilVisible(
      paymentCard,
      350,
      scrollable: find.descendant(
        of: find.byKey(OmcWidgetKeys.customerCaseDetailScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await waits.waitFor(
      paymentCard.first,
      description: 'Settled customer payment card',
    );
    expect(
      find.text('Paid'),
      findsWidgets,
      reason: 'ERP settlement must project back to the customer payment state.',
    );
    expect(
      find.text('Payment under review'),
      findsNothing,
      reason: 'A settled payment must not remain presented as under review.',
    );
    expect(
      find.text('Payment not available yet'),
      findsNothing,
      reason: 'The payment lifecycle must remain visible after settlement.',
    );
    waits.assertHealthy('Settled and activated customer request');
  }

  Future<void> _fillRequestForm(E2eConfig config) async {
    await tester.pump(const Duration(milliseconds: 800));

    for (var pass = 0; pass < 50; pass++) {
      final textFields = find.byType(TextFormField);
      Finder? nextRequiredField;
      var nextRequiredLabel = '';

      for (var index = 0; index < textFields.evaluate().length; index++) {
        final finder = textFields.at(index);
        final widget = tester.widget<TextFormField>(finder);
        final decorator = find.descendant(
          of: finder,
          matching: find.byType(InputDecorator),
        );
        final label = decorator.evaluate().isEmpty
            ? ''
            : tester
                      .widget<InputDecorator>(decorator.first)
                      .decoration
                      .labelText
                      ?.trim() ??
                  '';
        final current = widget.controller?.text.trim() ?? '';
        if (current.isNotEmpty) continue;

        final required =
            label == 'Full name' ||
            label == 'Phone or WhatsApp number' ||
            label == 'Email' ||
            label.endsWith('*');
        if (!required) continue;

        nextRequiredField = finder;
        nextRequiredLabel = label;
        break;
      }

      if (nextRequiredField == null) break;
      await tester.ensureVisible(nextRequiredField);
      await tester.enterText(
        nextRequiredField,
        _valueForTextField(nextRequiredLabel, config),
      );
      await tester.pump(const Duration(milliseconds: 100));

      if (pass == 49) {
        fail('More than 50 dynamic required fields were requested; aborting.');
      }
    }

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    final dropdownCount = dropdowns.evaluate().length;
    for (var index = 0; index < dropdownCount; index++) {
      final finder = dropdowns.at(index);
      final dropdown = find.descendant(
        of: finder,
        matching: find.byType(DropdownButton<String>),
      );
      if (dropdown.evaluate().isEmpty) continue;
      final items =
          tester.widget<DropdownButton<String>>(dropdown.first).items ??
          const <DropdownMenuItem<String>>[];
      if (items.isEmpty) continue;
      final firstValue = items
          .map((item) => item.value)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .firstOrNull;
      if (firstValue == null) continue;

      await tester.ensureVisible(finder);
      await tester.tap(finder.hitTestable());
      await tester.pump(const Duration(milliseconds: 250));
      final option = find.text(firstValue);
      if (option.evaluate().isNotEmpty) {
        await tester.tap(option.last.hitTestable());
        await tester.pump(const Duration(milliseconds: 250));
      } else {
        fail(
          'Dropdown option "$firstValue" could not be selected in the real form.',
        );
      }
    }

    final checks = find.byType(CheckboxListTile);
    final checkCount = checks.evaluate().length;
    for (var index = 0; index < checkCount; index++) {
      final finder = checks.at(index);
      final widget = tester.widget<CheckboxListTile>(finder);
      if (widget.value == true || widget.onChanged == null) continue;
      await tester.ensureVisible(finder);
      await tester.tap(finder.hitTestable());
      await tester.pump(const Duration(milliseconds: 100));
    }

    waits.assertHealthy('Customer request form completion');
  }

  String _valueForTextField(String label, E2eConfig config) {
    final normalized = label.toLowerCase();
    if (normalized.contains('email')) {
      return config.username.contains('@')
          ? config.username.trim()
          : 'omc-e2e@example.com';
    }
    if (normalized.contains('phone') ||
        normalized.contains('mobile') ||
        normalized.contains('whatsapp')) {
      return '03001234567';
    }
    if (normalized.contains('name')) return 'OMC E2E Customer';
    if (normalized.contains('date')) return '2026-08-27';
    if (normalized.contains('year')) return '2026';
    if (normalized.contains('amount') ||
        normalized.contains('number') ||
        normalized.contains('count') ||
        normalized.contains('quantity') ||
        normalized.contains('income') ||
        normalized.contains('turnover')) {
      return '1';
    }
    return 'OMC E2E customer journey';
  }

  Future<void> _submitRequest() async {
    final submit = find.text('Submit');
    await waits.waitFor(submit, description: 'Submit service request');
    await tester.ensureVisible(submit.first);
    await tester.tap(submit.first.hitTestable());
    await tester.pump();

    final validation = find.textContaining(
      RegExp(r'(is required|Enter a valid)'),
    );
    final submitState = await waits.waitForAny(
      {
        'submitted': find.text('Required documents'),
        'accepted': find.text('Service request submitted to OMC.'),
        'duplicate': find.text(
          'An active request already exists for this customer and service.',
        ),
        'snackbar': find.byType(SnackBar),
        'validation': validation,
      },
      description: 'Submitted customer request result',
      timeout: const Duration(seconds: 30),
    );
    if (submitState == 'duplicate') {
      fail(
        'The backend returned an existing active request after submission; '
        'the E2E requires a newly created request.',
      );
    }
    if (submitState == 'accepted') {
      await waits.waitFor(
        find.text('Required documents'),
        description: 'Newly submitted customer request detail',
        timeout: const Duration(seconds: 30),
      );
    }
    if (submitState != 'submitted') {
      if (submitState == 'accepted') {
        await _allowExpectedSuccessSnackbarToClose();
      } else {
        final source = submitState == 'snackbar'
            ? find.descendant(
                of: find.byType(SnackBar),
                matching: find.byType(Text),
              )
            : validation;
        final messages = source
            .evaluate()
            .map((element) => element.widget)
            .whereType<Text>()
            .map((widget) => widget.data)
            .whereType<String>()
            .where((message) => message.trim().isNotEmpty)
            .toSet()
            .join(' | ');
        fail(
          'Customer request submission failed with $submitState'
          '${messages.isEmpty ? '.' : ': $messages'}',
        );
      }
    }
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      await _allowExpectedSuccessSnackbarToClose();
    }
    await waits.waitForNetworkIdle(
      description: 'Submitted customer request detail',
      timeout: const Duration(seconds: 20),
    );
    waits.assertHealthy('Submitted customer request detail');
  }

  Future<void> _uploadAllRequiredDocuments() async {
    for (var uploadIndex = 0; uploadIndex < 20; uploadIndex++) {
      final upload = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('case.document.') &&
            key.value.endsWith('.upload');
      });
      if (upload.evaluate().isEmpty) break;

      await tester.ensureVisible(upload.first);
      await tester.pump(const Duration(milliseconds: 100));
      await waits.waitFor(
        upload.hitTestable(),
        description: 'Tappable required document ${uploadIndex + 1}',
      );
      await tester.tap(upload.hitTestable().first);
      await tester.pump();
      final uploadState = await waits.waitForAny(
        {
          'uploaded': find.textContaining('uploaded successfully.'),
          'snackbar': find.byType(SnackBar),
        },
        description: 'Required document upload ${uploadIndex + 1}',
        timeout: const Duration(seconds: 30),
      );
      if (uploadState != 'uploaded') {
        final messages = find
            .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
            .evaluate()
            .map((element) => element.widget)
            .whereType<Text>()
            .map((widget) => widget.data)
            .whereType<String>()
            .where((message) => message.trim().isNotEmpty)
            .toSet()
            .join(' | ');
        fail(
          'Required document upload ${uploadIndex + 1} failed'
          '${messages.isEmpty ? '.' : ': $messages'}',
        );
      }
      await _allowExpectedSuccessSnackbarToClose();
      await waits.waitForNetworkIdle(
        description: 'Required document upload ${uploadIndex + 1}',
        timeout: const Duration(seconds: 20),
      );
    }

    final remainingUpload = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('case.document.') &&
          key.value.endsWith('.upload');
    });
    if (remainingUpload.evaluate().isNotEmpty) {
      fail('More than 20 required document uploads were requested; aborting.');
    }

    final openPayments = find.text('Open payments');
    await waits.waitFor(
      openPayments,
      description: 'Payment opens after required documents are uploaded',
      timeout: const Duration(seconds: 30),
    );
    waits.assertHealthy('Required-document completion opened payment');
  }

  Future<void> _openPaymentAndSubmitReceipt() async {
    final openPayments = find.text('Open payments');
    await tester.ensureVisible(openPayments.first);
    await tester.tap(openPayments.first.hitTestable());
    await tester.pump();

    await waits.waitForScreen(
      find.byKey(OmcWidgetKeys.paymentDetailScreen),
      description: 'Customer payment detail',
      timeout: const Duration(seconds: 20),
    );

    final uploadProof = find.byKey(OmcWidgetKeys.paymentUploadReceipt);
    await tester.scrollUntilVisible(
      uploadProof,
      350,
      scrollable: find
          .descendant(
            of: find.byKey(OmcWidgetKeys.paymentDetailScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await waits.waitFor(
      uploadProof,
      description: 'Upload payment proof action',
    );
    await tester.ensureVisible(uploadProof.first);
    await tester.tap(uploadProof.first.hitTestable());
    await tester.pump();

    final receiptState = await waits.waitForAny(
      {
        'submitted': find.text('Receipt Submitted'),
        'accepted': find.text('Receipt uploaded for OMC review.'),
        'snackbar': find.byType(SnackBar),
      },
      description: 'Receipt submitted payment status',
      timeout: const Duration(seconds: 30),
    );
    if (receiptState == 'accepted') {
      await tester.scrollUntilVisible(
        find.text('Receipt Submitted'),
        -350,
        scrollable: find
            .descendant(
              of: find.byKey(OmcWidgetKeys.paymentDetailScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await waits.waitFor(
        find.text('Receipt Submitted'),
        description: 'Refreshed receipt submitted payment status',
        timeout: const Duration(seconds: 30),
      );
    } else if (receiptState != 'submitted') {
      final messages = find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
          .evaluate()
          .map((element) => element.widget)
          .whereType<Text>()
          .map((widget) => widget.data)
          .whereType<String>()
          .where((message) => message.trim().isNotEmpty)
          .toSet()
          .join(' | ');
      fail(
        'Payment receipt upload failed'
        '${messages.isEmpty ? '.' : ': $messages'}',
      );
    }
    await _allowExpectedSuccessSnackbarToClose();
    await waits.waitForNetworkIdle(
      description: 'Receipt submitted payment status',
      timeout: const Duration(seconds: 20),
    );
    waits.assertHealthy('Receipt submitted payment status');
  }

  Future<void> _allowExpectedSuccessSnackbarToClose() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (find.byType(SnackBar).evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      fail('Expected success snackbar did not close within 5 seconds.');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/omc_widget_keys.dart';

import '../support/e2e_config.dart';
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

    final startRequest = find.text('Start request');
    await waits.waitFor(startRequest, description: 'Start request action');
    await tester.ensureVisible(startRequest.first);
    await tester.tap(startRequest.first.hitTestable());
    await tester.pump();

    await waits.waitForAny(
      {
        'draft': find.text('Client details'),
        'duplicate': find.text('Service already in progress'),
      },
      description: 'Start request destination',
    ).then((state) async {
      if (state == 'duplicate') {
        fail(
          'The selected E2E customer already has an active '
          '${config.serviceTitle} request. Use a clean approved customer or '
          'a service that permits a fresh request; the E2E does not bypass '
          'duplicate protection.',
        );
      }
    });

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

    final requestReference = find.text(config.requestId.trim());
    await waits.waitFor(
      requestReference,
      description: 'Settled request ${config.requestId}',
      timeout: const Duration(seconds: 20),
    );

    final viewDetails = find.text('View details');
    await waits.waitFor(viewDetails, description: 'Open settled request');
    await tester.ensureVisible(viewDetails.first);
    await tester.tap(viewDetails.first.hitTestable());
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

    final textFields = find.byType(TextFormField);
    final count = textFields.evaluate().length;
    for (var index = 0; index < count; index++) {
      final finder = textFields.at(index);
      final widget = tester.widget<TextFormField>(finder);
      final label = widget.decoration?.labelText?.trim() ?? '';
      final current = widget.controller?.text.trim() ?? '';
      if (current.isNotEmpty) continue;

      final required =
          label == 'Full name' ||
          label == 'Phone or WhatsApp number' ||
          label == 'Email' ||
          label.endsWith('*');
      if (!required) continue;

      await tester.ensureVisible(finder);
      await tester.enterText(finder, _valueForTextField(widget, label, config));
      await tester.pump(const Duration(milliseconds: 100));
    }

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    final dropdownCount = dropdowns.evaluate().length;
    for (var index = 0; index < dropdownCount; index++) {
      final finder = dropdowns.at(index);
      final widget = tester.widget<DropdownButtonFormField<String>>(finder);
      final items = widget.items ?? const <DropdownMenuItem<String>>[];
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
        fail('Dropdown option "$firstValue" could not be selected in the real form.');
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

  String _valueForTextField(
    TextFormField widget,
    String label,
    E2eConfig config,
  ) {
    final normalized = label.toLowerCase();
    if (normalized.contains('email')) {
      return config.username.contains('@')
          ? config.username.trim()
          : 'omc-e2e@example.com';
    }
    if (normalized.contains('phone') || normalized.contains('whatsapp')) {
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

    await waits.waitFor(
      find.text('Required documents'),
      description: 'Submitted customer request detail',
      timeout: const Duration(seconds: 30),
    );
    await _allowExpectedSuccessSnackbarToClose();
    await waits.waitForNetworkIdle(
      description: 'Submitted customer request detail',
      timeout: const Duration(seconds: 20),
    );
    waits.assertHealthy('Submitted customer request detail');
  }

  Future<void> _uploadAllRequiredDocuments() async {
    for (var uploadIndex = 0; uploadIndex < 20; uploadIndex++) {
      final upload = find.text('Upload');
      if (upload.evaluate().isEmpty) break;

      await tester.ensureVisible(upload.first);
      await tester.tap(upload.first.hitTestable());
      await tester.pump();
      await waits.waitFor(
        find.textContaining('uploaded successfully.'),
        description: 'Required document upload ${uploadIndex + 1}',
        timeout: const Duration(seconds: 30),
      );
      await _allowExpectedSuccessSnackbarToClose();
      await waits.waitForNetworkIdle(
        description: 'Required document upload ${uploadIndex + 1}',
        timeout: const Duration(seconds: 20),
      );
    }

    if (find.text('Upload').evaluate().isNotEmpty) {
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

    await waits.waitFor(
      find.text('Payment actions'),
      description: 'Customer payment detail',
      timeout: const Duration(seconds: 20),
    );
    await waits.waitForNetworkIdle(description: 'Customer payment detail');
    waits.assertHealthy('Customer payment detail');

    final uploadProof = find.text('Upload payment proof');
    await waits.waitFor(uploadProof, description: 'Upload payment proof action');
    await tester.ensureVisible(uploadProof.first);
    await tester.tap(uploadProof.first.hitTestable());
    await tester.pump();

    await waits.waitFor(
      find.text('Receipt Submitted'),
      description: 'Receipt submitted payment status',
      timeout: const Duration(seconds: 30),
    );
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}

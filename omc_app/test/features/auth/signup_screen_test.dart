import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/auth/presentation/signup_screen.dart';

void main() {
  testWidgets('final step submits exactly once with canonical payload', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    final response = Completer<Map<String, dynamic>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signupSubmitProvider.overrideWithValue((data) {
            calls.add(Map<String, dynamic>.from(data));
            return response.future;
          }),
        ],
        child: const MaterialApp(home: SignupScreen()),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Ayesha Khan',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ayesha@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile number'),
      '3063191907',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp number'),
      '3063191908',
    );

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'CNIC'),
      '42101-1234567-8',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      'Karachi, Pakistan',
    );

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'StrongPass123!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'StrongPass123!',
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final createAccount = find.text('Create account');
    await tester.ensureVisible(createAccount);
    await tester.tap(createAccount);
    await tester.pump();
    await tester.tap(createAccount);
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single, containsPair('full_name', 'Ayesha Khan'));
    expect(calls.single, containsPair('first_name', 'Ayesha'));
    expect(calls.single, containsPair('last_name', 'Khan'));
    expect(calls.single, containsPair('email', 'ayesha@example.com'));
    expect(calls.single, containsPair('phone', '+923063191907'));
    expect(calls.single, containsPair('mobile', '+923063191907'));
    expect(calls.single, containsPair('whatsapp_no', '+923063191908'));
    expect(calls.single, containsPair('cnic', '4210112345678'));
    expect(calls.single, containsPair('customer_type', 'Customer'));
    expect(calls.single, containsPair('register_as', 'Customer'));
    expect(calls.single, containsPair('address', 'Karachi, Pakistan'));
    expect(calls.single, containsPair('password', 'StrongPass123!'));
    expect(calls.single, containsPair('confirm_password', 'StrongPass123!'));

    response.complete(<String, dynamic>{'message': 'Signup completed.'});
    await tester.pumpAndSettle();
    expect(find.text('We received your details.'), findsOneWidget);
  });
}

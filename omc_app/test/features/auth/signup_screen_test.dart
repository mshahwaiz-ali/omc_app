import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/auth/presentation/signup_screen.dart';

void main() {
  testWidgets('public signup exposes customer accounts only', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SignupScreen(),
        ),
      ),
    );

    expect(find.text('Customer'), findsWidgets);
    expect(find.text('Consultant'), findsNothing);
    expect(find.text('Business Partner'), findsNothing);
    expect(find.text('Tax Associate'), findsNothing);
    expect(find.textContaining('Staff options'), findsNothing);
    expect(
      find.textContaining('Create a customer account'),
      findsOneWidget,
    );
  });

  testWidgets('final step submits canonical verification payload', (
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
          signupUsernameAvailabilityProvider.overrideWithValue(
            (username) async => <String, dynamic>{
              'message': <String, dynamic>{
                'available': true,
                'username': username,
              },
            },
          ),
        ],
        child: const MaterialApp(home: SignupScreen()),
      ),
    );

    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Ayesha Khan',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ayesha@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'ayesha.khan',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile number'),
      '3063191907',
    );

    final whatsappToggle = find.widgetWithText(
      CheckboxListTile,
      'Use this number for WhatsApp',
    );
    await tester.ensureVisible(whatsappToggle);
    await tester.pumpAndSettle();
    await tester.tap(whatsappToggle);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'WhatsApp number'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp number'),
      '3063191908',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CNIC'),
      '42101-1234567-8',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      'Karachi, Pakistan',
    );

    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final acquisitionSource = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(acquisitionSource);
    await tester.tap(acquisitionSource);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Website').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'Confirm password'),
      findsNothing,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final sendVerificationEmail = find.text('Send verification email');
    await tester.ensureVisible(sendVerificationEmail);
    await tester.tap(sendVerificationEmail);
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single, containsPair('full_name', 'Ayesha Khan'));
    expect(calls.single, containsPair('first_name', 'Ayesha'));
    expect(calls.single, containsPair('last_name', 'Khan'));
    expect(calls.single, containsPair('email', 'ayesha@example.com'));
    expect(calls.single, containsPair('username', 'ayesha.khan'));
    expect(calls.single, containsPair('phone', '+923063191907'));
    expect(calls.single, containsPair('mobile', '+923063191907'));
    expect(calls.single, containsPair('whatsapp_no', '+923063191908'));
    expect(calls.single, containsPair('cnic', '4210112345678'));
    expect(calls.single, containsPair('customer_type', 'Customer'));
    expect(calls.single, containsPair('register_as', 'Customer'));
    expect(calls.single, containsPair('onboarding_mode', 'New Customer'));
    expect(calls.single, containsPair('address', 'Karachi, Pakistan'));
    expect(calls.single, containsPair('acquisition_source', 'Website'));
    expect(calls.single, containsPair('acquisition_source_detail', ''));
    expect(calls.single.containsKey('referral_code'), isFalse);
    expect(calls.single.containsKey('referral_assistance_consent'), isFalse);
    expect(calls.single.containsKey('password'), isFalse);
    expect(calls.single.containsKey('confirm_password'), isFalse);

    response.complete(<String, dynamic>{'message': 'Signup completed.'});
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(
      find.textContaining(
        'Open the verification link sent to ayesha@example.com.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('existing OMC customer submits claim onboarding mode', (
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
          signupUsernameAvailabilityProvider.overrideWithValue(
            (username) async => <String, dynamic>{
              'message': <String, dynamic>{
                'available': true,
                'username': username,
              },
            },
          ),
        ],
        child: const MaterialApp(home: SignupScreen()),
      ),
    );

    expect(find.text('Are you already an OMC customer?'), findsOneWidget);
    expect(find.text('New to OMC'), findsOneWidget);
    expect(find.text('Already an OMC customer'), findsOneWidget);

    await tester.ensureVisible(find.text('Already an OMC customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already an OMC customer'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Existing Customer',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'existing@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'existing.customer',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile number'),
      '3001234567',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CNIC'),
      '42101-7654321-0',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      'Karachi, Pakistan',
    );

    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final acquisitionSource = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(acquisitionSource);
    await tester.tap(acquisitionSource);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing Customer').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final sendVerificationEmail = find.text('Send verification email');
    await tester.ensureVisible(sendVerificationEmail);
    await tester.tap(sendVerificationEmail);
    await tester.pump();

    expect(calls, hasLength(1));
    expect(
      calls.single,
      containsPair('onboarding_mode', 'Existing Customer Claim'),
    );

    // Public Flutter must never submit the migration-only mode.
    expect(calls.single['onboarding_mode'], isNot('Imported Existing'));

    response.complete(<String, dynamic>{'message': 'Signup completed.'});
    await tester.pumpAndSettle();
  });
}

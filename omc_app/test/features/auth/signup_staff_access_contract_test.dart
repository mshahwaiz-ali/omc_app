import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/auth/presentation/signup_steps.dart';

void main() {
  testWidgets('staff role cards describe an access application', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignupRoleCard(
            role: 'Consultant',
            selected: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Consultant'), findsOneWidget);
    expect(find.text('Apply for consultant staff access.'), findsOneWidget);
  });

  testWidgets('staff verification does not promise automatic access', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SignupSecurityStep(
              formKey: GlobalKey<FormState>(),
              isCustomer: false,
              acceptedTerms: false,
              onTermsChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Verify and submit your application'), findsOneWidget);
    expect(
      find.textContaining('does not grant staff permissions'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'protected staff permissions are never enabled automatically',
      ),
      findsOneWidget,
    );
  });
}

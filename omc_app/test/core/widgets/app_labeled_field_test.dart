import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/widgets/app_labeled_field.dart';

void main() {
  testWidgets('renders a persistent required label above its control', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLabeledField(
            label: 'Finance review note',
            isRequired: true,
            child: TextField(),
          ),
        ),
      ),
    );

    final label = find.text('Finance review note *');
    final field = find.byType(TextField);
    expect(label, findsOneWidget);
    expect(field, findsOneWidget);
    expect(tester.getTopLeft(label).dy, lessThan(tester.getTopLeft(field).dy));
  });
}

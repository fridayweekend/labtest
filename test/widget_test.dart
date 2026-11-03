import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labtest/main.dart';

void main() {
  testWidgets('Blank input shows inline errors before Firebase is accessed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Inventory(setupError: 'Offline test')),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Item'));
    await tester.pump();
    expect(find.text('Choose a category.'), findsOneWidget);
    expect(
      find.text('Enter a whole number of zero or more.'),
      findsNWidgets(2),
    );
    expect(find.text('Use STK- followed by three digits.'), findsOneWidget);
  });
}

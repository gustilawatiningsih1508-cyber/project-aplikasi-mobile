// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bengkalis_marketplace/widgets/category_chip.dart';

void main() {
  testWidgets('CategoryChip renders correctly and handles taps', (WidgetTester tester) async {
    bool tapped = false;

    // Build the CategoryChip widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryChip(
            label: 'Elektronik',
            isSelected: false,
            onTap: () {
              tapped = true;
            },
            icon: Icons.phone_android,
          ),
        ),
      ),
    );

    // Verify label is shown
    expect(find.text('Elektronik'), findsOneWidget);

    // Tap the chip and verify the callback is executed
    await tester.tap(find.byType(CategoryChip));
    await tester.pump();

    expect(tapped, isTrue);
  });
}

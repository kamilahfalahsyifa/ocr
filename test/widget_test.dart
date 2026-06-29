import 'package:flutter_test/flutter_test.dart';

import 'package:snap_expense/main.dart';

void main() {
  testWidgets('Home screen renders SnapExpense branding and CTA',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SnapExpenseApp());
    // Pump a frame so the platform splash and first layout settle.
    await tester.pump();

    // App title appears in the AppBar.
    expect(find.text('SnapExpense'), findsWidgets);
    // Subtitle.
    expect(find.text('Scan. Extract. Review.'), findsOneWidget);
    // Description blurb.
    expect(
      find.textContaining('Take a picture of a receipt'),
      findsOneWidget,
    );
    // Primary CTA.
    expect(find.text('Scan Receipt'), findsOneWidget);
  });
}
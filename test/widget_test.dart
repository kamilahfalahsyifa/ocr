import 'package:flutter_test/flutter_test.dart';

import 'package:snap_expense/main.dart';
import 'package:snap_expense/services/receipt_storage_service.dart';

void main() {
  testWidgets('Home screen renders SnapExpense branding and CTAs',
      (WidgetTester tester) async {
    await tester.pumpWidget(SnapExpenseApp(storage: ReceiptStorageService()));
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
    // Secondary CTA for the History feature.
    expect(find.text('Saved Receipts'), findsOneWidget);
  });
}
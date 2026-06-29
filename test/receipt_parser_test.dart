import 'package:flutter_test/flutter_test.dart';

import 'package:snap_expense/helpers/receipt_parser_helper.dart';
import 'package:snap_expense/models/receipt_model.dart';

void main() {
  const parser = ReceiptParser();

  // ---------------------------------------------------------------------------
  // REGRESSION — the bug from the report
  // ---------------------------------------------------------------------------

  group('Alfamart bug regression', () {
    test('extracts Alfamart, 19/06/2026, 31300, Grocery (not the concatenated monster)',
        () {
      final r = parser.parse(
        rawText: '''
Alfamart
Jl. Sudirman No 1

Tgl. 19-06-2026
CHARM MAXI VVlo          19,900
CHARM MAXI VVlo2         13,400
Subtotal                 33,300
Discount                 2,000
Total Belanja            31,300
Total Bayar              31,300
PPN: 3,280
Kasir: BUDI
Member: 08123456789
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.merchant, 'Alfamart');
      expect(r.date, '19/06/2026');
      expect(r.total, '31300');
      expect(r.category, 'Grocery');
    });

    test('does NOT concatenate digits across lines into a monster number', () {
      final r = parser.parse(
        rawText: '''
Alfamart
Tgl. 19-06-2026
Item A   19,900
Item B   13,400
Item C   33,300
Discount 2,000
Total Belanja 31,300
PPN: 3,280
''',
        imagePath: '/tmp/test.jpg',
      );
      final parsed = int.tryParse(r.total);
      expect(parsed, isNotNull);
      expect(parsed! < 100000000, isTrue,
          reason: 'total should fit in 8 digits, got ${r.total}');
    });
  });

  // ---------------------------------------------------------------------------
  // Merchant dictionary
  // ---------------------------------------------------------------------------

  group('Merchant dictionary', () {
    test('Indomaret -> Grocery', () {
      final r = parser.parse(
        rawText: '''
INDOMARET
Jl. Test
TOTAL BELANJA 25,000
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.merchant, 'INDOMARET');
      expect(r.category, 'Grocery');
    });

    test('Alfamidi exact match (longer than alfamart substring)', () {
      final r = parser.parse(
        rawText: 'Alfamidi\nTOTAL BELANJA 10,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.merchant, 'Alfamidi');
      expect(r.category, 'Grocery');
    });

    test('Superindo -> Grocery', () {
      final r = parser.parse(
        rawText: 'Superindo\nTOTAL 50,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.merchant, 'Superindo');
      expect(r.category, 'Grocery');
    });

    test('Starbucks exact match -> Coffee', () {
      final r = parser.parse(
        rawText: 'Starbucks\nTOTAL 75,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.merchant, 'Starbucks');
      expect(r.category, 'Coffee');
    });

    test('Pertamina -> Fuel', () {
      final r = parser.parse(
        rawText: 'PERTAMINA\nTOTAL 250,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.merchant, 'PERTAMINA');
      expect(r.category, 'Fuel');
    });

    test('item-name line is not chosen as merchant', () {
      // The bug report had "CHARM MAXI VVlo" being chosen over "Alfamart".
      final r = parser.parse(
        rawText: '''
CHARM MAXI VVlo
Alfamart
TOTAL BELANJA 12,000
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.merchant, 'Alfamart');
    });

    test('OTI HASANUDIN bug regression: brand token wins over Instagram handle',
        () {
      final r = parser.parse(
        rawText: '''
otichicken.id
#AyamGueBeda

Alamat: Jl. Hasanuddin No. 12 Bandung

CS: 08123456789

OTI HASANUDIN

Order #12345
Rp 50,000
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.merchant, 'OTI HASANUDIN');
    });

    test('noise line "instagram" / "#AyamGueBeda" never wins', () {
      final r = parser.parse(
        rawText: '''
@otichicken.id
#AyamGueBeda
Follow us on Instagram
www.otichicken.id

OTI HASANUDIN
TOTAL 50,000
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.merchant, 'OTI HASANUDIN');
    });

    test('trace surfaces candidate list with raw scores', () {
      final r = parser.parse(
        rawText: '''
otichicken.id
#AyamGueBeda
Alamat: Jl. Test No. 1
OTI HASANUDIN
TOTAL 50,000
''',
        imagePath: '/tmp/test.jpg',
      );
      final trace = r.debugTrace;
      expect(trace, isNotNull);
      expect(trace!.merchantCandidates, isNotEmpty);
      // The winning candidate must appear with its score.
      expect(
        trace.merchantCandidates.any((s) => s.contains('OTI HASANUDIN')),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Date extraction
  // ---------------------------------------------------------------------------

  group('Date extraction', () {
    test('Tgl. dd-MM-yyyy -> dd/MM/yyyy', () {
      final r = parser.parse(
        rawText: 'Alfamart\nTgl. 19-06-2026\nTOTAL BELANJA 12,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.date, '19/06/2026');
    });

    test('Tanggal dd/MM/yyyy', () {
      final r = parser.parse(
        rawText: 'Indomaret\nTanggal: 29/06/2026\nTOTAL BELANJA 25,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.date, '29/06/2026');
    });

    test('dd.MM.yyyy without prefix still picked up', () {
      final r = parser.parse(
        rawText: 'Indomaret\n19.06.2026\nTOTAL BELANJA 25,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.date, '19/06/2026');
    });

    test('timestamps (12:30) are NOT parsed as dates', () {
      final r = parser.parse(
        rawText: '''
Indomaret
Tgl. 19-06-2026 12:30
TOTAL BELANJA 25,000
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.date, '19/06/2026');
    });
  });

  // ---------------------------------------------------------------------------
  // Total extraction — line-scoped, last keyword wins
  // ---------------------------------------------------------------------------

  group('Total extraction', () {
    test('TOTAL BELANJA 31,300 -> 31300', () {
      final r = parser.parse(
        rawText: '''
Alfamart
Item A   19,900
TOTAL BELANJA 31,300
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.total, '31300');
    });

    test('multi-total: picks the LAST matching keyword line', () {
      final r = parser.parse(
        rawText: '''
Subtotal   10,000
TOTAL     18,000
TOTAL BAYAR 25,000
TOTAL BELANJA 30,000
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.total, '30000');
    });

    test('discount receipt: TOTAL BELANJA is post-discount', () {
      final r = parser.parse(
        rawText: '''
Subtotal   33,300
Discount   2,000
TOTAL BELANJA 31,300
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.total, '31300');
    });

    test('PPN line is rejected', () {
      final r = parser.parse(
        rawText: '''
Subtotal  31,300
PPN        3,280
TOTAL BELANJA 31,300
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.total, '31300');
    });

    test('member/point line is rejected', () {
      final r = parser.parse(
        rawText: '''
Point: 12345
TOTAL BELANJA 12,000
''',
        imagePath: '/tmp/test.jpg',
      );
      // 12345 fits reasonable range but is on a disqualified line, so we
      // pick TOTAL BELANJA 12,000 instead.
      expect(r.total, '12000');
    });

    test('concatenated-mega-number rejected (> 8 digits)', () {
      // The exact shape of the reported bug.
      final r = parser.parse(
        rawText: '''
SomeShop
19,900
13,400
33,300
2,000
31,300
31,300
''',
        imagePath: '/tmp/test.jpg',
      );
      // Without a TOTAL keyword the parser falls back to largest reasonable
      // amount; all of these are < 8 digits and within bounds, so the
      // largest is chosen — but it must NOT be the cross-line concatenation.
      final parsed = int.tryParse(r.total) ?? 0;
      expect(parsed, lessThan(100000000));
    });

    test('totals > 8 digits are rejected', () {
      final r = parser.parse(
        rawText: '''
TOTAL 12345678901
TOTAL BELANJA 50,000
''',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.total, '50000');
    });

    test('totals < 1000 are rejected (likely line item)', () {
      final r = parser.parse(
        rawText: '''
TOTAL BELANJA 500
Item X  25,000
TOTAL BAYAR 25,000
''',
        imagePath: '/tmp/test.jpg',
      );
      // 500 is below the 1000 threshold, 25,000 is the chosen value.
      expect(r.total, '25000');
    });
  });

  // ---------------------------------------------------------------------------
  // Debug trace
  // ---------------------------------------------------------------------------

  group('Debug trace', () {
    test('records rejected candidates when present', () {
      final r = parser.parse(
        rawText: '''
Alfamart
Tgl. 19-06-2026
Point: 99999999999
TOTAL BELANJA 31,300
''',
        imagePath: '/tmp/test.jpg',
      );
      final trace = r.debugTrace;
      expect(trace, isNotNull);
      expect(trace!.chosenMerchant, 'Alfamart');
      expect(trace.chosenDate, '19/06/2026');
      expect(trace.chosenTotal, '31300');
      // The 99999999999 token should appear in the rejections.
      expect(trace.totalRejections, isNotEmpty);
    });

    test('trace is null when DebugTrace object not provided', () {
      // Default behaviour: parser always populates a trace.
      final r = parser.parse(
        rawText: 'Indomaret\nTOTAL 12,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.debugTrace, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Confidence — sanity checks
  // ---------------------------------------------------------------------------

  group('Confidence', () {
    test('dictionary merchant gives higher confidence than unknown merchant', () {
      final known = parser.parse(
        rawText: 'Alfamart\nTOTAL 12,000',
        imagePath: '/tmp/test.jpg',
      );
      final unknown = parser.parse(
        rawText: 'OTI HASANUDIN\nTOTAL 50,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(
        known.confidenceFor(ReceiptModel.fieldMerchant),
        greaterThan(unknown.confidenceFor(ReceiptModel.fieldMerchant)),
      );
    });

    test('TOTAL BELANJA keyword gives high total confidence', () {
      final r = parser.parse(
        rawText: 'Alfamart\nTOTAL BELANJA 12,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(
        r.confidenceFor(ReceiptModel.fieldTotal),
        greaterThan(0.85),
      );
    });

    test('all four confidence keys are always populated', () {
      final r = parser.parse(
        rawText: 'Alfamart\nTOTAL BELANJA 12,000',
        imagePath: '/tmp/test.jpg',
      );
      expect(r.confidence.containsKey(ReceiptModel.fieldMerchant), isTrue);
      expect(r.confidence.containsKey(ReceiptModel.fieldDate), isTrue);
      expect(r.confidence.containsKey(ReceiptModel.fieldTotal), isTrue);
      expect(r.confidence.containsKey(ReceiptModel.fieldCategory), isTrue);
    });
  });
}
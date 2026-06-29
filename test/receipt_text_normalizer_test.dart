import 'package:flutter_test/flutter_test.dart';

import 'package:snap_expense/helpers/receipt_text_normalizer.dart';

void main() {
  const normalizer = ReceiptTextNormalizer();

  group('ReceiptTextNormalizer', () {
    test('fixes OCR O -> 0 in numeric tokens', () {
      expect(
        normalizer.normalize('T0TAL Rp.44.OOO'),
        contains('TOTAL'),
      );
      expect(
        normalizer.normalize('T0TAL Rp.44.OOO'),
        contains('44.000'),
      );
    });

    test('fixes l -> 1 inside numeric tokens', () {
      expect(
        normalizer.normalize('TOTAL Rpl2.500'),
        contains('12.500'),
      );
    });

    test('strips Rp. punctuation and duplicates spaces', () {
      expect(
        normalizer.normalize('TOTAL   Rp.   44.000'),
        contains('Rp 44.000'),
      );
    });

    test('leaves alphabetic words alone (no digit context)', () {
      expect(
        normalizer.normalize('Kopi Kenangan'),
        equals('Kopi Kenangan'),
      );
    });

    test('normalizes Indonesian dashes and curly quotes', () {
      expect(
        normalizer.normalize('29–Juni–2026'),
        contains('29-Juni-2026'),
      );
    });
  });
}
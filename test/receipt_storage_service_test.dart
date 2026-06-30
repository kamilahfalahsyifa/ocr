import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:snap_expense/models/receipt_model.dart';
import 'package:snap_expense/services/receipt_storage_service.dart';

ReceiptModel _fixture(String merchant, {DateTime? at}) => ReceiptModel(
      merchant: merchant,
      date: '29/06/2026',
      total: '50000',
      category: 'Grocery',
      rawText: 'OCR text for $merchant',
      imagePath: '/tmp/$merchant.jpg',
      createdAt: at ?? DateTime.now(),
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('snap_expense_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('ReceiptStorageService', () {
    test('initialize + saveReceipt + getReceipts round-trip', () async {
      final storage = ReceiptStorageService();
      await storage.initialize();

      final r1 = _fixture('Indomaret');
      final r2 = _fixture('Alfamart');
      await storage.saveReceipt(r1);
      await storage.saveReceipt(r2);

      expect(storage.count(), 2);
      final all = await storage.getReceipts();
      expect(all.length, 2);
      expect(all.map((r) => r.merchant).toSet(), {'Indomaret', 'Alfamart'});
    });

    test('deleteReceipt removes a single receipt', () async {
      final storage = ReceiptStorageService();
      await storage.initialize();

      final r = _fixture('Kopi Kenangan',
          at: DateTime(2026, 6, 29, 12, 0, 0));
      await storage.saveReceipt(r);

      expect(storage.count(), 1);
      await storage.deleteReceipt(r.createdAt.toIso8601String());
      expect(storage.count(), 0);
    });

    test('clearReceipts wipes the box', () async {
      final storage = ReceiptStorageService();
      await storage.initialize();

      await storage.saveReceipt(_fixture('A'));
      await storage.saveReceipt(_fixture('B'));
      expect(storage.count(), 2);

      await storage.clearReceipts();
      expect(storage.count(), 0);
    });

    test('JSON round-trip preserves all persistable fields', () {
      final r = ReceiptModel(
        merchant: 'Starbucks',
        date: '29/06/2026',
        total: '75000',
        category: 'Coffee',
        rawText: 'raw ocr text',
        imagePath: '/tmp/x.jpg',
        createdAt: DateTime(2026, 6, 29, 10, 30),
      );
      final restored = ReceiptModel.fromJson(r.toJson());
      expect(restored.merchant, r.merchant);
      expect(restored.date, r.date);
      expect(restored.total, r.total);
      expect(restored.category, r.category);
      expect(restored.rawText, r.rawText);
      expect(restored.imagePath, r.imagePath);
      expect(restored.createdAt, r.createdAt);
    });

    test('changes stream fires on save + delete', () async {
      final storage = ReceiptStorageService();
      await storage.initialize();

      final events = <void>[];
      final sub = storage.changes.listen(events.add);

      final r = _fixture('A');
      await storage.saveReceipt(r);
      await storage.deleteReceipt(r.createdAt.toIso8601String());

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events.length, greaterThanOrEqualTo(2));
    });
  });
}
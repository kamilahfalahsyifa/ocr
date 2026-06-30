import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/receipt_model.dart';

/// Local persistence for saved receipts, backed by a Hive box.
///
/// Each entry is stored as a plain `Map<String, dynamic>` so we don't need
/// to run codegen (`hive_generator` / `build_runner`) — the box is opened
/// with the default `Map` adapter that ships with Hive.
///
/// Box layout:
///   * **Box name:** `saved_receipts`
///   * **Key:**       ISO-8601 timestamp string (also used for ordering)
///   * **Value:**     `Map<String, dynamic>` produced by [ReceiptModel.toJson]
class ReceiptStorageService {
  ReceiptStorageService();

  /// Name of the Hive box used by this service.
  static const String boxName = 'saved_receipts';

  Box<Map>? _box;
  final StreamController<void> _changes =
      StreamController<void>.broadcast();

  /// Stream that fires whenever the box is mutated. The History page listens
  /// to this so it can rebuild without a manual refresh.
  Stream<void> get changes => _changes.stream;

  /// Opens the underlying Hive box. Call once during app startup
  /// (`main.dart`), before the UI is rendered.
  Future<void> initialize() async {
    _box ??= await Hive.openBox<Map>(boxName);
  }

  /// Returns `true` if the box has been opened.
  bool get isReady => _box != null;

  /// Persists [receipt] under its `createdAt` ISO string as the key.
  /// Returns the same key so callers can correlate the write.
  Future<String> saveReceipt(ReceiptModel receipt) async {
    final box = _requireBox();
    final baseKey = receipt.createdAt.toIso8601String();
    var key = baseKey;
    // Guarantee uniqueness for back-to-back saves that share the same
    // millisecond timestamp — otherwise Hive would silently overwrite.
    var suffix = 1;
    while (box.containsKey(key)) {
      key = '$baseKey-$suffix';
      suffix += 1;
    }
    await box.put(key, receipt.toJson());
    _changes.add(null);
    return key;
  }

  /// Returns every saved receipt, newest first.
  Future<List<ReceiptModel>> getReceipts() async {
    final box = _requireBox();
    final entries = box.values.map(ReceiptModel.fromJson).toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// Synchronous variant used by the History page after the box is open.
  List<ReceiptModel> getReceiptsSync() {
    final box = _requireBox();
    final entries = box.values.map(ReceiptModel.fromJson).toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// Removes a single receipt by its [id] (the `createdAt` ISO string).
  Future<void> deleteReceipt(String id) async {
    final box = _requireBox();
    await box.delete(id);
    _changes.add(null);
  }

  /// Wipes every saved receipt. Used by the future "Export JSON" / "Export
  /// CSV" flow plus the developer-mode reset.
  Future<void> clearReceipts() async {
    final box = _requireBox();
    await box.clear();
    _changes.add(null);
  }

  /// Number of saved receipts.
  int count() => _box?.length ?? 0;

  /// Closes the box and the broadcast stream. Call from app shutdown.
  Future<void> dispose() async {
    await _box?.close();
    await _changes.close();
  }

  Box<Map> _requireBox() {
    final box = _box;
    if (box == null) {
      throw StateError(
        'ReceiptStorageService.initialize() must be awaited before use.',
      );
    }
    return box;
  }
}
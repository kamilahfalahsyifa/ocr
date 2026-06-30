import '../helpers/receipt_parser_helper.dart';

/// Immutable structured representation of a receipt.
///
/// Built by [ReceiptParser] from raw OCR text and editable on the Review
/// screen before being saved. The optional [createdAt] timestamp is set
/// when the user saves the receipt and is used by the History page to sort
/// newest-first.
class ReceiptModel {
  /// The merchant or store name printed on the receipt.
  final String merchant;

  /// Date printed on the receipt, formatted as `dd/MM/yyyy`.
  final String date;

  /// Total amount printed on the receipt, formatted as a numeric string
  /// (no currency symbol) so the UI can format it locale-aware with [intl].
  final String total;

  /// Auto-classified spending category, e.g. `Food`, `Grocery`, `Fuel`.
  final String category;

  /// The unmodified raw text returned by Google ML Kit — useful for the
  /// developer-mode pipeline visualization.
  final String rawText;

  /// Absolute path to the selected receipt image on the device filesystem.
  final String imagePath;

  /// When the user saved the receipt. Used by the History page to sort
  /// newest-first. Defaults to `DateTime.now()`.
  final DateTime createdAt;

  /// Per-field confidence scores in `[0.0, 1.0]`. Keyed by field name.
  final Map<String, double> confidence;

  /// Parser reasoning trace for Developer Mode. `null` when the parser is
  /// run in production / test mode and the trace is not needed.
  final DebugTrace? debugTrace;

  static const String fieldMerchant = 'merchant';
  static const String fieldDate = 'date';
  static const String fieldTotal = 'total';
  static const String fieldCategory = 'category';

  /// JSON keys used by [toJson] / [fromJson] — kept in one place so the
  /// serialization contract is obvious.
  static const String _kMerchant = 'merchant';
  static const String _kDate = 'date';
  static const String _kTotal = 'total';
  static const String _kCategory = 'category';
  static const String _kRawText = 'rawText';
  static const String _kImagePath = 'imagePath';
  static const String _kCreatedAt = 'createdAt';

  ReceiptModel({
    required this.merchant,
    required this.date,
    required this.total,
    required this.category,
    required this.rawText,
    required this.imagePath,
    DateTime? createdAt,
    this.confidence = const <String, double>{},
    this.debugTrace,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Returns a copy of this receipt with any subset of fields replaced.
  ReceiptModel copyWith({
    String? merchant,
    String? date,
    String? total,
    String? category,
    String? rawText,
    String? imagePath,
    DateTime? createdAt,
    Map<String, double>? confidence,
    DebugTrace? debugTrace,
  }) {
    return ReceiptModel(
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      total: total ?? this.total,
      category: category ?? this.category,
      rawText: rawText ?? this.rawText,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      confidence: confidence ?? this.confidence,
      debugTrace: debugTrace ?? this.debugTrace,
    );
  }

  /// Convenience getter — confidence for [fieldName] or `0.0` if unset.
  double confidenceFor(String fieldName) => confidence[fieldName] ?? 0.0;


  Map<String, dynamic> toJson() => <String, dynamic>{
    _kMerchant: merchant,
    _kDate: date,
    _kTotal: total,
    _kCategory: category,
    _kRawText: rawText,
    _kImagePath: imagePath,
    _kCreatedAt: createdAt.toIso8601String(),
  };


  factory ReceiptModel.fromJson(Map<dynamic, dynamic> json) {
    DateTime createdAt;
    final raw = json[_kCreatedAt];
    if (raw is String) {
      createdAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }
    return ReceiptModel(
      merchant: (json[_kMerchant] as String?) ?? '',
      date: (json[_kDate] as String?) ?? '',
      total: (json[_kTotal] as String?) ?? '',
      category: (json[_kCategory] as String?) ?? '',
      rawText: (json[_kRawText] as String?) ?? '',
      imagePath: (json[_kImagePath] as String?) ?? '',
      createdAt: createdAt,
    );
  }
}

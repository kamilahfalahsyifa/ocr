import '../helpers/receipt_parser_helper.dart';

/// Immutable structured representation of a receipt.
///
/// Built by [ReceiptParser] from raw OCR text and editable on the Review
/// screen before being saved.
///
/// All fields are exposed as named parameters so the model can be reconstructed
/// from any layer (OCR parser, user edits, or future persistence).
///
/// The optional [confidence] map carries per-field confidence scores from the
/// parser — keyed by field name (`merchant`, `date`, `total`, `category`).
/// Values are doubles in `[0.0, 1.0]`. The map is exposed primarily for the
/// Developer Mode visualization; production UIs can ignore it.
///
/// The optional [debugTrace] records the parser's reasoning (candidates,
/// rejections, chosen values) and is rendered in Developer Mode so the
/// audience can see exactly why each field was chosen.
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

  /// Per-field confidence scores in `[0.0, 1.0]`. Keyed by field name.
  final Map<String, double> confidence;

  /// Parser reasoning trace for Developer Mode. `null` when the parser is
  /// run in production / test mode and the trace is not needed.
  final DebugTrace? debugTrace;

  static const String fieldMerchant = 'merchant';
  static const String fieldDate = 'date';
  static const String fieldTotal = 'total';
  static const String fieldCategory = 'category';

  const ReceiptModel({
    required this.merchant,
    required this.date,
    required this.total,
    required this.category,
    required this.rawText,
    required this.imagePath,
    this.confidence = const <String, double>{},
    this.debugTrace,
  });

  /// Returns a copy of this receipt with any subset of fields replaced.
  ///
  /// Used by the Review screen when the user edits individual fields before
  /// saving.
  ReceiptModel copyWith({
    String? merchant,
    String? date,
    String? total,
    String? category,
    String? rawText,
    String? imagePath,
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
      confidence: confidence ?? this.confidence,
      debugTrace: debugTrace ?? this.debugTrace,
    );
  }

  /// Convenience getter — confidence for [fieldName] or `0.0` if unset.
  double confidenceFor(String fieldName) => confidence[fieldName] ?? 0.0;
}
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../helpers/receipt_parser_helper.dart';
import '../helpers/receipt_text_normalizer.dart';
import '../models/receipt_model.dart';
import '../services/ocr_service.dart';

/// Stage of the OCR pipeline that the UI can highlight in Developer Mode.
enum PipelineStage {
  imageSelected,
  ocrCompleted,
  parsingCompleted,
  reviewReady,
}

/// Single source of truth for the OCR demo.
///
/// Holds the selected image file, the raw text returned by Google ML Kit,
/// the normalized text, the structured [ReceiptModel] produced by
/// [ReceiptParser], loading flags, and a set of completed [PipelineStage]s
/// used by Developer Mode. All UI reads flow through this provider — there
/// is no other mutable application state.
class ReceiptProvider extends ChangeNotifier {
  ReceiptProvider({
    OCRService? ocrService,
    ReceiptParser? parser,
    ReceiptTextNormalizer? normalizer,
    ImagePicker? imagePicker,
  })  : _ocrService = ocrService ?? OCRService(),
        _parser = parser ?? ReceiptParser(normalizer: normalizer),
        _imagePicker = imagePicker ?? ImagePicker();

  final OCRService _ocrService;
  final ReceiptParser _parser;
  final ImagePicker _imagePicker;

  String? _selectedImagePath;
  String? get selectedImagePath => _selectedImagePath;

  /// Raw text returned by Google ML Kit. `null` until OCR completes.
  String? _rawText;
  String? get rawText => _rawText;

  /// Structured receipt produced by [ReceiptParser]. `null` until parsing
  /// completes.
  ReceiptModel? _receipt;
  ReceiptModel? get receipt => _receipt;

  /// OCR text after passing through the [ReceiptTextNormalizer]. Surfaced in
  /// Developer Mode so the audience can see how normalization fixes common
  /// OCR mistakes (e.g. `T0TAL` -> `TOTAL`). `null` until OCR completes.
  String? _normalizedText;
  String? get normalizedText => _normalizedText;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Whether Developer Mode is enabled in the AppBar.
  bool _developerMode = false;
  bool get developerMode => _developerMode;

  /// Stages that have completed in the current pipeline run.
  final Set<PipelineStage> _completedStages = <PipelineStage>{};
  Set<PipelineStage> get completedStages => Set.unmodifiable(_completedStages);

  /// Opens the platform's image picker for [source] (camera or gallery).
  /// Returns the path of the picked image, or `null` if the user cancelled.
  Future<String?> pickImageFromSource(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(source: source);
      if (picked == null) return null;
      _setSelectedImage(picked.path);
      return picked.path;
    } catch (e) {
      _errorMessage = 'Could not access the selected image. Please try again.';
      notifyListeners();
      return null;
    }
  }

  void _setSelectedImage(String path) {
    _resetPipeline();
    _selectedImagePath = path;
    _completedStages.add(PipelineStage.imageSelected);
    notifyListeners();
  }

  /// Runs the full pipeline against the currently-selected image:
  ///   1. OCR (Google ML Kit) -> raw text
  ///   2. Parsing              -> [ReceiptModel]
  ///
  /// Returns `true` on success, `false` if any stage failed. The caller
  /// should inspect [errorMessage] on failure.
  Future<bool> runPipeline() async {
    final path = _selectedImagePath;
    if (path == null) {
      _errorMessage = 'No image selected.';
      notifyListeners();
      return false;
    }

    _resetPipeline(keepImage: true);
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final file = File(path);

      // Files smaller than 4 KB are usually blurry / blank — ML Kit tends
      // to return empty text on those. A production app would analyse
      // image variance; this is a pragmatic shortcut for the demo.
      final tooBlurry = file.lengthSync() < 4 * 1024;

      final rawText = await _ocrService.recognizeText(file);

      if (rawText.trim().isEmpty) {
        _errorMessage = tooBlurry
            ? 'The image looks too blurry. Please try again with a sharper photo.'
            : 'No text detected. Try a clearer photo.';
        return false;
      }
      _rawText = rawText;
      _completedStages.add(PipelineStage.ocrCompleted);
      notifyListeners();

      // The parser runs the normalizer internally; we mirror it here so the
      // Developer Mode UI can show the NORMALIZED stage without forcing
      // the parser to expose a second return channel.
      final receipt = _parser.parse(rawText: rawText, imagePath: path);
      _normalizedText = const ReceiptTextNormalizer().normalize(rawText);
      _receipt = receipt;
      _completedStages.add(PipelineStage.parsingCompleted);
      _completedStages.add(PipelineStage.reviewReady);
      return true;
    } catch (e) {
      _errorMessage = 'OCR failed. Please try again.';
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Replaces one of the parsed fields after the user edits them on the
  /// Review screen. No-op if parsing has not completed yet.
  void updateReceipt({
    String? merchant,
    String? date,
    String? total,
    String? category,
  }) {
    final current = _receipt;
    if (current == null) return;
    _receipt = current.copyWith(
      merchant: merchant,
      date: date,
      total: total,
      category: category,
    );
    notifyListeners();
  }

  /// Simulates persisting the receipt. Per the project spec there is no
  /// database — this just flips a saving flag for the UI, with a brief
  /// delay so the user sees a loading state.
  Future<bool> saveReceipt() async {
    if (_receipt == null) return false;
    _isSaving = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _isSaving = false;
    notifyListeners();
    return true;
  }

  /// Clears any error set during the last pipeline run.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Toggles Developer Mode. When enabled, the Result screen renders an
  /// OCR-pipeline visualization with a green checkmark per completed stage.
  void toggleDeveloperMode() {
    _developerMode = !_developerMode;
    notifyListeners();
  }

  /// Resets the entire pipeline so the user can scan another receipt.
  void resetForNextScan() {
    _resetPipeline();
    notifyListeners();
  }

  /// Releases the underlying ML Kit recognizer. Call from the app root.
  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  void _resetPipeline({bool keepImage = false}) {
    _rawText = null;
    _normalizedText = null;
    _receipt = null;
    _errorMessage = null;
    _completedStages.clear();
    if (!keepImage) {
      _selectedImagePath = null;
    }
  }
}
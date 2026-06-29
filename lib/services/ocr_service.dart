import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Thin wrapper around Google ML Kit on-device text recognition.
///
/// Responsibilities:
///   * Accept an image file path.
///   * Run ML Kit's [TextRecognizer] over the image.
///   * Return the raw recognized text.
///
/// This class intentionally performs **no parsing**. Parsing lives in
/// [ReceiptParser] so that the OCR engine and the text-to-structured-data
/// logic can be explained (and tested) independently during the demo.
class OCRService {
  /// ML Kit recommends keeping one [TextRecognizer] alive for the session
  /// and closing it only on app shutdown.
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Runs OCR against [imageFile] and returns the raw recognized text.
  /// The caller is responsible for handling an empty result.
  ///
  /// Throws if the image cannot be read or ML Kit fails.
  Future<String> recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  /// Releases ML Kit native resources. Call on app shutdown.
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
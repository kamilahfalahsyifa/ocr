import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {

  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

 
  Future<String> recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
/// Application-wide string constants.
///
/// Centralizing the strings here keeps the UI widgets clean and makes the
/// presentation copy easy to update in a single place — useful for the demo.
class AppStrings {
  const AppStrings._();

  static const String appTitle = 'SnapExpense';
  static const String appSubtitle = 'Scan. Extract. Review.';
  static const String appDescription =
      'Take a picture of a receipt and let OCR extract important transaction information.';

  static const String scanReceipt = 'Scan Receipt';

  static const String readingReceipt = 'Reading receipt...';
  static const String recognizingText =
      'Recognizing text using Google ML Kit...';

  static const String ocrResultTitle = 'OCR Result';
  static const String rawOcrText = 'Raw OCR Text';
  static const String parsedResult = 'Parsed Result';
  static const String merchant = 'Merchant';
  static const String date = 'Date';
  static const String total = 'Total';
  static const String category = 'Category';
  static const String reviewResult = 'Review Result';

  static const String reviewTitle = 'Review Receipt';
  static const String saveReceipt = 'Save Receipt';
  static const String successDialogTitle = 'Receipt Successfully Processed';
  static const String done = 'Done';

  static const String developerMode = 'Developer Mode';
  static const String pipelineTitle = 'OCR Pipeline';
  static const String normalizedOcrText = 'Normalized OCR';
  static const String confidenceTitle = 'Confidence';
  static const String confidencePercentSuffix = '%';
  static const String debugTitle = 'Parser Debug';
  static const String debugDetectedMerchant = 'Detected Merchant';
  static const String debugTotalCandidates = 'Total Candidates';
  static const String debugRejectedCandidates = 'Rejected Candidates';
  static const String debugChosenCandidate = 'Chosen Candidate';
  static const String debugDateCandidates = 'Date Candidates';
  static const String chosenDateLabel = 'Chosen Date';

  static const String errorNoText = 'No text detected. Try a clearer photo.';
  static const String errorBlurry =
      'The image looks too blurry. Please try again with a sharper photo.';
  static const String errorOcrFailed = 'OCR failed. Please try again.';
  static const String errorParsingFailed =
      'Could not parse the receipt. Please review manually.';
}
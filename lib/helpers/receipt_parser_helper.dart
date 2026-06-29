import '../models/receipt_model.dart';
import 'receipt_text_normalizer.dart';

/// Pure-Dart parser that converts raw OCR text into a structured [ReceiptModel].
///
/// Pipeline: normalize OCR -> split into lines -> extract merchant / date /
/// total / category. Each step records its candidates + rejection reasons
/// into a [DebugTrace] attached to the result so the Developer Mode UI can
/// show the audience exactly why a field was chosen.
class ReceiptParser {
  /// Optional [normalizer] is accepted for backwards compatibility with
  /// existing callers (the provider passes one via
  /// `ReceiptParser(normalizer: ...)`); it is ignored — [normalize] is a
  /// static helper.
  const ReceiptParser({Object? normalizer});

  /// Cleans up OCR mistakes before line-by-line parsing runs.
  ///
  /// * `O` / `o` -> `0` **inside numeric tokens only** (never in merchant
  ///   names like `Kopi`).
  /// * Collapse duplicated whitespace, remove invisible characters,
  ///   normalize line endings.
  /// * Strip currency-symbol punctuation (`Rp.` -> `Rp`).
  /// * Trim every line.
  ///
  /// Runs **before** parsing so every regex downstream operates on a clean
  /// string. Returns the normalized text — same content but safer for the
  /// parser.
  static String normalize(String text) {
    return const ReceiptTextNormalizer().normalize(text);
  }

  /// Plausible lower/upper bounds for a real receipt total in IDR.
  static const double _totalMinReasonable = 1000;
  static const double _totalMaxReasonable = 10000000;

  /// Reject any candidate amount with more than this many digits. Capping at
  /// 8 keeps things sensible while still allowing up to Rp 99.999.999.
  static const int _maxAcceptableDigits = 8;

  /// Known merchants -> spending category. Lowercase keys; matched via
  /// case-insensitive [String.contains] across the full normalized text.
  /// Order matters — the first match wins.
  static const Map<String, String> _merchantCategoryMap = {
    'alfamart': 'Grocery',
    'indomaret': 'Grocery',
    'alfamidi': 'Grocery',
    'superindo': 'Grocery',
    'hypermart': 'Grocery',
    'lotte mart': 'Grocery',
    'starbucks': 'Coffee',
    'fore coffee': 'Coffee',
    'kopi kenangan': 'Coffee',
    'tim hortons': 'Coffee',
    "mcdonald's": 'Food',
    'mcdonalds': 'Food',
    'kfc': 'Food',
    'burger king': 'Food',
    'pizza hut': 'Food',
    'hokben': 'Food',
    'hoka-hoka bento': 'Food',
    'solaria': 'Food',
    'pertamina': 'Fuel',
    'shell': 'Fuel',
    'total energi': 'Fuel',
    'bp': 'Fuel',
    'vivo': 'Fuel',
  };

  /// Total keywords in priority order — most-specific first. The parser
  /// picks the **last** matching line in the receipt.
  static const List<String> _totalKeywords = [
    'TOTAL BELANJA',
    'GRAND TOTAL',
    'TOTAL BAYAR',
    'TOTAL',
    'JUMLAH',
    'TUNAI',
    'AMOUNT',
  ];

  /// Lines whose presence disqualifies them from contributing a total:
  /// they refer to related-but-different amounts (tax, point balances, item
  /// counts). Per spec: PPN, DPP, POINT, ITEM, MEMBER.
  static const Set<String> _totalRejectLineKeywords = {
    'PPN',
    'DPP',
    'POINT',
    'POIN',
    'MEMBER',
    'ITEM',
    'QTY',
    'DISCOUNT',
    'POTONGAN',
    'CHANGE',
    'KEMBALI',
  };

  /// Date-prefix keywords recognized in Indonesian/English receipts.
  static const List<String> _datePrefixKeywords = [
    'TGL',
    'TGL.',
    'TANGGAL',
    'DATE',
  ];

  /// Parses [rawText] (as returned by Google ML Kit) into a [ReceiptModel]
  /// tagged with [imagePath]. The model fields are filled with best-effort
  /// defaults; the user can refine them on the Review screen.
  ReceiptModel parse({
    required String rawText,
    required String imagePath,
  }) {
    final normalized = normalize(rawText);
    final lines = _splitLines(normalized);

    final trace = DebugTrace(rawLines: lines, normalizedText: normalized);

    final merchant = _extractMerchant(lines, trace);
    final date = _extractDate(lines, normalized, trace);
    final total = _extractTotal(lines, trace);
    final category = _extractCategory(merchant.value);

    trace.chosenMerchant = merchant.value;
    trace.chosenDate = date.value;
    trace.chosenTotal = total.value;
    trace.chosenCategory = category.value;

    return ReceiptModel(
      merchant: merchant.value,
      date: date.value,
      total: total.value,
      category: category.value,
      rawText: rawText,
      imagePath: imagePath,
      confidence: <String, double>{
        ReceiptModel.fieldMerchant: merchant.confidence,
        ReceiptModel.fieldDate: date.confidence,
        ReceiptModel.fieldTotal: total.confidence,
        ReceiptModel.fieldCategory: category.confidence,
      },
      debugTrace: trace,
    );
  }

  /// Splits the normalized text on `\n` and trims / drops empty lines.
  List<String> _splitLines(String normalized) {
    return normalized
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  /// Picks the best merchant line from [lines].
  ///
  /// Scoring:
  ///   * exact merchant match in dictionary (highest weight);
  ///   * +30 — line lives in the top section of the receipt;
  ///   * -50 — line is dominated by digits;
  ///   * -40 — line mentions cashier / member / etc. (blocklist).
  ///
  /// Returns the first dictionary hit immediately; falls back to the first
  /// non-blocklist uppercase line if no merchant is recognized.
  _Pick _extractMerchant(List<String> lines, DebugTrace trace) {
    trace.merchantCandidates = <String>[];

    if (lines.isEmpty) {
      trace.merchantRejectionReason = 'receipt is empty';
      return const _Pick(value: 'Unknown Merchant', confidence: 0.0);
    }

    // STEP 2 — drop noisy lines that can never be the merchant.
    final candidates = <_MerchantCandidate>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isMerchantNoisyLine(line)) continue;

      final score = _scoreMerchantCandidate(line, i, lines.length);
      candidates.add(_MerchantCandidate(line, score));
    }

    if (candidates.isEmpty) {
      trace.merchantRejectionReason =
          'every line was filtered out by the noise rules';
      return const _Pick(value: 'Unknown Merchant', confidence: 0.0);
    }

    // STEP 4 — pick the highest score.
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first;
    trace.merchantCandidates
      ..clear()
      ..addAll(candidates.map((c) => '${c.line} (${c.score})'));

    // Map the raw integer score onto a 0.0-1.0 confidence for the UI.
    final confidence = (best.score / 210.0).clamp(0.0, 0.99);
    return _Pick(
      value: best.line,
      confidence: confidence.toDouble(),
      sourceLine: lines.indexOf(best.line),
    );
  }

  /// Returns true if [line] looks like a social handle, address, label, or
  /// other content that can never be a merchant name.
  bool _isMerchantNoisyLine(String line) {
    final lower = line.toLowerCase();

    // Hard length / shape rules.
    if (line.length < 4) return true;
    if (RegExp(r'^[\d\s\W]+$').hasMatch(line)) return true;
    final digitCount = RegExp(r'\d').allMatches(line).length;
    if (digitCount > line.length / 2) return true;
    if (!RegExp(r'[A-Za-z]').hasMatch(line)) return true;
    if (RegExp(r'^[#@_\-=*~`]+$').hasMatch(line)) return true;

    // Keyword-based filters — these tokens almost never identify a store.
    const noiseTokens = <String>[
      'instagram',
      'tiktok',
      'facebook',
      'follow us',
      'alamat',
      'cs:',
      'member',
      'kasir',
      'order',
      'invoice',
      'powered by',
      'download',
      'share',
      'thank you',
      'terimakasih',
      'www',
      'http',
      '@',
      '#',
      'poin',
      'transfer',
      'customer copy',
      'tax invoice',
      'cashier',
      'subtotal',
      'discount',
      'ppn',
      'tanggal',
    ];
    for (final token in noiseTokens) {
      if (lower.contains(token)) return true;
    }
    return false;
  }

  /// Brand / category keywords worth a heavy scoring boost even when the
  /// exact merchant name isn't in our dictionary (e.g. `OTI HASANUDIN`).
  static const List<String> _brandTokens = [
    'OTI',
    'CHICKEN',
    'KFC',
    'MCD',
    'BURGER',
    'PIZZA',
    'COFFEE',
    'MART',
  ];

  /// Address-related tokens — strong negative signal (per spec).
  ///
  /// Each entry is matched as a whole word (delimited by whitespace or
  /// common punctuation) so short tokens like `RT` / `RW` / `KEL` don't
  /// spuriously match inside store names (e.g. `ALFAMART` ends in `RT`).
  static final List<RegExp> _addressTokenPatterns = [
    RegExp(r'\bJL\.?\b', caseSensitive: false),
    RegExp(r'\bJALAN\b', caseSensitive: false),
    RegExp(r'\bNO\.?\s*\d', caseSensitive: false),
    RegExp(r'\bRT\s*\d', caseSensitive: false),
    RegExp(r'\bRW\s*\d', caseSensitive: false),
    RegExp(r'\bKEL(?:URAHAN)?\.?\b', caseSensitive: false),
    RegExp(r'\bKEC(?:AMATAN)?\.?\b', caseSensitive: false),
    RegExp(r'\bKOTA\b', caseSensitive: false),
    RegExp(r'\bKABUPATEN\b', caseSensitive: false),
    RegExp(r'\bPROVINSI\b', caseSensitive: false),
    RegExp(r'\bINDONESIA\b', caseSensitive: false),
  ];

  /// Computes the raw merchant score for [line] at position [index] in a
  /// receipt of [totalLines]. Numbers match the spec verbatim.
  int _scoreMerchantCandidate(String line, int index, int totalLines) {
    var score = 0;
    final upper = line.toUpperCase();
    final lower = line.toLowerCase();

    // +40 ALL CAPS — ignore single-letter differences like punctuation.
    final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length >= 3 && letters == letters.toUpperCase()) {
      score += 40;
    }

    // +20 top 40% of the receipt.
    if (totalLines > 0 && index <= totalLines * 0.4) {
      score += 20;
    }

    // +100 known merchant (case-insensitive substring match).
    for (final entry in _merchantCategoryMap.entries) {
      if (lower.contains(entry.key)) {
        score += 100;
        break;
      }
    }

    // +50 brand-token bonus — covers merchants like `OTI HASANUDIN` whose
    // exact name isn't in the dictionary but whose brand token is.
    for (final token in _brandTokens) {
      if (upper.contains(token)) {
        score += 50;
        break;
      }
    }

    // -80 address keyword (per spec) — matched as a whole word so tokens
    // like `RT` / `RW` don't false-positive on store names.
    for (final pattern in _addressTokenPatterns) {
      if (pattern.hasMatch(line)) {
        score -= 80;
        break;
      }
    }

    // -50 contains numbers.
    if (RegExp(r'\d').hasMatch(line)) {
      score -= 50;
    }

    // -30 long line (> 45 chars) — usually an address or a long item name.
    if (line.length > 45) {
      score -= 30;
    }

    // -70 contains "Order".
    if (upper.contains('ORDER')) {
      score -= 70;
    }

    // -70 contains "Rp" (currency marker — receipt body, not header).
    if (line.contains('Rp')) {
      score -= 70;
    }

    return score;
  }

  /// Rejects timestamps like `12:30` so they are never mistaken for dates.
  static final RegExp _timestampPattern = RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$');

  static final List<RegExp> _datePatterns = [
    RegExp(r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b'),
    RegExp(r'\b(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})\b'),
  ];

  /// Picks the best date from [lines].
  ///
  /// Prefers dates that appear on a line containing one of the prefix
  /// keywords (`TGL`, `TANGGAL`, `DATE`). Timestamps are explicitly rejected.
  /// Returns `dd/MM/yyyy`.
  _Pick _extractDate(
    List<String> lines,
    String normalized,
    DebugTrace trace,
  ) {
    trace.dateCandidates = <String>[];

    final candidates = <_Candidate<String>>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final upper = line.toUpperCase();
      final hasDateKeyword =
          _datePrefixKeywords.any((kw) => upper.contains(kw));

      for (final pattern in _datePatterns) {
        for (final match in pattern.allMatches(line)) {
          final token = match.group(0)!;
          if (_timestampPattern.hasMatch(token)) continue;
          final formatted = _formatDateMatch(pattern, match);
          if (formatted == null) continue;

          var score = 0.65;
          if (hasDateKeyword) score += 0.25;
          if (i < lines.length / 4) score += 0.05;
          score = score.clamp(0.0, 1.0);
          candidates.add(_Candidate<String>(formatted, score));
          trace.dateCandidates.add(formatted);
        }
      }
    }

    if (candidates.isNotEmpty) {
      candidates.sort((a, b) => b.score.compareTo(a.score));
      return _Pick(
        value: candidates.first.value,
        confidence: candidates.first.score,
      );
    }

    for (final pattern in _datePatterns) {
      for (final match in pattern.allMatches(normalized)) {
        final formatted = _formatDateMatch(pattern, match);
        if (formatted == null) continue;
        trace.dateCandidates.add(formatted);
        return _Pick(value: formatted, confidence: 0.40);
      }
    }

    trace.dateRejectionReason = 'no plausible date found';
    final now = DateTime.now();
    final fallback = '${_two(now.day)}/${_two(now.month)}/${now.year}';
    return _Pick(value: fallback, confidence: 0.10);
  }

  String? _formatDateMatch(RegExp pattern, RegExpMatch match) {
    if (pattern == _datePatterns[1]) {
      final year = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final day = int.tryParse(match.group(3)!);
      if (!_isPlausibleDate(day, month, year)) return null;
      return _formatDate(day!, month!, year!);
    }
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (year != null && year < 100) year += 2000;
    if (!_isPlausibleDate(day, month, year)) return null;
    return _formatDate(day!, month!, year!);
  }

  bool _isPlausibleDate(int? day, int? month, int? year) {
    if (day == null || month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    if (year < 2000 || year > 2100) return false;
    return true;
  }

  String _formatDate(int day, int month, int year) =>
      '${_two(day)}/${_two(month)}/${year.toString().padLeft(4, '0')}';

  String _two(int n) => n.toString().padLeft(2, '0');

  /// Picks the best total from [lines].
  ///
  /// For every line that contains a TOTAL keyword, extracts ONLY the number
  /// on that same line and picks the **last** matching line in document
  /// order. Rejects:
  ///   * lines containing PPN / DPP / POINT / ITEM / MEMBER / DISCOUNT
  ///   * values < 1000 or > 10,000,000
  ///   * numbers with more than 8 digits
  _Pick _extractTotal(List<String> lines, DebugTrace trace) {
    trace.totalCandidates = <String>[];
    trace.totalRejections = <String>[];

    final keywordLines = <_KeywordHit>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final upper = line.toUpperCase();

      final paddedUpper = ' $upper ';
      if (_totalRejectLineKeywords.any(paddedUpper.contains)) {
        trace.totalRejections.add(
          'line $i "$line" — contains disqualifying keyword',
        );
        continue;
      }

      String? matchedKeyword;
      for (final kw in _totalKeywords) {
        if (upper.contains(kw)) {
          matchedKeyword = kw;
          break;
        }
      }
      if (matchedKeyword == null) continue;
      keywordLines.add(_KeywordHit(lineIndex: i, keyword: matchedKeyword));
    }

    _KeywordHit? chosenHit;
    _NumericCandidate? chosenAmount;
    for (final hit in keywordLines) {
      final line = lines[hit.lineIndex];
      final numbers = _extractAmountsOnLine(line);
      for (final n in numbers) {
        final value = _parseAmount(n.raw);
        if (value == null) continue;
        if (!_isReasonableAmount(n.raw, value)) {
          trace.totalRejections.add(
            'line ${hit.lineIndex} "$line" — '
            'token "${n.raw}" outside reasonable range or too long',
          );
          continue;
        }
        chosenHit = hit;
        chosenAmount = n;
        trace.totalCandidates.add(
          '${hit.keyword} → ${n.raw} (line ${hit.lineIndex})',
        );
        break;
      }
    }

    if (chosenHit != null && chosenAmount != null) {
      final formatted =
          _formatAmountForDisplay(_parseAmount(chosenAmount.raw)!);
      return _Pick(
        value: formatted,
        confidence: 0.92,
        sourceLine: chosenHit.lineIndex,
      );
    }

    // Per-line fallback so we never produce the concatenated monster
    // number that came from the original multi-line regex.
    _NumericCandidate? fallbackAmount;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final paddedUpper = ' ${line.toUpperCase()} ';
      if (_totalRejectLineKeywords.any(paddedUpper.contains)) continue;

      for (final n in _extractAmountsOnLine(line)) {
        final value = _parseAmount(n.raw);
        if (value == null) continue;
        if (!_isReasonableAmount(n.raw, value)) continue;
        if (fallbackAmount == null ||
            value > (_parseAmount(fallbackAmount.raw) ?? 0)) {
          fallbackAmount = n;
        }
      }
    }

    if (fallbackAmount != null) {
      trace.totalRejectionReason = 'no keyword match — used largest reasonable';
      trace.totalCandidates.add('largest-fallback → ${fallbackAmount.raw}');
      final formatted =
          _formatAmountForDisplay(_parseAmount(fallbackAmount.raw)!);
      return _Pick(value: formatted, confidence: 0.40, sourceLine: -1);
    }

    trace.totalRejectionReason = 'no acceptable amount found';
    return const _Pick(value: '0', confidence: 0.0);
  }

  /// Extracts candidate numeric tokens from a SINGLE line. We split on
  /// whitespace and consider every token that starts with a digit, so we
  /// can never accidentally match across line boundaries.
  List<_NumericCandidate> _extractAmountsOnLine(String line) {
    final out = <_NumericCandidate>[];
    final tokens = line.split(RegExp(r'\s+'));
    var offset = 0;
    for (final token in tokens) {
      if (token.isEmpty) continue;
      final start = line.indexOf(token, offset);
      offset = start + token.length;
      if (token.length > 12) continue;
      if (!RegExp(r'^\d[\d.,]*\d$|^\d$').hasMatch(token)) continue;
      out.add(_NumericCandidate(token, start));
    }
    return out;
  }

  bool _isReasonableAmount(String raw, double value) {
    if (value < _totalMinReasonable) return false;
    if (value > _totalMaxReasonable) return false;
    final digitsOnly = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > _maxAcceptableDigits) return false;
    return true;
  }

  String _formatAmountForDisplay(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// Parses a localized numeric string into a [double]. Returns `null` if
  /// the token cannot be interpreted.
  double? _parseAmount(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    final hasComma = s.contains(',');
    final hasDot = s.contains('.');

    double? value;
    if (hasComma && hasDot) {
      if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
      value = double.tryParse(s);
    } else if (hasComma) {
      final parts = s.split(',');
      if (parts.length == 2 && parts.last.length <= 2) {
        value = double.tryParse('${parts[0]}.${parts.last}');
      } else {
        value = double.tryParse(s.replaceAll(',', ''));
      }
    } else if (hasDot) {
      final parts = s.split('.');
      if (parts.length > 2) {
        value = double.tryParse(s.replaceAll('.', ''));
      } else if (parts.length == 2 && parts.last.length == 3) {
        value = double.tryParse(s.replaceAll('.', ''));
      } else {
        value = double.tryParse(s);
      }
    } else {
      value = double.tryParse(s);
    }
    return value;
  }

  /// Maps the chosen merchant to a spending category using the same
  /// dictionary used for merchant detection.
  _Pick _extractCategory(String merchant) {
    final lower = merchant.toLowerCase();
    for (final entry in _merchantCategoryMap.entries) {
      if (lower.contains(entry.key)) {
        return _Pick(value: entry.value, confidence: 0.95);
      }
    }
    return const _Pick(value: 'Others', confidence: 0.50);
  }
}

/// A single field pick — value + confidence in `[0.0, 1.0]`.
class _Pick {
  const _Pick({
    required this.value,
    required this.confidence,
    this.sourceLine = -1,
  });
  final String value;
  final double confidence;
  final int sourceLine;
}

/// A candidate produced by one of the field extractors.
class _Candidate<T> {
  const _Candidate(this.value, this.score);
  final T value;
  final double score;
}

/// A numeric token captured on a specific source line.
class _NumericCandidate {
  const _NumericCandidate(this.raw, this.start);
  final String raw;
  final int start;
}

/// One merchant candidate + its raw score, for sorting and trace output.
class _MerchantCandidate {
  const _MerchantCandidate(this.line, this.score);
  final String line;
  final int score;
}

/// A line that matched one of the TOTAL keywords.
class _KeywordHit {
  const _KeywordHit({required this.lineIndex, required this.keyword});
  final int lineIndex;
  final String keyword;
}

/// Trace of the parser's reasoning for a single receipt. Surfaces in the
/// Developer Mode UI via [ReceiptModel.debugTrace].
class DebugTrace {
  DebugTrace({
    required this.rawLines,
    required this.normalizedText,
  });

  final List<String> rawLines;
  final String normalizedText;

  List<String> merchantCandidates = <String>[];
  String? merchantRejectionReason;

  List<String> dateCandidates = <String>[];
  String? dateRejectionReason;

  List<String> totalCandidates = <String>[];
  List<String> totalRejections = <String>[];
  String? totalRejectionReason;

  String chosenMerchant = '';
  String chosenDate = '';
  String chosenTotal = '';
  String chosenCategory = '';
}
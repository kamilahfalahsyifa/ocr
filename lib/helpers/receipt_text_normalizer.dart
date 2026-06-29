/// Pure-Dart utility that cleans up raw OCR text before it reaches the parser.
///
/// Google ML Kit is usually accurate but it does produce noise — common
/// mistakes on thermal receipts include:
///   * `O` for `0`, `o` for `0`, `I`/`l` for `1`, `S` for `5`
///   * Punctuation inserted into numbers (`Rp.44.OOO`)
///   * Multiple consecutive spaces
///   * Curly / fancy quotes that confuse downstream regexes
///
/// Running the text through [ReceiptTextNormalizer.normalize] before parsing
/// dramatically improves the hit-rate of every regex that the parser uses.
class ReceiptTextNormalizer {
  const ReceiptTextNormalizer();

  /// Cleans up [raw] OCR text. The transformation is intentionally
  /// conservative — it never deletes alphanumeric characters, only swaps
  /// known-ambiguous glyphs and tidies spacing.
  String normalize(String raw) {
    if (raw.isEmpty) return raw;

    var s = raw;

    s = s.replaceAllMapped(
      RegExp(r'\bRp\.?\s*:?\s*', caseSensitive: false),
      (_) => 'Rp ',
    );

    s = _fixKeywordTokens(s);

    s = _fixNumericTokens(s);

    s = s.split('\n').map(_tidyLine).join('\n');

    s = s
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-');

    return s.trim();
  }

  String _tidyLine(String line) {
    return line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  /// Replaces ambiguous characters inside tokens that already contain digits.
  ///
  /// Outside such tokens we leave letters alone so we never corrupt merchant
  /// names like `McDonald's`.
  String _fixNumericTokens(String s) {
    return s.replaceAllMapped(
      RegExp(r'[A-Za-z0-9][A-Za-z0-9.,\-]*[A-Za-z0-9]|[A-Za-z0-9]'),
      (match) {
        final token = match.group(0)!;
        if (!_looksNumeric(token)) return token;
        return _swapAmbiguous(token);
      },
    );
  }

  /// Fixes *word-shape* OCR mistakes on common receipt keywords.
  ///
  /// `T0TAL`, `T0TAL BELANJA`, `TOTAl`, `TOTA1`, `JUMLAH` etc. are token
  /// shapes [_fixNumericTokens] would leave alone because the token contains
  /// no digits. We recognise the canonical keyword patterns (case-insensitive,
  /// digit-tolerant) and rewrite them to the canonical spelling so the
  /// parser's keyword search hits.
  String _fixKeywordTokens(String s) {
    var out = s;
    out = out.replaceAllMapped(
      RegExp(r'\bT[O0]T[A4][L1]\b', caseSensitive: false),
      (_) => 'TOTAL',
    );
    out = out.replaceAllMapped(
      RegExp(r'\bJU[MN]L[A4]H\b', caseSensitive: false),
      (_) => 'JUMLAH',
    );
    out = out.replaceAllMapped(
      RegExp(r'\bB[A4]Y[A4]R\b', caseSensitive: false),
      (_) => 'BAYAR',
    );
    return out;
  }

  /// Returns true if [token] contains at least one digit and is short enough
  /// to plausibly be a price / quantity.
  bool _looksNumeric(String token) {
    if (!RegExp(r'\d').hasMatch(token)) return false;
    if (token.length > 24) return false;
    final separators = token.codeUnits
        .where((c) => c == 0x2E || c == 0x2C)
        .length;
    return separators <= 2;
  }

  /// Performs the actual character swaps on a numeric-ish token.
  ///
  /// Substitutions:
  ///   * `O` / `o` -> `0`
  ///   * `I` / `l` / `|` -> `1`
  ///   * `S` / `s` (only when surrounded by digits) -> `5`
  ///   * stray `;` / `_` inside the token are dropped
  String _swapAmbiguous(String token) {
    final buf = StringBuffer();
    for (var i = 0; i < token.length; i++) {
      final c = token[i];
      final next = i + 1 < token.length ? token[i + 1] : '';
      final prev = i > 0 ? token[i - 1] : '';

      switch (c) {
        case 'O':
        case 'o':
          buf.write('0');
          break;
        case 'I':
        case 'l':
        case '|':
          buf.write('1');
          break;
        case 'S':
        case 's':
          // Swap only between digits — keeps words like "Super" untouched.
          if (_isDigit(prev) && _isDigit(next)) {
            buf.write('5');
          } else {
            buf.write(c);
          }
          break;
        case ';':
        case '_':
          continue;
        default:
          buf.write(c);
      }
    }
    return buf.toString();
  }

  bool _isDigit(String s) => s.isNotEmpty && RegExp(r'^\d$').hasMatch(s);
}


class ReceiptTextNormalizer {
  const ReceiptTextNormalizer();

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

  bool _looksNumeric(String token) {
    if (!RegExp(r'\d').hasMatch(token)) return false;
    if (token.length > 24) return false;
    final separators = token.codeUnits
        .where((c) => c == 0x2E || c == 0x2C)
        .length;
    return separators <= 2;
  }

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
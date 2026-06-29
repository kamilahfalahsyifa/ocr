import 'package:intl/intl.dart';

class CurrencyFormatter {
  const CurrencyFormatter._();

  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(String amount) {
    final numeric = double.tryParse(
      amount.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (numeric == null) return amount;
    return _rupiah.format(numeric);
  }
}

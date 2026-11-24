import 'package:intl/intl.dart';

final NumberFormat _idr =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// Prices are whole numbers (no decimals) in the API. Shown as Indonesian rupiah;
/// change the symbol/locale here if you use another currency.
String formatPrice(int v) => _idr.format(v);

String formatKm(int? v) =>
    v == null ? '-' : '${NumberFormat.decimalPattern().format(v)} km';

String formatDate(DateTime? d) =>
    d == null ? '-' : DateFormat('d MMM yyyy, HH:mm').format(d);

String capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

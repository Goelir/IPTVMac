/// Names in the order a person expects: case does not matter and numbers count by value ("Channel 2" before "Channel 10"). Other scripts
/// (Hebrew, Cyrillic, Greek...) follow in their own letter order. Dart has no locale-aware collation built in, so accents on Latin letters
/// sort after "z" instead of beside their base letter.
int compareNames(String a, String b) {
  final x = _chunks.allMatches(a.toLowerCase()).map((m) => m[0]!).toList(), y = _chunks.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final p = x[i], q = y[i];
    final c = _isDigit(p) && _isDigit(q) ? BigInt.parse(p).compareTo(BigInt.parse(q)) : p.compareTo(q);
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}

final _chunks = RegExp(r'\d+|\D+');
bool _isDigit(String s) => s.codeUnitAt(0) >= 0x30 && s.codeUnitAt(0) <= 0x39;

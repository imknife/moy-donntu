const _cyr = 'абвгдежзийклмнопрстуфхцчшщъыьэюя';
const _punct = ' _-,;:!?.\'"()[]{}@*/\\&#%`^+<=>|~\$';

class _Key {
  _Key(this.primary, this.secondary, this.tertiary, {this.number});
  final int primary;
  final int secondary;
  final int tertiary;
  final BigInt? number;
}

_Key _char(String ch) {
  final lower = ch.toLowerCase();
  final upper = lower != ch ? 1 : 0;
  if (lower == 'ё') return _Key(3000 + _cyr.indexOf('е'), 1, upper);
  final cyr = _cyr.indexOf(lower);
  if (cyr >= 0) return _Key(3000 + cyr, lower == 'й' ? 1 : 0, upper);
  final code = lower.codeUnitAt(0);
  if (code >= 0x30 && code <= 0x39) return _Key(1000 + code - 0x30, 0, 0);
  if (code >= 0x61 && code <= 0x7a) return _Key(2000 + code, 0, upper);
  final p = _punct.indexOf(lower);
  if (p >= 0) return _Key(1 + p, 0, 0);
  return _Key(5000 + code, 0, upper);
}

List<_Key> _tokens(String s, bool numeric) {
  final out = <_Key>[];
  final units = s.split('');
  var i = 0;
  while (i < units.length) {
    final c = units[i].codeUnitAt(0);
    if (numeric && c >= 0x30 && c <= 0x39) {
      var j = i;
      while (j < units.length && units[j].codeUnitAt(0) >= 0x30 && units[j].codeUnitAt(0) <= 0x39) {
        j++;
      }
      out.add(_Key(1000, 0, 0, number: BigInt.parse(units.sublist(i, j).join())));
      i = j;
    } else {
      out.add(_char(units[i]));
      i++;
    }
  }
  return out;
}

int compareRu(String a, String b, {bool numeric = false}) {
  final ta = _tokens(a, numeric);
  final tb = _tokens(b, numeric);
  final n = ta.length < tb.length ? ta.length : tb.length;
  for (var i = 0; i < n; i++) {
    final x = ta[i], y = tb[i];
    if (x.number != null || y.number != null) {
      if (x.number == null) return 1;
      if (y.number == null) return -1;
      final c = x.number!.compareTo(y.number!);
      if (c != 0) return c;
    } else if (x.primary != y.primary) {
      return x.primary < y.primary ? -1 : 1;
    }
  }
  if (ta.length != tb.length) return ta.length < tb.length ? -1 : 1;
  for (var i = 0; i < n; i++) {
    if (ta[i].secondary != tb[i].secondary) return ta[i].secondary < tb[i].secondary ? -1 : 1;
  }
  for (var i = 0; i < n; i++) {
    if (ta[i].tertiary != tb[i].tertiary) return ta[i].tertiary < tb[i].tertiary ? -1 : 1;
  }
  return 0;
}

List<T> stableSorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final indexed = [for (final e in items.indexed) e];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1 - b.$1;
  });
  return [for (final e in indexed) e.$2];
}

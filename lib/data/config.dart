import 'package:flutter/foundation.dart';

const _localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

String? resolveApiUrl(String raw, {required bool production}) {
  final value = raw.trim().replaceFirst(RegExp(r'/$'), '');
  if (value.isEmpty) return null;
  final url = Uri.tryParse(value);
  if (url == null || !url.hasScheme || url.host.isEmpty) throw FormatException('API_URL: некорректный адрес «$value»');
  if (url.scheme == 'https') return value;
  if (url.scheme == 'http' && (!production || _localHosts.contains(url.host))) return value;
  throw FormatException('API_URL: в production-сборке нужен https-адрес сервера (получено «$value»)');
}

class AppConfig {
  static const _apiUrl = String.fromEnvironment('API_URL');
  static const _features = String.fromEnvironment('FEATURES');
  static const _aceUrl = String.fromEnvironment('ACE_URL', defaultValue: 'https://ace.donntu.ru');

  static String? get apiUrl => resolveApiUrl(_apiUrl, production: kReleaseMode);

  static String get aceUrl => resolveApiUrl(_aceUrl, production: kReleaseMode)!;

  static Set<String> get featureOverride => _features.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
}

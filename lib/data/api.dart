import 'dart:async';
import 'dart:convert';
import 'dart:io';

class HttpError implements Exception {
  const HttpError(this.message, this.status);
  final String message;
  final int status;

  @override
  String toString() => message;
}

class NoConnection implements Exception {
  const NoConnection([this.message = 'Нет связи с сервером. Проверьте интернет и попробуйте ещё раз.']);
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this.baseUrl);

  static const _timeout = Duration(seconds: 20);

  final String? baseUrl;

  bool get enabled => baseUrl != null;

  Future<String> send(String path, {Object? body}) async {
    final base = baseUrl;
    if (base == null) throw const NoConnection('Сервер не настроен');
    final verb = body == null ? 'GET' : 'POST';
    final client = HttpClient();
    try {
      final request = await client.openUrl(verb, Uri.parse(base + path)).timeout(_timeout);
      request.headers.set('Accept', 'application/json');
      if (body != null) {
        request.headers.set('Content-Type', 'application/json');
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close().timeout(_timeout);
      final text = await response.transform(utf8.decoder).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? detail;
        try {
          final j = jsonDecode(text);
          if (j is Map) detail = (j['message'] ?? j['error']) as String?;
        } catch (_) {}
        throw HttpError(detail ?? (response.statusCode == 401 ? 'Войдите через ACE для доступа' : 'Сервер вернул ошибку ${response.statusCode}'), response.statusCode);
      }
      return text;
    } on HttpError {
      rethrow;
    } on SocketException {
      throw const NoConnection();
    } on TimeoutException {
      throw const NoConnection();
    } on HandshakeException {
      throw const NoConnection();
    } on HttpException {
      throw const NoConnection();
    } finally {
      client.close(force: true);
    }
  }
}

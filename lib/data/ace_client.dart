import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/ace.dart';
import '../domain/cabinet_feed.dart';
import 'records.dart';
import 'secret_store.dart';

class AceError implements Exception {
  const AceError(this.message, {this.status = 0, this.code = 'network'});
  final String message;
  final int status;
  final String code;

  @override
  String toString() => message;
}

const _tokenKey = 'ds:ace:token';
const _zachKey = 'personal:ds:ace:zach';
const _studentKey = 'personal:ds:ace:student';
const _feedKey = 'personal:ds:ace:feed';

class _Envelope {
  const _Envelope(this.data, this.state, this.msg, this.raw);
  final Map<String, dynamic>? data;
  final int state;
  final String msg;
  final Map<String, dynamic> raw;
}

num? _finite(Object? v) {
  if (v == null || v == '') return null;
  final n = num.tryParse('$v');
  return n != null && n.isFinite ? n : null;
}

String? _pick(Map<String, dynamic> d, List<String> keys) {
  for (final k in keys) {
    if (d[k] != null && d[k] != '') return '${d[k]}';
  }
  return null;
}

class AceClient {
  AceClient({
    required this.baseUrl,
    required this.secrets,
    required this.records,
    HttpClient Function()? factory,
    String Function()? fingerprint,
    int Function()? clock,
  })  : _factory = factory ?? HttpClient.new,
        _fingerprint = fingerprint ?? _randomFingerprint,
        _now = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final String baseUrl;
  final SecretStore secrets;
  final Records records;
  final HttpClient Function() _factory;
  static const _timeout = Duration(seconds: 20);
  final String Function() _fingerprint;
  final int Function() _now;
  int _revision = 0;
  Future<void> _pending = Future.value();

  static String _randomFingerprint() {
    final r = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return '${r}0123456789abcdef'.substring(0, 24);
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action(), onError: (_) => action());
    _pending = next.then((_) {}, onError: (_) {});
    return next;
  }

  void _ensure(int revision) {
    if (revision != _revision) throw const AceError('Запрос отменён после выхода', code: 'session_changed');
  }

  Future<_Envelope> _call(String path, {Map<String, dynamic>? body, String? token}) async {
    final base = baseUrl.replaceFirst(RegExp(r'/$'), '').replaceFirst(RegExp(r'/api$'), '');
    final client = _factory();
    try {
      final request = await client.openUrl(body == null ? 'GET' : 'POST', Uri.parse('$base/api/$path')).timeout(_timeout);
      request.headers.set('Accept', 'application/json');
      if (token != null) request.headers.set('Authorization', 'Bearer $token');
      if (body != null) {
        request.headers.set('Content-Type', 'application/json');
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close().timeout(_timeout);
      final text = await response.transform(utf8.decoder).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 && token == null) return const _Envelope(null, 0, 'Неверные логин или пароль', {});
        throw AceError(
          response.statusCode == 401 ? 'Вход истёк — войди ещё раз' : (response.statusCode == 429 ? 'Слишком много попыток — подожди минуту' : 'Сервис недоступен — попробуйте позже'),
          status: response.statusCode,
          code: 'http',
        );
      }
      final json = jsonDecode(text) as Map<String, dynamic>;
      return _Envelope(json['data'] is Map ? (json['data'] as Map).cast<String, dynamic>() : null, (json['state'] as num?)?.toInt() ?? 0, json['msg'] as String? ?? '', json);
    } on AceError {
      rethrow;
    } on TimeoutException {
      throw const AceError('Сервис не ответил вовремя', code: 'timeout');
    } on FormatException {
      throw const AceError('Сервис недоступен — попробуйте позже', code: 'http');
    } catch (_) {
      throw const AceError('Проверь подключение к сети');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _persist(int revision, String key, Object value) => _enqueue(() async {
        _ensure(revision);
        await records.set(key, jsonEncode(value));
        _ensure(revision);
      });

  Future<void> _clearSession() => _enqueue(() async {
        await secrets.delete(_tokenKey);
        await records.remove(_zachKey);
        await records.remove(_studentKey);
        await records.remove(_feedKey);
      });

  Future<LoginResult> login({required String userName, required String password, String? captchaKey, String? captchaCode, String? otpCode}) async {
    final revision = ++_revision;
    await _clearSession();
    _ensure(revision);
    final r = await _call('tokenauth', body: {
      'userName': userName,
      'password': password,
      'isParent': false,
      'fingerprint': await _fingerprintValue(),
      'captchaKey': captchaKey ?? '',
      'captchaCode': captchaCode ?? '',
      'otpCode': otpCode ?? '',
      'redirect': false,
    });
    _ensure(revision);
    final token = r.data?['accessToken'];
    if (token is String && token.isNotEmpty) {
      await _enqueue(() => secrets.write(_tokenKey, token));
      return LoginOk(token);
    }
    if (r.data?['require2FA'] == true) return LoginTwoFactor(email: r.data?['email'] as String? ?? '', message: r.msg.isNotEmpty ? r.msg : 'Введи код из письма');
    final msg = r.msg.isNotEmpty ? r.msg : 'Не получилось войти';
    if (RegExp(r'не\s*верн|капч|код с картинки', caseSensitive: false).hasMatch(msg)) {
      try {
        final c = await captcha();
        _ensure(revision);
        return LoginCaptcha(imageBase64: c.image, key: c.key, message: msg);
      } on AceError catch (e) {
        if (e.code == 'session_changed') rethrow;
      }
    }
    return LoginError(msg);
  }

  Future<String> _fingerprintValue() async {
    final saved = await records.get('device-fingerprint');
    if (saved != null) return saved;
    final value = _fingerprint();
    await records.set('device-fingerprint', value);
    return value;
  }

  Future<({String image, String key})> captcha() async {
    final r = await _call('auth/Captcha');
    final c = r.raw['image'] != null ? r.raw : r.data;
    final image = c?['image'];
    final key = c?['key'];
    if (image is! String || key is! String) throw const AceError('ACE не выдал картинку с кодом');
    return (image: image, key: key);
  }

  Future<String?> token() => secrets.read(_tokenKey);

  Future<T?> _read<T>(String key, T Function(Map<String, dynamic>) parse) async {
    final revision = _revision;
    await _pending;
    _ensure(revision);
    final raw = await records.get(key);
    _ensure(revision);
    if (raw == null) return null;
    try {
      return parse(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<ZachBook?> cachedBook() => _read(_zachKey, ZachBook.fromJson);

  Future<StudentCard?> cachedStudent() => _read(_studentKey, StudentCard.fromJson);

  Future<AceFeed?> cachedFeed() => _read(_feedKey, AceFeed.fromJson);

  Future<void> logout() async {
    _revision++;
    await _clearSession();
  }

  Future<StudentCard> student(String token) async {
    final revision = _revision;
    final r = await _call('Students/Card', token: token);
    _ensure(revision);
    final d = r.data?['studentCard'];
    if (r.state != 1 || d is! Map) throw AceError(r.msg.isNotEmpty ? r.msg : 'ACE не отдал студенческий билет');
    final m = d.cast<String, dynamic>();
    final card = StudentCard(
      fullName: _pick(m, ['fullName']) ?? '',
      university: _pick(m, ['universityName']),
      number: _pick(m, ['cardNumber']),
      issued: _pick(m, ['cardDate']),
      order: _pick(m, ['documentNubmer', 'documentNumber']),
      level: _pick(m, ['levelName']),
      direction: _pick(m, ['specialityName']),
      course: _finite(m['course'])?.toInt(),
      form: _pick(m, ['formStudy']),
      loadedAt: _now(),
    );
    await _persist(revision, _studentKey, card.toJson());
    return card;
  }

  Future<Map<String, dynamic>?> _me(String token, int revision) async {
    final me = await _call('tokenauth', token: token);
    _ensure(revision);
    if (me.state != 1) throw AceError(me.msg.isNotEmpty ? me.msg : 'Вход в ACE истёк — войди ещё раз');
    final user = me.data?['user'];
    return user is Map ? user.cast<String, dynamic>() : null;
  }

  Future<AceFeed> feed(String token) async {
    final revision = _revision;
    final u = await _me(token, revision);
    final userId = (u?['userID'] as num?)?.toInt() ?? (u?['studentID'] != null ? -(u!['studentID'] as num).toInt() : null);
    if (userId == null) throw const AceError('ACE не назвал номер пользователя');
    final r = await _call('Feed?userID=$userId', token: token);
    _ensure(revision);
    if (r.state != 1) throw AceError(r.msg.isNotEmpty ? r.msg : 'ACE не отдал уведомления');
    final raw = (r.data?['feed'] as List? ?? const []).cast<Map<String, dynamic>>();
    final items = [
      for (final e in raw.indexed)
        () {
          final x = e.$2;
          final category = '${x['category'] ?? ''}';
          final text = plainText('${x['text'] ?? x['html'] ?? ''}');
          final kind = RegExp('пропуск', caseSensitive: false).hasMatch(text)
              ? 'absence'
              : (RegExp(r'оценк|зач[её]т', caseSensitive: false).hasMatch(text) ? 'grade' : (category == 'Перемещения' ? 'move' : 'other'));
          final idPart = '${(x['notificationID'] ?? x['objectID']) ?? e.$1}';
          return AceFeedItem(
            id: '$idPart:${x['fullDate'] ?? e.$1}',
            category: category,
            kind: kind,
            text: text,
            date: x['date'] != null ? '${x['date']}' : null,
            time: x['time'] != null ? '${x['time']}' : null,
            isNew: x['isNew'] == true,
          );
        }(),
    ];
    final feed = AceFeed(items: items, absences: items.where((i) => i.kind == 'absence').length, unread: items.where((i) => i.isNew).length, loadedAt: _now());
    await _persist(revision, _feedKey, feed.toJson());
    return feed;
  }

  Future<ZachBook> zachBook(String token) async {
    final revision = _revision;
    final u = await _me(token, revision);
    final studentId = (u?['studentID'] as num?)?.toInt() ?? ((u?['userID'] as num?) != null && (u!['userID'] as num) < 0 ? -(u['userID'] as num).toInt() : null);
    final r = await _call('EducationalActivity/ZachBook${studentId != null ? '?studentID=$studentId' : ''}', token: token);
    _ensure(revision);
    if (r.state != 1 || r.data == null) throw AceError(r.msg.isNotEmpty ? r.msg : 'ACE не отдал зачётку');
    final d = r.data!;
    final book = ZachBook(
      studentName: _pick(d, ['studentName']) ?? '',
      avgPoint: _finite(d['avgPoint']),
      currentSem: _finite(d['currentSem'])?.toInt(),
      rows: [for (final x in (d['zachBook'] as List? ?? const [])) if (x is Map) ZachRow.fromJson(x.cast<String, dynamic>())],
      share: [
        for (final s in (d['markCountStatistic'] as List? ?? const []))
          if (s is Map && _finite(s['mark']) != null && _finite(s['avg']) != null) MarkShare(_finite(s['mark'])!, _finite(s['avg'])!),
      ],
      loadedAt: _now(),
    );
    await _persist(revision, _zachKey, book.toJson());
    return book;
  }
}

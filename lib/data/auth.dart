import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/ace.dart';
import 'ace_client.dart';
import 'records.dart';
import 'resources.dart';
import 'secret_store.dart';

const _sessionKey = 'donntu-server-session';
const _localSessionPrefix = 'local:';

class AceSignInRequired implements Exception {
  const AceSignInRequired();

  @override
  String toString() => 'Для данных ACE войдите через университетскую учётную запись';
}

class AceResource<T> extends ValueNotifier<ResourceState<T>> {
  AceResource(this._auth, this._cached, this._fresh) : super(const ResourceState());
  final AuthService _auth;
  final Future<T?> Function() _cached;
  final Future<T> Function(String token) _fresh;
  Future<void>? _running;

  Future<void> refresh() => _running ??= Future<void>.microtask(_run).whenComplete(() => _running = null);

  void reset() => value = const ResourceState();

  Future<void> _run() async {
    final session = _auth.session.value;
    if (session == null) {
      value = const ResourceState(error: AceSignInRequired());
      return;
    }
    value = ResourceState(data: value.data, loading: true);
    T? cached;
    try {
      cached = await _cached();
    } catch (_) {
      cached = null;
    }
    if (_auth.session.value != session) return;
    if (cached != null && value.data == null) value = ResourceState(data: cached, loading: true);
    final token = await _auth.ace.token();
    if (token == null) {
      value = const ResourceState(error: AceSignInRequired());
      return;
    }
    try {
      final fresh = await _fresh(token);
      if (_auth.session.value != session) return;
      value = ResourceState(data: fresh);
    } catch (e) {
      if (_auth.session.value != session) return;
      final denied = (e is AceError && (e.status == 401 || e.status == 403 || e.code == 'session_changed')) || RegExp(r'ист[её]к|401|403|сесси|отмен[её]н', caseSensitive: false).hasMatch('$e');
      final saved = value.data ?? cached;
      if (!denied && saved != null) {
        value = ResourceState(data: saved, offline: true);
      } else {
        value = ResourceState(error: e);
      }
    }
  }
}

class AuthService {
  AuthService({required this.ace, required this.secrets, required this.records, required this.session});
  final AceClient ace;
  final SecretStore secrets;
  final Records records;
  final ValueNotifier<String?> session;
  int _ticket = 0;

  late final AceResource<StudentCard> student = AceResource(this, ace.cachedStudent, ace.student);
  late final AceResource<ZachBook> book = AceResource(this, ace.cachedBook, ace.zachBook);
  late final AceResource<AceFeed> feed = AceResource(this, ace.cachedFeed, ace.feed);

  Future<void> restore() async {
    session.value = await secrets.read(_sessionKey);
  }

  Future<LoginResult> login({required String userName, required String password, String? captchaKey, String? captchaCode, String? otpCode}) async {
    if (session.value != null) await logout();
    final ticket = ++_ticket;
    final result = await ace.login(userName: userName, password: password, captchaKey: captchaKey, captchaCode: captchaCode, otpCode: otpCode);
    if (ticket != _ticket) throw const AceError('Вход отменён: сессия изменилась', code: 'session_changed');
    if (result is LoginOk) await connect(ticket);
    return result;
  }

  Future<void> connect(int ticket) async {
    if (ticket != _ticket) throw const AceError('Вход отменён: сессия изменилась', code: 'session_changed');
    final value = '$_localSessionPrefix${_randomId()}';
    await secrets.write(_sessionKey, value);
    if (ticket != _ticket) {
      await secrets.delete(_sessionKey);
      throw const AceError('Вход отменён: сессия изменилась', code: 'session_changed');
    }
    session.value = value;
  }

  Future<void> logout() async {
    _ticket++;
    session.value = null;
    await ace.logout();
    await secrets.delete(_sessionKey);
    await records.removePrefix('personal:');
    student.reset();
    book.reset();
    feed.reset();
  }

  String _randomId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}

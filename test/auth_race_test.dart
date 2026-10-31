import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_lab/data/ace_client.dart';
import 'package:flutter_lab/data/auth.dart';
import 'package:flutter_lab/data/records.dart';
import 'package:flutter_lab/data/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

class GatedSecretStore extends MemorySecretStore {
  final Completer<void> gate = Completer<void>();
  final Completer<void> writeStarted = Completer<void>();

  @override
  Future<void> write(String key, String value) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await gate.future;
    await super.write(key, value);
  }
}

void main() {
  test('выход во время записи ключа: вход отменяется, ключ удаляется, сессия пуста', () async {
    final secrets = GatedSecretStore();
    final records = MemoryRecords();
    final session = ValueNotifier<String?>(null);
    final auth = AuthService(
      ace: AceClient(baseUrl: 'http://127.0.0.1:1', secrets: secrets, records: records),
      secrets: secrets,
      records: records,
      session: session,
    );
    final connecting = auth.connect(0);
    final failure = expectLater(connecting, throwsA(isA<AceError>().having((e) => e.code, 'code', 'session_changed')));
    await secrets.writeStarted.future;
    await auth.logout();
    secrets.gate.complete();
    await failure;
    expect(session.value, isNull);
    expect(secrets.values, isEmpty);
    expect(await auth.secrets.read('donntu-server-session'), isNull);
  });

  test('обычный вход пишет локальную сессию', () async {
    final secrets = MemorySecretStore();
    final session = ValueNotifier<String?>(null);
    final records = MemoryRecords();
    final auth = AuthService(ace: AceClient(baseUrl: 'http://127.0.0.1:1', secrets: secrets, records: records), secrets: secrets, records: records, session: session);
    await auth.connect(0);
    expect(session.value, startsWith('local:'));
    expect(await secrets.read('donntu-server-session'), session.value);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lab/data/ace_client.dart';
import 'package:flutter_lab/data/records.dart';
import 'package:flutter_lab/data/secret_store.dart';
import 'package:flutter_lab/domain/brand.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Future<void> go(WidgetTester tester, String location) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed(location);
  await tester.pumpAndSettle();
}

final zachBook = {
  'studentName': 'Иванов',
  'avgPoint': 4.5,
  'currentSem': 2,
  'loadedAt': 1,
  'share': [],
  'rows': [
    {'dis': 'Математика', 'controlForm': 'Экзамен', 'mark': 'отлично', 'markNumber': 5, 'sem': 2, 'course': 1, 'hours': 144, 'zet': 4, 'teacherName': 'Петров П.П.', 'dateExam': '2026-01-15', 'year': '2025-2026'},
    {'dis': 'Физика', 'controlForm': 'Экзамен', 'mark': 'хорошо', 'markNumber': 4, 'sem': 2, 'course': 1, 'hours': 108, 'zet': null, 'teacherName': null, 'dateExam': null, 'year': null},
    {'dis': 'Философия', 'controlForm': 'Зачёт', 'mark': 'зачтено', 'markNumber': 7, 'sem': 1, 'course': 1, 'hours': null, 'zet': null, 'teacherName': null, 'dateExam': null, 'year': null},
    {'dis': 'Математика', 'controlForm': 'Экзамен', 'mark': 'хорошо', 'markNumber': 4, 'sem': 1, 'course': 1, 'hours': null, 'zet': null, 'teacherName': null, 'dateExam': null, 'year': null},
  ],
};

final studentCard = {
  'fullName': 'Иванов Иван Иванович',
  'university': 'ДонНТУ',
  'number': '12345',
  'issued': '2024-09-01',
  'order': '№ 55',
  'level': 'Бакалавр',
  'direction': 'Программная инженерия',
  'profile': null,
  'course': 2,
  'form': 'Очная',
  'group': null,
  'loadedAt': 1,
};

final feed = {
  'items': [
    {'id': '1:1', 'category': 'Пропуски', 'kind': 'absence', 'text': 'Вам выставлен пропуск по дисциплине "Физика" за 07.09.2026', 'date': '07.09.2026', 'time': null, 'isNew': true},
    {'id': '2:2', 'category': 'Оценки', 'kind': 'grade', 'text': 'Оценка 5\nпо математике', 'date': null, 'time': null, 'isNew': false},
  ],
  'absences': 1,
  'unread': 1,
  'loadedAt': 1,
};

Future<(MemorySecretStore, MemoryRecords)> signedIn() async {
  final secrets = MemorySecretStore();
  final records = MemoryRecords();
  await secrets.write('ds:ace:token', 'tok');
  await secrets.write('donntu-server-session', 'local:abc');
  records.data['personal:ds:ace:zach'] = jsonEncode(zachBook);
  records.data['personal:ds:ace:student'] = jsonEncode(studentCard);
  records.data['personal:ds:ace:feed'] = jsonEncode(feed);
  return (secrets, records);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('первый запуск: выбор группы и вход через кабинет', (tester) async {
    final c = await makeController();
    await pumpApp(tester, c);
    expect(find.text('Выберите группу'), findsOneWidget);
    expect(find.text('Войти через кабинет'), findsOneWidget);
    await tester.tap(find.text('Войти через кабинет'));
    await tester.pumpAndSettle();
    expect(find.text('Кабинет студента'), findsOneWidget);
    expect(find.text('Пароль не сохраняется на телефоне'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('вход: кнопка неактивна без логина и пароля, пароль скрыт', (tester) async {
    final c = await makeController();
    await pumpApp(tester, c);
    await go(tester, '/login');
    final field = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(field.obscureText, isTrue);
    await tester.tap(find.text('Войти').last);
    await tester.pumpAndSettle();
    expect(c.session.value, isNull);
    await unmount(tester);
  });

  testWidgets('вход: успешный вход сохраняет сессию, чистит пароль и открывает расписание', (tester) async {
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);
    final server = (await tester.runAsync(() => HttpServer.bind(InternetAddress.loopbackIPv4, 0)))!;
    addTearDown(() => server.close(force: true));
    final passwords = <String>[];
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'POST') {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
        passwords.add('${body['password']}');
        request.response.write(jsonEncode({'state': 1, 'msg': '', 'data': {'accessToken': 'tok-77'}}));
      } else if (request.uri.path.endsWith('Students/Card')) {
        request.response.write(jsonEncode({'state': 1, 'msg': '', 'data': {'studentCard': {'fullName': 'Иванов Пётр Сергеевич', 'cardNumber': '9'}}}));
      } else {
        request.response.write(jsonEncode({'state': 0, 'msg': 'нет', 'data': null}));
      }
      await request.response.close();
    });
    final secrets = MemorySecretStore();
    final records = MemoryRecords();
    final ace = AceClient(baseUrl: 'http://127.0.0.1:${server.port}', secrets: secrets, records: records, fingerprint: () => 'fp');
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, secrets: secrets, records: records, ace: ace);
    await pumpApp(tester, c);
    await go(tester, '/login');
    await tester.enterText(find.byType(TextField).at(0), 'student');
    await tester.enterText(find.byType(TextField).at(1), 'мой-пароль');
    await tester.pump();
    await tester.tap(find.text('Войти').last);
    for (var i = 0; i < 40 && c.session.value == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    for (var i = 0; i < 40 && c.store.prefs.value.displayName.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.session.value, startsWith('local:'));
    expect(passwords, ['мой-пароль']);
    expect(secrets.values['ds:ace:token'], 'tok-77');
    expect(secrets.values.values.join(), isNot(contains('мой-пароль')));
    expect(records.data.values.join(), isNot(contains('мой-пароль')));
    expect(c.store.prefs.value.displayName, 'Пётр Иванов');
    expect(find.text('Войти'), findsNothing);
    await unmount(tester);
  });

  testWidgets('зачётка: сводка, семестры, переключатель оценок и зачётов, подробности', (tester) async {
    final (secrets, records) = await signedIn();
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, secrets: secrets, records: records);
    await pumpApp(tester, c);
    await c.auth.restore();
    await go(tester, '/gradebook');
    await tester.pumpAndSettle();
    expect(find.text('Средний балл'), findsOneWidget);
    expect(find.text('4,5'), findsWidgets);
    expect(find.text('Математика'), findsOneWidget);
    expect(find.text('Философия'), findsNothing);
    await tester.tap(find.text('Зачёты'));
    await tester.pumpAndSettle();
    expect(find.text('Записей пока нет'), findsOneWidget);
    await tester.tap(find.text('Открыть «Оценки»'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Математика'));
    await tester.pumpAndSettle();
    expect(find.text('Отлично'), findsOneWidget);
    expect(find.text('Петров П.П.'), findsOneWidget);
    expect(find.text('15.01.2026'), findsOneWidget);
    expect(find.text('ДРУГИЕ СЕМЕСТРЫ'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('студенческий билет показывает реквизиты на одной странице', (tester) async {
    final (secrets, records) = await signedIn();
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, secrets: secrets, records: records);
    await pumpApp(tester, c);
    await c.auth.restore();
    await go(tester, '/student-card');
    await tester.pumpAndSettle();
    expect(find.text('Иванов Иван Иванович'), findsOneWidget);
    expect(find.text('Бакалавр'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('лента кабинета: фильтры и счётчики', (tester) async {
    final (secrets, records) = await signedIn();
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, secrets: secrets, records: records);
    await pumpApp(tester, c);
    await c.auth.restore();
    await go(tester, '/cabinet');
    await tester.pumpAndSettle();
    expect(find.text('Пропусков'), findsOneWidget);
    expect(find.text('Физика'), findsOneWidget);
    await tester.tap(find.text('Оценки').first);
    await tester.pumpAndSettle();
    expect(find.text('Физика'), findsNothing);
    expect(find.text('Оценка 5'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('без входа разделы ACE предлагают войти', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    for (final route in ['/gradebook', '/student-card', '/cabinet']) {
      await go(tester, route);
      expect(find.text('Войти'), findsOneWidget, reason: route);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    }
    await unmount(tester);
  });

  testWidgets('выход стирает токен, сессию и кеш кабинета, заметки остаются', (tester) async {
    final (secrets, records) = await signedIn();
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, secrets: secrets, records: records, stored: {
      'notes': jsonEncode([
        {'id': 'n', 'title': 'Моя', 'text': 'заметка', 'updatedAt': '2026-10-23T10:00:00Z'},
      ]),
    });
    await pumpApp(tester, c);
    await c.auth.restore();
    expect(c.session.value, 'local:abc');
    await go(tester, '/logout');
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(find.text('Вы вышли из аккаунта'), findsOneWidget);
    expect(c.session.value, isNull);
    expect(secrets.values, isEmpty);
    expect(records.data.keys.where((k) => k.startsWith('personal:')), isEmpty);
    expect(c.store.notes.value.single.id, 'n');
    await unmount(tester);
  });

  testWidgets('карта кампуса закрыта флагом и открывается, когда он включён', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await go(tester, '/campus');
    expect(find.text('Страница не найдена'), findsWidgets);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    c.features.value = const Features(campus: true);
    await go(tester, '/campus?building=4');
    expect(find.text('Корпус 4'), findsWidgets);
    expect(find.text('ул. Кобозева, 17, Донецк'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('карта кампуса: маршрут между корпусами и время в пути', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    c.features.value = const Features(campus: true);
    await pumpApp(tester, c);
    await go(tester, '/campus?from=4&to=1');
    expect(find.textContaining('мин пешком'), findsOneWidget);
    expect(find.text('Маршрут в Яндекс Картах'), findsOneWidget);
    await tester.tap(find.byTooltip('Убрать маршрут').evaluate().isEmpty ? find.bySemanticsLabel('Убрать маршрут') : find.byTooltip('Убрать маршрут'));
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('карта кампуса: поиск аудитории и выбор корпуса', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    c.features.value = const Features(campus: true);
    await pumpApp(tester, c);
    await go(tester, '/campus');
    await tester.enterText(find.byType(TextField), '8.705');
    await tester.pumpAndSettle();
    expect(find.text('ауд. 8.705'), findsOneWidget);
    await tester.tap(find.text('Корпус 8').first);
    await tester.pumpAndSettle();
    expect(find.text('Аудитория 8.705'), findsOneWidget);
    expect(find.text('Маршрут сюда'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('страница пары: кнопки «Файлы» и «Корпус»', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    c.features.value = const Features(campus: true);
    await pumpApp(tester, c);
    await go(tester, '/lesson?date=2026-10-23&group=ПИ-25а&sub=1&slot=2&key=2-0-Алгоритмы и структуры данных');
    expect(find.text('Файлы'), findsOneWidget);
    expect(find.text('Корпус'), findsOneWidget);
    await tester.tap(find.text('Корпус'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Корпус 8'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('мои файлы: добавление, открытие и удаление с подтверждением', (tester) async {
    final files = FakeFiles();
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, files: files);
    await pumpApp(tester, c);
    await go(tester, '/materials');
    expect(find.text('Добавьте конспект, презентацию или практикум'), findsOneWidget);
    await tester.tap(find.text('Добавить файл'));
    await tester.pumpAndSettle();
    expect(find.text('Конспект.pdf'), findsOneWidget);
    expect(find.text('2 КБ'), findsOneWidget);
    await tester.tap(find.text('Конспект.pdf'));
    await tester.pumpAndSettle();
    expect(files.opened, ['Конспект.pdf']);
    await tester.tap(find.bySemanticsLabel('Удалить файл Конспект.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(files.deleted, ['/tmp/Конспект.pdf']);
    expect(c.store.materials.value, isEmpty);
    await unmount(tester);
  });
}

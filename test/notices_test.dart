import 'package:flutter_lab/data/store.dart';
import 'package:flutter_lab/domain/deadline.dart';
import 'package:flutter_lab/domain/models.dart';
import 'package:flutter_lab/domain/notes.dart';
import 'package:flutter_lab/domain/notices.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

Deadline deadline(String id, String due, {bool done = false}) => Deadline(id: id, title: 'Работа $id', due: due, createdAt: '2026-10-20T10:00:00Z', done: done);

Note note(String id, String title) => Note(id: id, title: title, text: '', updatedAt: '2026-10-20T10:00:00Z');

void main() {
  setUpAll(loadFonts);

  test('уведомления: изменения, просроченные и сегодняшние дедлайны, кабинет', () {
    final notices = buildNotices(
      changes: const [
        LessonChange(type: 'changed', day: 3, num: 2, week: 'UPPER', subgroup: 0, subject: 'Дискретная математика', fields: [FieldChange(field: 'rooms', from: '8.705', to: '5.426')]),
        LessonChange(type: 'removed', day: 4, num: 1, week: 'UPPER', subgroup: 0, subject: 'Алгоритмы', fields: null),
      ],
      deadlines: [deadline('a', '2026-10-22'), deadline('b', '2026-10-23'), deadline('c', '2026-11-20'), deadline('d', '2026-10-01', done: true)],
      today: DateTime.utc(2026, 10, 23),
      minute: 600,
      feedAbsences: 2,
      feedUnread: 1,
    );
    expect(notices.map((n) => n.title), ['Дискретная математика', 'Алгоритмы', 'Работа a', 'Работа b', 'Лента кабинета']);
    expect(notices.first.text, 'Ср · перенесена в 5.426');
    expect(notices[1].text, 'Чт · отменена');
    expect(notices[3].text, 'Срок сегодня');
    expect({for (final n in notices) n.id}.length, notices.length);
  });

  test('уведомления: перенос A->B и затем B->C даёт разные идентификаторы', () {
    String idOf(String from, String to) => buildNotices(
          changes: [LessonChange(type: 'changed', day: 3, num: 2, week: 'UPPER', subgroup: 0, subject: 'Дискретная математика', fields: [FieldChange(field: 'rooms', from: from, to: to)])],
          deadlines: const [],
          today: DateTime.utc(2026, 10, 23),
          minute: 600,
        ).single.id;
    final first = idOf('8.705', '5.426');
    final second = idOf('5.426', '3.101');
    expect(first, isNot(second));
    expect(idOf('8.705', '5.426'), first);
    expect(first, contains('rooms'));
    expect(first, contains('5.426'));
  });

  test('уведомления: порядок полей не влияет на идентификатор', () {
    String idOf(List<FieldChange> fields) => buildNotices(
          changes: [LessonChange(type: 'changed', day: 1, num: 1, week: 'UPPER', subgroup: 0, subject: 'Алгоритмы', fields: fields)],
          deadlines: const [],
          today: DateTime.utc(2026, 10, 23),
          minute: 600,
        ).single.id;
    const rooms = FieldChange(field: 'rooms', from: '1', to: '2');
    const teachers = FieldChange(field: 'teachers', from: '', to: 'Иванов И.И.');
    expect(idOf([rooms, teachers]), idOf([teachers, rooms]));
    expect(idOf([rooms]), isNot(idOf([rooms, teachers])));
  });

  test('уведомления: без событий список пуст', () {
    expect(buildNotices(changes: const [], deadlines: [deadline('c', '2026-11-20')], today: DateTime.utc(2026, 10, 23), minute: 600), isEmpty);
  });

  test('прочитанные уведомления и удаление пачкой сохраняются', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.open();
    store.setPrefs((p) => p.copyWith(readNotices: ['change:1', 'feed:1:1']));
    store.saveNote(note('n1', 'Первая'));
    store.saveNote(note('n2', 'Вторая'));
    store.saveNote(note('n3', 'Третья'));
    store.saveDeadline(deadline('d1', '2026-11-01'));
    store.saveDeadline(deadline('d2', '2026-11-02'));
    store.removeNotes({'n1', 'n3'});
    store.removeDeadlines({'d1'});
    final again = AppStore.fromPreferences(await SharedPreferences.getInstance());
    expect(again.prefs.value.readNotices, ['change:1', 'feed:1:1']);
    expect(again.notes.value.map((n) => n.id), ['n2']);
    expect(again.deadlines.value.map((d) => d.id), ['d2']);
  });

  testWidgets('дедлайны: долгое нажатие выбирает, выбранные удаляются разом', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, stored: {'preferences': '{"onboarded":true}'});
    c.store.saveDeadline(deadline('a', '2026-10-30'));
    c.store.saveDeadline(deadline('b', '2026-10-31'));
    c.store.saveDeadline(deadline('c', '2026-11-02'));
    await pumpApp(tester, c);
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Сервисы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дедлайны'));
    await tester.pumpAndSettle();
    expect(find.text('Работа a'), findsOneWidget);
    await tester.longPress(find.text('Работа a'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрано: 1'), findsOneWidget);
    await tester.tap(find.text('Работа b'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрано: 2'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Удалить выбранные'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(c.store.deadlines.value.map((d) => d.id), ['c']);
    expect(find.textContaining('Выбрано'), findsNothing);
    handle.dispose();
    await unmount(tester);
  });

  testWidgets('заметки: выбор нескольких, закрепление и удаление', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, stored: {'preferences': '{"onboarded":true}'});
    c.store.saveNote(note('n1', 'Первая'));
    c.store.saveNote(note('n2', 'Вторая'));
    c.store.saveNote(note('n3', 'Третья'));
    await pumpApp(tester, c);
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Сервисы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Заметки'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Первая'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Третья'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрано: 2'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Закрепить выбранные'));
    await tester.pumpAndSettle();
    expect({for (final n in c.store.notes.value) if (n.pinned) n.id}, {'n1', 'n3'});
    await tester.longPress(find.text('Вторая'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Удалить выбранные'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(c.store.notes.value.map((n) => n.id).toSet(), {'n1', 'n3'});
    handle.dispose();
    await unmount(tester);
  });

  testWidgets('уведомления: непрочитанное с точкой, «Прочитать все» гасит точку, прочитанное серое', (tester) async {
    final c = await makeController(
      group: 'ПИ-25а',
      subgroup: 1,
      stored: {'preferences': '{"onboarded":true}'},
    );
    c.store.saveDeadline(deadline('a', '2026-10-20'));
    await pumpApp(tester, c);
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Обзор'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Уведомления, непрочитанных: 1'));
    await tester.pumpAndSettle();
    expect(find.text('Работа a'), findsOneWidget);
    expect(find.text('Прочитать все'), findsOneWidget);
    await tester.tap(find.text('Прочитать все'));
    await tester.pumpAndSettle();
    expect(find.text('Прочитать все'), findsNothing);
    expect(c.store.prefs.value.readNotices, isNotEmpty);
    expect(find.text('Работа a'), findsOneWidget);
    handle.dispose();
    await unmount(tester);
  });
}

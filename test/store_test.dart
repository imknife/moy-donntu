import 'dart:convert';

import 'package:flutter_lab/data/loader.dart';
import 'package:flutter_lab/data/store.dart';
import 'package:flutter_lab/domain/notes.dart';
import 'package:flutter_lab/ui/group_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

Future<AppStore> open(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return AppStore.fromPreferences(await SharedPreferences.getInstance());
}

void main() {
  test('пустое хранилище: настройки по умолчанию, онбординг не пройден', () async {
    final store = await open({});
    expect(store.selection.value, (group: '', subgroup: 0));
    expect(store.prefs.value.onboarded, isFalse);
    expect(store.prefs.value.theme, ThemeChoice.system);
    expect(store.prefs.value.showCancelled, isTrue);
    expect(store.notes.value, isEmpty);
  });

  test('группа, подгруппа, настройки и заметки переживают перезапуск', () async {
    final store = await open({});
    store.setGroup('ПИ-25а', 2);
    store.setPrefs((p) => p.copyWith(theme: ThemeChoice.dark, mode: 2, hidePast: true, largeText: true, onboarded: true));
    store.saveNote(const Note(id: 'a', title: '', text: '☐ x', updatedAt: '2026-10-23T10:00:00Z', lessonKey: 'k', lessonDate: '2026-10-23'));
    final sp = await SharedPreferences.getInstance();
    final again = AppStore.fromPreferences(sp);
    expect(again.selection.value, (group: 'ПИ-25а', subgroup: 2));
    expect(again.prefs.value.theme, ThemeChoice.dark);
    expect(again.prefs.value.mode, 2);
    expect(again.prefs.value.hidePast, isTrue);
    expect(again.prefs.value.largeText, isTrue);
    expect(again.notes.value.single.lessonKey, 'k');
  });

  test('запись настроек совместима с форматом RN: fontSize и onboarded', () async {
    final store = await open({});
    store.setPrefs((p) => p.copyWith(largeText: true, onboarded: true));
    final sp = await SharedPreferences.getInstance();
    final json = jsonDecode(sp.getString('preferences')!) as Map<String, dynamic>;
    expect(json['fontSize'], 'large');
    expect(json['onboarded'], isTrue);
    expect(json.containsKey('motion'), isFalse);
    expect(json.containsKey('font'), isFalse);
    expect(json.containsKey('iconSet'), isFalse);
  });

  test('старые настройки с font, iconSet и motion читаются, лишние ключи отбрасываются', () async {
    final store = await open({
      'preferences': jsonEncode({
        'theme': 'dark',
        'onboarded': true,
        'font': 'jost',
        'iconSet': 'phosphor',
        'motion': 'reduced',
        'textCase': 'lower',
        'fontSize': 'large',
      }),
    });
    final prefs = store.prefs.value;
    expect(prefs.theme, ThemeChoice.dark);
    expect(prefs.onboarded, isTrue);
    expect(prefs.largeText, isTrue);
    store.setPrefs((p) => p.copyWith(hidePast: true));
    final sp = await SharedPreferences.getInstance();
    final saved = jsonDecode(sp.getString('preferences')!) as Map<String, dynamic>;
    expect(saved.containsKey('font'), isFalse);
    expect(saved.containsKey('iconSet'), isFalse);
    expect(saved.containsKey('motion'), isFalse);
    expect(saved.containsKey('textCase'), isFalse);
    expect(saved['theme'], 'dark');
  });

  test('выбранная группа без флага онбординга считается пройденным онбордингом', () async {
    final store = await open({'selection': jsonEncode({'group': 'ПИ-25а', 'subgroup': 1})});
    expect(store.prefs.value.onboarded, isTrue);
  });

  test('повреждённые данные не ломают запуск', () async {
    final store = await open({'selection': '{', 'preferences': 'мусор', 'notes': '[1,2]'});
    expect(store.selection.value.group, '');
    expect(store.prefs.value, const Prefs());
    expect(store.notes.value, isEmpty);
  });

  test('подгруппа ограничена диапазоном 0..2', () async {
    final store = await open({'selection': jsonEncode({'group': 'ПИ-25а', 'subgroup': 9})});
    expect(store.selection.value.subgroup, 2);
  });

  test('заметки: новая сверху, замена по id, удаление', () async {
    final store = await open({});
    store.saveNote(const Note(id: '1', title: '', text: 'a', updatedAt: ''));
    store.saveNote(const Note(id: '2', title: '', text: 'b', updatedAt: ''));
    store.saveNote(const Note(id: '1', title: '', text: 'a2', updatedAt: ''));
    expect(store.notes.value.map((n) => n.id + n.text), ['1a2', '2b']);
    store.removeNote('2');
    expect(store.notes.value.map((n) => n.id), ['1']);
  });

  test('поиск групп по коду и факультету без учёта регистра', () {
    const groups = [GroupInfo('ПИ-25а', 1, 'Факультет интеллектуальных систем'), GroupInfo('ИИ-23', 4, 'Факультет интеллектуальных систем'), GroupInfo('АВТ-21', 3, 'Другой факультет')];
    expect(filterGroups(groups, 'пи-25').map((g) => g.code), ['ПИ-25а']);
    expect(filterGroups(groups, 'ИНТЕЛЛЕКТУАЛЬНЫХ').length, 2);
    expect(filterGroups(groups, '  '), groups);
    expect(filterGroups(groups, 'zzz'), isEmpty);
  });

  test('сид содержит не меньше 49 групп с расписанием и пакет ПИ-25а', () {
    final bytes = readSeed();
    final startup = parseStartupSync(bytes, 'ПИ-25а');
    expect(startup.groups.length, greaterThanOrEqualTo(49));
    expect(startup.groups.map((g) => g.code), contains('ПИ-25а'));
    expect(startup.loaded!.pkg.lessons, isNotEmpty);
    expect(parseStartupSync(bytes, null).loaded, isNull);
  });
}

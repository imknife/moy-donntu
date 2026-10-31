import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/deadline.dart';
import '../domain/notes.dart';
import 'material_files.dart';

enum ThemeChoice { system, light, dark }

const defaultQuickServices = ['gradebook', 'rooms', 'teachers'];

@immutable
class Prefs {
  const Prefs({
    this.theme = ThemeChoice.system,
    this.mode = 0,
    this.hidePast = false,
    this.showCancelled = true,
    this.onboarded = false,
    this.startScreen = 'schedule',
    this.autoSync = true,
    this.largeText = false,
    this.savedTeachers = const [],
    this.activeTeacher = '',
    this.quickServices = defaultQuickServices,
    this.displayName = '',
    this.lockscreen = true,
    this.persistent = false,
    this.autostartDone = false,
    this.reminders = false,
    this.changeAlerts = true,
    this.notificationMinutes = 15,
    this.hiddenKinds = const [],
    this.showGaps = true,
    this.readNotices = const [],
  });
  final ThemeChoice theme;
  final int mode;
  final bool hidePast;
  final bool showCancelled;
  final bool onboarded;
  final String startScreen;
  final bool autoSync;
  final bool largeText;
  final List<String> savedTeachers;
  final String activeTeacher;
  final List<String> quickServices;
  final String displayName;
  final bool lockscreen;
  final bool persistent;
  final bool autostartDone;
  final bool reminders;
  final bool changeAlerts;
  final int notificationMinutes;
  final List<String> hiddenKinds;
  final bool showGaps;
  final List<String> readNotices;

  Prefs copyWith({
    ThemeChoice? theme,
    int? mode,
    bool? hidePast,
    bool? showCancelled,
    bool? onboarded,
    String? startScreen,
    bool? autoSync,
    bool? largeText,
    List<String>? savedTeachers,
    String? activeTeacher,
    List<String>? quickServices,
    String? displayName,
    bool? lockscreen,
    bool? persistent,
    bool? autostartDone,
    bool? reminders,
    bool? changeAlerts,
    int? notificationMinutes,
    List<String>? hiddenKinds,
    bool? showGaps,
    List<String>? readNotices,
  }) =>
      Prefs(
        theme: theme ?? this.theme,
        mode: mode ?? this.mode,
        hidePast: hidePast ?? this.hidePast,
        showCancelled: showCancelled ?? this.showCancelled,
        onboarded: onboarded ?? this.onboarded,
        startScreen: startScreen ?? this.startScreen,
        autoSync: autoSync ?? this.autoSync,
        largeText: largeText ?? this.largeText,
        savedTeachers: savedTeachers ?? this.savedTeachers,
        activeTeacher: activeTeacher ?? this.activeTeacher,
        quickServices: quickServices ?? this.quickServices,
        displayName: displayName ?? this.displayName,
        lockscreen: lockscreen ?? this.lockscreen,
        persistent: persistent ?? this.persistent,
        autostartDone: autostartDone ?? this.autostartDone,
        reminders: reminders ?? this.reminders,
        changeAlerts: changeAlerts ?? this.changeAlerts,
        notificationMinutes: notificationMinutes ?? this.notificationMinutes,
        hiddenKinds: hiddenKinds ?? this.hiddenKinds,
        showGaps: showGaps ?? this.showGaps,
        readNotices: readNotices ?? this.readNotices,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'mode': mode,
        'hidePast': hidePast,
        'showCancelled': showCancelled,
        'onboarded': onboarded,
        'startScreen': startScreen,
        'autoSync': autoSync,
        'fontSize': largeText ? 'large' : 'normal',
        'savedTeachers': savedTeachers,
        'activeTeacher': activeTeacher,
        'quickServices': quickServices,
        'lockscreen': lockscreen,
        'persistent': persistent,
        'autostartDone': autostartDone,
        'reminders': reminders,
        'changeAlerts': changeAlerts,
        'notificationMinutes': notificationMinutes,
        'hiddenKinds': hiddenKinds,
        'showGaps': showGaps,
        'readNotices': readNotices,
      };

  factory Prefs.fromJson(Map<String, dynamic> j) => Prefs(
        theme: ThemeChoice.values.firstWhere((t) => t.name == j['theme'], orElse: () => ThemeChoice.system),
        mode: (j['mode'] as int?)?.clamp(0, 2) ?? 0,
        hidePast: j['hidePast'] as bool? ?? false,
        showCancelled: j['showCancelled'] as bool? ?? true,
        onboarded: j['onboarded'] as bool? ?? false,
        startScreen: j['startScreen'] as String? ?? 'schedule',
        autoSync: j['autoSync'] as bool? ?? true,
        largeText: j['fontSize'] == 'large',
        savedTeachers: [for (final s in (j['savedTeachers'] as List? ?? const [])) s as String],
        activeTeacher: j['activeTeacher'] as String? ?? '',
        quickServices: [for (final s in (j['quickServices'] as List? ?? defaultQuickServices)) s as String],
        lockscreen: j['lockscreen'] as bool? ?? true,
        persistent: j['persistent'] as bool? ?? false,
        autostartDone: j['autostartDone'] as bool? ?? false,
        reminders: j['reminders'] as bool? ?? false,
        changeAlerts: j['changeAlerts'] as bool? ?? true,
        notificationMinutes: (j['notificationMinutes'] as num?)?.toInt() ?? 15,
        hiddenKinds: [for (final s in (j['hiddenKinds'] as List? ?? const [])) s as String],
        showGaps: j['showGaps'] as bool? ?? true,
        readNotices: [for (final s in (j['readNotices'] as List? ?? const [])) s as String],
      );

  @override
  bool operator ==(Object other) => other is Prefs && other.displayName == displayName && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => Object.hash(jsonEncode(toJson()), displayName);
}

typedef Selection = ({String group, int subgroup});

class RecentSearch {
  const RecentSearch(this.title, this.page, this.params);
  final String title;
  final String page;
  final Map<String, String> params;

  Map<String, dynamic> toJson() => {'title': title, 'page': page, 'params': params};

  factory RecentSearch.fromJson(Map<String, dynamic> j) =>
      RecentSearch(j['title'] as String, j['page'] as String, (j['params'] as Map? ?? const {}).cast<String, String>());
}

class AppStore {
  AppStore._(this._sp, Selection selection, Prefs prefs, List<Note> notes, List<RecentSearch> recents, List<MaterialFile> materials, List<Deadline> deadlines)
      : selection = ValueNotifier(selection),
        deadlines = ValueNotifier(deadlines),
        materials = ValueNotifier(materials),
        prefs = ValueNotifier(prefs),
        notes = ValueNotifier(notes),
        recents = ValueNotifier(recents);

  final SharedPreferences _sp;
  final ValueNotifier<Selection> selection;
  final ValueNotifier<Prefs> prefs;
  final ValueNotifier<List<Note>> notes;
  final ValueNotifier<List<Deadline>> deadlines;
  final ValueNotifier<List<RecentSearch>> recents;
  final ValueNotifier<List<MaterialFile>> materials;

  static Future<AppStore> open() async => fromPreferences(await SharedPreferences.getInstance());

  static AppStore fromPreferences(SharedPreferences sp) {
    final sel = _read(sp, 'selection');
    final prefs = _read(sp, 'preferences');
    final rawNotes = sp.getString('notes');
    var notes = <Note>[];
    if (rawNotes != null) {
      try {
        notes = [for (final n in jsonDecode(rawNotes) as List) Note.fromJson(n as Map<String, dynamic>)];
      } catch (_) {
        notes = [];
      }
    }
    var deadlines = <Deadline>[];
    final rawDeadlines = sp.getString('deadlines');
    if (rawDeadlines != null) {
      try {
        deadlines = [for (final n in jsonDecode(rawDeadlines) as List) Deadline.fromJson(n as Map<String, dynamic>)];
      } catch (_) {
        deadlines = [];
      }
    }
    var recents = <RecentSearch>[];
    final rawRecents = sp.getString('recent-searches');
    if (rawRecents != null) {
      try {
        recents = [for (final n in jsonDecode(rawRecents) as List) RecentSearch.fromJson(n as Map<String, dynamic>)];
      } catch (_) {
        recents = [];
      }
    }
    var materials = <MaterialFile>[];
    final rawMaterials = sp.getString('materials');
    if (rawMaterials != null) {
      try {
        materials = [for (final n in jsonDecode(rawMaterials) as List) MaterialFile.fromJson(n as Map<String, dynamic>)];
      } catch (_) {
        materials = [];
      }
    }
    final group = sel?['group'] as String? ?? '';
    final name = sp.getString('name') ?? '';
    final base = (prefs == null ? const Prefs() : Prefs.fromJson(prefs)).copyWith(displayName: name);
    final onboarded = prefs?['onboarded'] as bool? ?? group.isNotEmpty;
    return AppStore._(sp, (group: group, subgroup: ((sel?['subgroup'] as int?) ?? 0).clamp(0, 2)), base.copyWith(onboarded: onboarded), notes, recents, materials, deadlines);
  }

  static Map<String, dynamic>? _read(SharedPreferences sp, String key) {
    final raw = sp.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void setGroup(String group, [int? subgroup]) {
    selection.value = (group: group, subgroup: subgroup ?? selection.value.subgroup);
    _sp.setString('selection', jsonEncode({'group': selection.value.group, 'subgroup': selection.value.subgroup}));
  }

  void setSubgroup(int subgroup) => setGroup(selection.value.group, subgroup);

  void setPrefs(Prefs Function(Prefs) change) {
    final before = prefs.value;
    prefs.value = change(before);
    _sp.setString('preferences', jsonEncode(prefs.value.toJson()));
    if (prefs.value.displayName != before.displayName) _sp.setString('name', prefs.value.displayName);
  }

  void saveNote(Note note) {
    notes.value = [note, ...notes.value.where((n) => n.id != note.id)];
    _persistNotes();
  }

  void removeNote(String id) {
    notes.value = notes.value.where((n) => n.id != id).toList();
    _persistNotes();
  }

  void removeNotes(Set<String> ids) {
    notes.value = notes.value.where((n) => !ids.contains(n.id)).toList();
    _persistNotes();
  }

  void _persistNotes() => _sp.setString('notes', jsonEncode([for (final n in notes.value) n.toJson()]));

  void saveDeadline(Deadline item) {
    final index = deadlines.value.indexWhere((d) => d.id == item.id);
    deadlines.value = index < 0 ? [...deadlines.value, item] : [for (final d in deadlines.value) d.id == item.id ? item : d];
    _persistDeadlines();
  }

  void removeDeadline(String id) {
    deadlines.value = deadlines.value.where((d) => d.id != id).toList();
    _persistDeadlines();
  }

  void removeDeadlines(Set<String> ids) {
    deadlines.value = deadlines.value.where((d) => !ids.contains(d.id)).toList();
    _persistDeadlines();
  }

  void _persistDeadlines() => _sp.setString('deadlines', jsonEncode([for (final d in deadlines.value) d.toJson()]));

  void addMaterial(MaterialFile file) {
    materials.value = [...materials.value, file];
    _persistMaterials();
  }

  void removeMaterial(String id) {
    materials.value = materials.value.where((m) => m.id != id).toList();
    _persistMaterials();
  }

  void _persistMaterials() => _sp.setString('materials', jsonEncode([for (final m in materials.value) m.toJson()]));

  void addRecent(RecentSearch entry) {
    recents.value = [entry, ...recents.value.where((r) => r.title != entry.title)].take(6).toList();
    _sp.setString('recent-searches', jsonEncode([for (final r in recents.value) r.toJson()]));
  }
}

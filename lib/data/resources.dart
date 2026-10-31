import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'offline.dart';
import 'records.dart';
import 'seed_store.dart';

class ResourceSpec<T> {
  const ResourceSpec(this.path, this.parse, {this.keepPrevious});
  final String path;
  final T Function(Object? json) parse;
  final bool Function(T previous, T fresh)? keepPrevious;
}

@immutable
class ResourceState<T> {
  const ResourceState({this.data, this.loading = false, this.error, this.offline = false});
  final T? data;
  final bool loading;
  final Object? error;
  final bool offline;

  bool get hasData => data != null;
}

class Resource<T> extends ValueNotifier<ResourceState<T>> {
  Resource(this._hub, this.spec, this.key) : super(const ResourceState());
  final ResourceHub _hub;
  final ResourceSpec<T> spec;
  final String key;
  Future<void>? _running;

  Future<void> refresh() => _running ??= Future<void>.microtask(() => _hub._run(this)).whenComplete(() => _running = null);
}

class ResourceHub {
  ResourceHub({required this.api, required this.records, required this.seed});
  final ApiClient api;
  final Records records;
  final SeedStore seed;
  final Map<String, Resource<Object?>> _resources = {};

  String keyOf(ResourceSpec<Object?> spec) => 'public:${spec.path}';

  Resource<T> watch<T>(ResourceSpec<T> spec, {bool refresh = true}) {
    final key = keyOf(spec);
    final existing = _resources[key];
    if (existing != null) {
      if (refresh && !existing.value.loading && existing.value.hasData == false) unawaited(existing.refresh());
      return existing as Resource<T>;
    }
    final created = Resource<T>(this, spec, key);
    _resources[key] = created as Resource<Object?>;
    if (refresh) unawaited(created.refresh());
    return created;
  }

  Future<T> fetch<T>(ResourceSpec<T> spec) async {
    final r = watch(spec, refresh: false);
    await r.refresh();
    final state = r.value;
    if (state.data != null) return state.data as T;
    throw state.error ?? const NoConnection();
  }

  Future<T?> local<T>(ResourceSpec<T> spec) => _local(spec, keyOf(spec));

  Future<T?> _local<T>(ResourceSpec<T> spec, String key) async {
    final saved = await records.get(key);
    if (saved != null) {
      try {
        return await _parse(spec, saved);
      } catch (_) {
        await records.remove(key);
      }
    }
    final fromSeed = await seed.raw(key);
    if (fromSeed == null) return null;
    try {
      return await _parse(spec, fromSeed);
    } catch (_) {
      return null;
    }
  }

  Future<T> _parse<T>(ResourceSpec<T> spec, String text) {
    final parse = spec.parse;
    if (text.length < 24000) return Future.value(parse(jsonDecode(text)));
    return Isolate.run(() => parse(jsonDecode(text)));
  }

  Future<void> _run<T>(Resource<T> r) async {
    final spec = r.spec;
    final key = r.key;
    r.value = ResourceState(data: r.value.data, loading: true, offline: r.value.offline);
    if (r.value.data == null) {
      final local = await _local(spec, key) ?? await _fromPackages(spec);
      if (local != null) r.value = ResourceState(data: local, loading: api.enabled);
    }
    Object? error;
    if (api.enabled) {
      try {
        final text = await api.send(spec.path);
        final data = await _parse(spec, text);
        final previous = r.value.data;
        if (previous != null && (spec.keepPrevious?.call(previous, data) ?? false)) {
          r.value = ResourceState(data: previous);
          return;
        }
        await records.set(key, text);
        r.value = ResourceState(data: data);
        return;
      } catch (e) {
        error = e;
      }
    }
    if (r.value.data != null) {
      r.value = ResourceState(data: r.value.data, offline: api.enabled);
      return;
    }
    r.value = ResourceState(error: error ?? const NoConnection('Нет сохранённых данных'));
  }

  Future<T?> _fromPackages<T>(ResourceSpec<T> spec) async {
    final answer = await offlineAnswer(spec.path, await _packageTexts());
    return answer as T?;
  }

  Future<List<String>> _packageTexts() async {
    final texts = await seed.packageTexts();
    final groups = jsonDecode((await seed.raw('public:/groups')) ?? '{"groups":[]}') as Map<String, dynamic>;
    final out = <String>[];
    var i = 0;
    for (final g in groups['groups'] as List) {
      final key = 'public:/groups/${Uri.encodeComponent(g['code'] as String)}/package';
      final inSeed = (await seed.raw(key)) != null;
      final cached = await records.get(key);
      if (cached != null) {
        out.add(cached);
      } else if (inSeed) {
        out.add(texts[i]);
      }
      if (inSeed) i++;
    }
    return out;
  }
}

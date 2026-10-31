import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/api.dart';
import 'data/app_controller.dart';
import 'data/config.dart';
import 'data/loader.dart';
import 'data/native_bridge.dart';
import 'data/records.dart';
import 'data/secret_store.dart';
import 'data/store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Boot());
}

Future<AppController> bootstrap() async {
  final results = await Future.wait([AppStore.open(), readSeedBytes(), getApplicationSupportDirectory()]);
  final store = results[0] as AppStore;
  final bytes = results[1] as SeedBytes;
  final dir = results[2] as Directory;
  final startup = await parseStartup(bytes, store.selection.value.group);
  return AppController(
    store: store,
    bytes: bytes,
    groups: startup.groups,
    loaded: startup.loaded,
    records: FileRecords(Directory('${dir.path}${Platform.pathSeparator}cache')),
    api: ApiClient(AppConfig.apiUrl),
    secrets: PlatformSecretStore(),
    native: MethodChannelBridge(),
  );
}

class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  AppController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    bootstrap().then((c) {
      if (!mounted) return;
      setState(() => _controller = c);
      Future<void>.delayed(const Duration(seconds: 2), c.warmDirectories);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) return App(controller: controller);
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF151E27) : Colors.white,
      child: _error == null
          ? const SizedBox.expand()
          : Directionality(
              textDirection: TextDirection.ltr,
              child: Center(child: Text('Не удалось загрузить данные: $_error', style: TextStyle(color: dark ? Colors.white : Colors.black))),
            ),
    );
  }
}

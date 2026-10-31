import 'dart:io';

import 'package:flutter_lab/ui/settings_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('версия в приложении совпадает с версией в pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$').firstMatch(line);
    expect(match, isNotNull);
    expect(appVersion, match!.group(1));
  });
}

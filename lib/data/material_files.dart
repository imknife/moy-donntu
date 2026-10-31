import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MaterialFile {
  const MaterialFile({required this.id, required this.name, required this.path, this.size, this.lessonKey});
  final String id;
  final String name;
  final String path;
  final int? size;
  final String? lessonKey;

  factory MaterialFile.fromJson(Map<String, dynamic> j) => MaterialFile(
        id: j['id'] as String,
        name: j['name'] as String,
        path: (j['path'] ?? j['uri']) as String,
        size: (j['size'] as num?)?.toInt(),
        lessonKey: j['lessonKey'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'path': path, if (size != null) 'size': size, if (lessonKey != null) 'lessonKey': lessonKey};
}

abstract class MaterialFiles {
  Future<({String name, String path, int? size})?> pick();
  Future<void> open(String path, String name);
  Future<void> delete(String path);
}

class PlatformMaterialFiles implements MaterialFiles {
  @override
  Future<({String name, String path, int? size})?> pick() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}materials');
    await dir.create(recursive: true);
    final target = File('${dir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}-${file.name}');
    final source = file.path;
    if (source != null) {
      await File(source).copy(target.path);
    } else {
      await target.writeAsBytes(await file.readAsBytes());
    }
    return (name: file.name, path: target.path, size: await file.length());
  }

  @override
  Future<void> open(String path, String name) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(path, name: name)]));
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

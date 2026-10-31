import 'package:flutter/material.dart';

import '../data/material_files.dart';
import 'common.dart';
import 'derived.dart';
import 'icons.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';

String sizeText(MaterialFile m) => m.size != null ? '${(m.size! / 1024).ceil().clamp(1, 1 << 30)} КБ' : 'Локальный файл';

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key, this.lessonKey, this.subject});
  final String? lessonKey;
  final String? subject;

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  bool _busy = false;
  Object? _error;

  Future<void> _add() async {
    final app = context.app;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await app.files.pick();
      if (picked != null) {
        app.store.addMaterial(MaterialFile(id: '${DateTime.now().microsecondsSinceEpoch}', name: picked.name, path: picked.path, size: picked.size, lessonKey: widget.lessonKey));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(MaterialFile m) async {
    if (!await confirm(context, title: 'Удалить файл?')) return;
    if (!mounted) return;
    final app = context.app;
    await app.files.delete(m.path);
    app.store.removeMaterial(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = context.app;
    return PageScaffold(
      title: 'Мои файлы',
      children: [
        Text(widget.subject != null ? 'Мои файлы · ${widget.subject}' : 'Файлы хранятся только на этом телефоне', style: T.body.copyWith(color: c.muted)),
        const VGap(8),
        PrimaryButton(label: 'Добавить файл', enabled: !_busy, onTap: _add),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: ErrorBox(error: _error!)),
        const VGap(8),
        ValueListenableBuilder<List<MaterialFile>>(
          valueListenable: app.store.materials,
          builder: (context, all, _) {
            final visible = widget.lessonKey != null ? [for (final m in all) if (m.lessonKey == widget.lessonKey) m] : all;
            if (visible.isEmpty) {
              return EmptyBox(icon: 'file', title: widget.lessonKey != null ? 'К этому занятию ещё нет ваших файлов' : 'Добавьте конспект, презентацию или практикум');
            }
            return RowsCard(children: [
              for (final m in visible)
                MenuRow(
                  icon: 'file',
                  title: m.name,
                  detail: sizeText(m),
                  onTap: () async {
                    try {
                      await app.files.open(m.path, m.name);
                    } catch (e) {
                      if (context.mounted) setState(() => _error = e);
                    }
                  },
                  trailing: Tap(label: 'Удалить файл ${m.name}', onTap: () => _remove(m), child: SizedBox(width: 44, height: 44, child: Center(child: AppIcon('trash', size: 20, color: c.text)))),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

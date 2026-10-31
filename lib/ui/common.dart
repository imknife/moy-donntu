import 'package:flutter/material.dart';

import '../data/ace_client.dart';
import '../data/api.dart';
import '../data/resources.dart';
import 'derived.dart';
import 'icons.dart';
import 'theme.dart';
import 'type_settings.dart';
import 'widgets.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.title, required this.children, this.actions = const [], this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24), this.overlay, this.onRefresh});
  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final EdgeInsets padding;
  final Widget? overlay;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    Widget list = ListView(padding: padding, children: children);
    if (onRefresh != null) list = RefreshIndicator(onRefresh: onRefresh!, color: c.link, backgroundColor: c.surface, child: list);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                BackBar(title: title, actions: actions),
                Expanded(child: list),
              ],
            ),
            ?overlay,
          ],
        ),
      ),
    );
  }
}

class VGap extends StatelessWidget {
  const VGap(this.h, {super.key});
  final double h;

  @override
  Widget build(BuildContext context) => SizedBox(height: h);
}

class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.controller, required this.hint, this.autofocus = false});
  final TextEditingController controller;
  final String hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: T.body.copyWith(color: c.text),
      cursorColor: c.link,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: T.body.copyWith(color: c.muted),
        prefixIcon: Padding(padding: const EdgeInsets.all(12), child: AppIcon('search', size: 20, color: c.muted)),
        filled: true,
        fillColor: c.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final String value;
  final void Function(String value) onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = options[i] == value;
          return Tap(
            label: options[i],
            onTap: () => onChanged(options[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: selected ? c.segmentOn : c.surface, borderRadius: BorderRadius.circular(12)),
              child: Text(options[i].cased, style: T.caption.copyWith(color: selected ? c.segmentOnText : c.text)),
            ),
          );
        },
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, this.icon, required this.onTap, this.selected = false});
  final String label;
  final String? icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: label,
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: selected ? c.segmentOn : c.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[AppIcon(icon!, size: 16, color: selected ? c.segmentOnText : c.text), const SizedBox(width: 6)],
            Text(label.cased, style: T.caption.copyWith(color: selected ? c.segmentOnText : c.text)),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onTap, this.secondary = false, this.enabled = true, this.danger = false});
  final String label;
  final VoidCallback? onTap;
  final bool secondary;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final active = enabled && onTap != null;
    final bg = secondary ? Colors.transparent : (danger ? c.danger : c.segmentOn);
    final fg = secondary ? c.link : (danger ? c.onLink : c.segmentOnText);
    final box = Container(
      height: 48,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: active ? bg : (secondary ? Colors.transparent : c.track), borderRadius: BorderRadius.circular(12)),
      child: Text(label.cased, style: T.subject.copyWith(color: active ? fg : c.muted)),
    );
    return active ? Tap(label: label, onTap: onTap!, child: box) : box;
  }
}

class EmptyBox extends StatelessWidget {
  const EmptyBox({super.key, this.icon = 'sun', required this.title, this.text, this.actionLabel, this.onAction});
  final String? icon;
  final String title;
  final String? text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          if (icon != null) ...[AppIcon(icon!, size: 36, color: c.muted), const SizedBox(height: 10)],
          Text(title.cased, textAlign: TextAlign.center, style: T.heading.copyWith(color: c.text)),
          if (text != null) ...[const SizedBox(height: 6), Text(text!.cased, textAlign: TextAlign.center, style: T.body.copyWith(color: c.muted))],
          if (actionLabel != null && onAction != null) ...[const SizedBox(height: 16), PrimaryButton(label: actionLabel!, onTap: onAction)],
        ],
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 64});
  final double height;

  @override
  Widget build(BuildContext context) => Container(height: height, decoration: BoxDecoration(color: context.pal.track, borderRadius: BorderRadius.circular(16)));
}

class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final text = error is HttpError || error is NoConnection || error is AceError ? error.toString() : 'Не удалось загрузить данные';
    return SurfaceCard(
      color: c.changes,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: T.body.copyWith(color: c.danger)),
          if (onRetry != null) Tap(onTap: onRetry!, child: Padding(padding: const EdgeInsets.only(top: 10), child: Text('Повторить'.cased, style: T.bodyLink.copyWith(color: c.link)))),
        ],
      ),
    );
  }
}

class ResourceView<D> extends StatefulWidget {
  const ResourceView({super.key, required this.resource, required this.builder, this.keepPrevious = false});
  final Resource<D> resource;
  final Widget Function(BuildContext context, D data) builder;
  final bool keepPrevious;

  @override
  State<ResourceView<D>> createState() => _ResourceViewState<D>();
}

class _ResourceViewState<D> extends State<ResourceView<D>> {
  D? _last;

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final builder = widget.builder;
    return ValueListenableBuilder<ResourceState<D>>(
      valueListenable: resource,
      builder: (context, state, _) {
        final data = state.data;
        if (data != null) {
          _last = data;
          return builder(context, data);
        }
        final previous = _last;
        if (widget.keepPrevious && previous != null && state.error == null) return builder(context, previous);
        if (state.error != null && !state.loading) return ErrorBox(error: state.error!, onRetry: () => resource.refresh());
        return Column(children: [for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonBox())]);
      },
    );
  }
}

void showToast(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  final c = context.pal;
  messenger?.showSnackBar(SnackBar(
    content: Text(text, style: T.caption.copyWith(color: c.onLink)),
    backgroundColor: c.text,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  ));
}

Future<bool> confirm(BuildContext context, {required String title, String? text, String ok = 'Удалить'}) async {
  final c = context.pal;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      title: Text(title, style: T.heading.copyWith(color: c.text)),
      content: text == null ? null : Text(text, style: T.body.copyWith(color: c.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена'.cased, style: T.captionSemi.copyWith(color: c.link))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok, style: T.captionSemi.copyWith(color: c.danger))),
      ],
    ),
  );
  return result ?? false;
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 40});
  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: AppIcon(icon, size: size / 2, color: c.text),
    );
  }
}

class SectionHead extends StatelessWidget {
  const SectionHead({super.key, required this.title, this.link, this.onTap});
  final String title;
  final String? link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.cased, style: T.heading.copyWith(color: c.text)),
          if (link != null) Tap(onTap: onTap ?? () {}, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(link!.cased, style: T.caption.copyWith(color: c.link)))),
        ],
      ),
    );
  }
}

class RowsCard extends StatelessWidget {
  const RowsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SurfaceCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children));
}

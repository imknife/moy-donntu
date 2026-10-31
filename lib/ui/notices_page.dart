import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../domain/models.dart';
import '../domain/notices.dart';
import 'common.dart';
import 'icons.dart';
import 'scope.dart';
import 'settings_group.dart';
import 'theme.dart';
import 'derived.dart';

Listenable noticeSources(AppController app) => Listenable.merge([app.model, app.store.deadlines, app.auth.feed, app.session, app.clock, app.store.prefs]);

List<Notice> noticesOf(AppController app) {
  final changes = app.model.value?.pkg.lastChange?.changes ?? const <LessonChange>[];
  final feed = app.session.value == null ? null : app.auth.feed.value.data;
  return buildNotices(
    changes: changes,
    deadlines: app.store.deadlines.value,
    today: app.clock.value.today,
    minute: app.clock.value.minute,
    feedAbsences: feed?.absences ?? 0,
    feedUnread: feed?.unread ?? 0,
  );
}

int unreadNotices(AppController app) {
  final read = app.store.prefs.value.readNotices.toSet();
  return noticesOf(app).where((n) => !read.contains(n.id)).length;
}

void markNoticesRead(AppController app, Iterable<String> ids) {
  final live = noticesOf(app).map((n) => n.id).toSet();
  app.store.setPrefs((p) => p.copyWith(readNotices: [...{for (final id in p.readNotices) if (live.contains(id)) id, ...ids}]));
}

class NoticeBell extends StatelessWidget {
  const NoticeBell({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = context.app;
    return ListenableBuilder(
      listenable: noticeSources(app),
      builder: (context, _) {
        final unread = unreadNotices(app);
        return Tap(
          label: unread > 0 ? 'Уведомления, непрочитанных: $unread' : 'Уведомления',
          onTap: () => context.open('notifications'),
          child: SizedBox(
            width: 44,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AppIcon('bell', size: 22, color: c.text),
                if (unread > 0)
                  Positioned(
                    right: 10,
                    top: 6,
                    child: Container(width: 10, height: 10, decoration: BoxDecoration(color: c.link, shape: BoxShape.circle, border: Border.all(color: c.background, width: 1.5))),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = context.app;
    return ListenableBuilder(
      listenable: noticeSources(app),
      builder: (context, _) {
        final notices = noticesOf(app);
        final read = app.store.prefs.value.readNotices.toSet();
        final unread = notices.where((n) => !read.contains(n.id)).length;
        return GroupedPage(
          title: 'Уведомления',
          actions: [
            if (unread > 0)
              Tap(
                label: 'Прочитать все',
                onTap: () => markNoticesRead(app, notices.map((n) => n.id)),
                child: SizedBox(height: 56, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Center(child: Text('Прочитать все', style: T.captionSemi.copyWith(color: c.link))))),
              ),
          ],
          children: [
            if (notices.isEmpty)
              const EmptyBox(icon: 'bell', title: 'Нет уведомлений')
            else
              SettingsGroup(children: [
                for (final n in notices)
                  _NoticeRow(
                    notice: n,
                    read: read.contains(n.id),
                    onTap: () {
                      markNoticesRead(app, [n.id]);
                      context.open(n.route);
                    },
                  ),
              ]),
          ],
        );
      },
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice, required this.read, required this.onTap});
  final Notice notice;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: '${notice.title}, ${notice.text}',
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              SizedBox(width: 14, child: read ? null : Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.link, shape: BoxShape.circle)))),
              const SizedBox(width: 4),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: AppIcon(notice.icon, size: 18, color: read ? c.muted : c.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notice.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(color: read ? c.muted : c.text)),
                    Text(notice.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.micro.copyWith(color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppIcon('chevron', size: 18, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

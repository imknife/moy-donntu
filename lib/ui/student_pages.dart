import 'package:flutter/material.dart';

import '../data/auth.dart';
import '../data/resources.dart';
import '../domain/ace.dart';
import '../domain/cabinet_feed.dart';
import '../domain/grades.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'derived.dart';
import 'icons.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

class AceView<D> extends StatefulWidget {
  const AceView({super.key, required this.resource, required this.builder, required this.signInTitle, required this.signInText});
  final AceResource<D> resource;
  final Widget Function(BuildContext context, D data) builder;
  final String signInTitle;
  final String signInText;

  @override
  State<AceView<D>> createState() => _AceViewState<D>();
}

class _AceViewState<D> extends State<AceView<D>> {
  @override
  void initState() {
    super.initState();
    widget.resource.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.resource, context.app.session]),
      builder: (context, _) {
        final ResourceState<D> state = widget.resource.value;
        if (context.app.session.value == null || state.error is AceSignInRequired) {
          return EmptyBox(icon: null, title: widget.signInTitle, text: widget.signInText, actionLabel: 'Войти', onAction: () => context.open('login'));
        }
        final data = state.data;
        if (data != null) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (state.offline) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Без сети · сохранённые данные'.cased, style: T.caption.copyWith(color: c.muted))),
            widget.builder(context, data),
          ]);
        }
        if (state.error != null && !state.loading) return ErrorBox(error: state.error!, onRetry: widget.resource.refresh);
        return const Column(children: [Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonBox(height: 120)), SkeletonBox()]);
      },
    );
  }
}

class StudentCardPage extends StatelessWidget {
  const StudentCardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.app.auth;
    return PageScaffold(
      title: 'Студенческий билет',
      onRefresh: auth.student.refresh,
      children: [
        AceView<StudentCard>(
          resource: auth.student,
          signInTitle: 'Студенческий билет',
          signInText: 'Войдите через университетскую учётную запись, чтобы загрузить ваш документ.',
          builder: (context, card) => Column(children: [
            StudentDocument(card: card),
            const VGap(8),
            PrimaryButton(label: 'Обновить билет', secondary: true, onTap: auth.student.refresh),
          ]),
        ),
      ],
    );
  }
}

class StudentDocument extends StatelessWidget {
  const StudentDocument({super.key, required this.card});
  final StudentCard card;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final dark = c.surface.computeLuminance() < 0.5;
    final onCard = dark ? c.text : Colors.white;
    final onCardMuted = dark ? c.muted : const Color(0xCCFFFFFF);
    final fields = <(String, String?)>[
      ('Дата выдачи', card.issued),
      ('Приказ о зачислении', card.order),
      ('Уровень образования', card.level),
      ('Профиль', card.profile),
      ('Группа', card.group),
    ].where((f) => f.$2 != null && f.$2!.isNotEmpty).toList();
    final face = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: dark ? const [Color(0xFF24507A), Color(0xFF14283C)] : const [Color(0xFF1B8AD6), Color(0xFF005A93)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Студенческий билет'.cased, style: T.captionSemi.copyWith(color: onCardMuted)), AppIcon('card', size: 22, color: onCardMuted)]),
          if (card.university != null && card.university!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(card.university!, style: T.caption.copyWith(color: onCardMuted))),
          const VGap(14),
          Text(card.fullName.isEmpty ? 'Имя не указано' : card.fullName, style: T.display.copyWith(color: onCard, fontSize: 28, height: 1.2)),
          if (card.number != null && card.number!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(card.number!, style: T.heading.copyWith(color: onCard, fontSize: 20))),
          if (card.direction != null && card.direction!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(card.direction!, style: T.body.copyWith(color: onCard))),
          Padding(padding: const EdgeInsets.only(top: 8), child: Text([if (card.course != null) '${card.course} курс', if (card.form != null) card.form!].join(' · '), style: T.body.copyWith(color: onCardMuted))),
        ],
      ),
    );
    return SurfaceCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          face,
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.hairline, indent: 8, endIndent: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fields[i].$1, style: T.micro.copyWith(color: c.muted)), Text(fields[i].$2!, style: T.body.copyWith(color: c.text))]),
            ),
          ],
        ],
      ),
    );
  }
}

class GradeSquare extends StatelessWidget {
  const GradeSquare({super.key, required this.row, this.size = 40});
  final ZachRow row;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final badge = gradeBadge(row);
    final (bg, fg) = switch (badge.tone) {
      GradeTone.good || GradeTone.credit => (c.tint, c.link),
      GradeTone.ok => (c.soft, c.text),
      GradeTone.bad => (c.changes, c.danger),
      GradeTone.none => (c.soft, c.muted),
    };
    return Semantics(
      label: badge.word,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
        alignment: Alignment.center,
        child: badge.value == '✓' ? AppIcon('check', size: size * 0.5, color: fg) : Text(badge.value, style: T.heading.copyWith(color: fg, fontSize: size * 0.5, height: 1.2, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class GradeRowTile extends StatelessWidget {
  const GradeRowTile({super.key, required this.row, this.extras = const [], this.showSem = false, required this.onTap});
  final ZachRow row;
  final List<ZachRow> extras;
  final bool showSem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final badge = gradeBadge(row);
    return Tap(
      label: '${row.dis}, ${badge.word}. Открыть подробности',
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(row.dis, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(color: c.text, fontWeight: FontWeight.w600)),
                Text(gradeMeta(row, showSem: showSem, extras: extras), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.micro.copyWith(color: c.muted)),
              ]),
            ),
            const SizedBox(width: 12),
            GradeSquare(row: row),
          ]),
        ),
      ),
    );
  }
}

class GradebookPage extends StatefulWidget {
  const GradebookPage({super.key});

  @override
  State<GradebookPage> createState() => _GradebookPageState();
}

class _GradebookPageState extends State<GradebookPage> {
  bool _all = false;
  int _kind = 0;
  int? _semester;

  @override
  Widget build(BuildContext context) {
    final auth = context.app.auth;
    return PageScaffold(
      title: 'Зачётная книжка',
      onRefresh: auth.book.refresh,
      children: [
        AceView<ZachBook>(
          resource: auth.book,
          signInTitle: 'Ваши результаты учёбы',
          signInText: 'Зачётная книжка доступна после входа в кабинет студента.',
          builder: (context, book) => _content(context, book),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, ZachBook book) {
    final c = context.pal;
    final sems = {for (final r in book.rows) r.sem}.toList()..sort();
    final sem = _semester ?? (book.currentSem != null && sems.contains(book.currentSem) ? book.currentSem : (sems.isNotEmpty ? sems.last : null));
    bool inScope(ZachRow r) => _all || sem == null || r.sem == sem;
    bool inKind(ZachRow r) => _kind == 1 ? isCreditRow(r) : !isCreditRow(r);
    final rows = [for (final r in book.rows) if (inScope(r) && inKind(r)) r];
    final otherKind = _kind == 1 ? 'Оценки' : 'Зачёты';
    final elsewhere = rows.isEmpty ? book.rows.where((r) => inScope(r) && !inKind(r)).length : 0;
    final stats = semesterStats(book);
    final marks = book.rows.where(hasGrade).length;
    final credits = book.rows.where(isCreditRow).length;
    void pick(int s) => setState(() {
          _semester = s;
          _all = false;
        });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SurfaceCard(
        color: c.tint,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Средний балл'.cased, style: T.caption.copyWith(color: c.muted)), Text(decimalComma(book.avgPoint), style: T.display.copyWith(color: c.text))]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$marks ${plural(marks, 'оценка', 'оценки', 'оценок')}'.cased, style: T.subject.copyWith(color: c.text, fontWeight: FontWeight.w600)),
              Text('$credits ${plural(credits, 'зачёт', 'зачёта', 'зачётов')}'.cased, style: T.caption.copyWith(color: c.muted)),
            ]),
          ]),
          if (stats.any((s) => s.avg != null)) ...[
            const VGap(16),
            SizedBox(
              height: 76 * (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(1.0, 2.0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final s in stats)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Tap(
                        label: '${s.sem} семестр, средний балл ${decimalComma(s.avg)}',
                        onTap: () => pick(s.sem),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 48),
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Text(s.avg == null ? '–' : decimalComma(s.avg, 1), style: T.micro.copyWith(color: !_all && s.sem == sem ? c.link : c.muted, fontSize: 11)),
                            const SizedBox(height: 3),
                            Container(height: s.avg == null ? 6 : 10 + ((s.avg! - 2) / 3 * 34).round().toDouble(), decoration: BoxDecoration(color: !_all && s.sem == sem ? c.link : c.muted, borderRadius: BorderRadius.circular(6))),
                            const SizedBox(height: 3),
                            Text('${s.sem}', style: T.micro.copyWith(color: !_all && s.sem == sem ? c.link : c.muted, fontSize: 11)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ],
        ]),
      ),
      const VGap(8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in sems) PillButton(label: '$s сем.', selected: !_all && sem == s, onTap: () => pick(s)),
        PillButton(label: 'Все', selected: _all, onTap: () => setState(() => _all = true)),
      ]),
      const VGap(8),
      SegmentedPill(options: const ['Оценки', 'Зачёты'], value: _kind, onChanged: (i) => setState(() => _kind = i), height: 34),
      const VGap(8),
      if (rows.isEmpty)
        EmptyBox(
          icon: 'knowledge',
          title: 'Записей пока нет',
          text: elsewhere > 0 ? 'В этом семестре есть ${otherKind == 'Зачёты' ? 'зачёты' : 'оценки'}: откройте вкладку «$otherKind».' : 'В этом разделе ещё нет результатов.',
          actionLabel: elsewhere > 0 ? 'Открыть «$otherKind»' : 'Обновить',
          onAction: elsewhere > 0 ? () => setState(() => _kind = _kind == 1 ? 0 : 1) : context.app.auth.book.refresh,
        )
      else
        RowsCard(children: [
          for (final (r, extras) in groupCourseWork(rows))
            GradeRowTile(row: r, extras: extras, showSem: _all, onTap: () => context.open('grade', _all ? {'dis': r.dis} : {'dis': r.dis, 'sem': '${r.sem}'})),
        ]),
    ]);
  }
}

class GradeDetailPage extends StatelessWidget {
  const GradeDetailPage({super.key, required this.dis, this.sem});
  final String dis;
  final int? sem;

  @override
  Widget build(BuildContext context) {
    final auth = context.app.auth;
    return PageScaffold(
      title: dis.isEmpty ? 'Дисциплина' : dis,
      onRefresh: auth.book.refresh,
      children: [
        AceView<ZachBook>(
          resource: auth.book,
          signInTitle: 'Нужен вход',
          signInText: 'Результаты доступны после входа в кабинет студента.',
          builder: (context, book) => _detail(context, book),
        ),
      ],
    );
  }

  Widget _detail(BuildContext context, ZachBook book) {
    final c = context.pal;
    final rows = rowsOfDiscipline(book, dis, sem);
    final others = sem == null ? <ZachRow>[] : rowsOfDiscipline(book, dis).where((r) => r.sem != sem).toList();
    Widget field(String label, String value) => Padding(padding: const EdgeInsets.only(top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: T.micro.copyWith(color: c.muted)), Text(value, style: T.body.copyWith(color: c.text))]));
    if (rows.isEmpty) {
      return EmptyBox(icon: 'knowledge', title: 'Записей не нашлось', text: 'Дисциплины нет в загруженной зачётной книжке. Обновите её.', actionLabel: 'Обновить', onAction: context.app.auth.book.refresh);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GradeSquare(row: r, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(gradeBadge(r).word, style: T.heading.copyWith(color: gradeBadge(r).tone == GradeTone.bad ? c.danger : c.link, fontSize: 17)),
                    Text('${r.controlForm.isEmpty ? 'Контроль' : r.controlForm} · ${r.sem} семестр${r.course != null ? ' · ${r.course} курс' : ''}'.cased, style: T.caption.copyWith(color: c.muted)),
                  ]),
                ),
              ]),
              if (r.teacherName != null && r.teacherName!.isNotEmpty) field('Преподаватель', r.teacherName!),
              if (r.dateExam != null && r.dateExam!.isNotEmpty) field('Дата', examDate(r.dateExam)),
              if ((r.hours ?? 0) > 0 || (r.zet ?? 0) > 0) field('Объём', [if ((r.hours ?? 0) > 0) '${num2(r.hours!)} ч', if ((r.zet ?? 0) > 0) '${num2(r.zet!)} з.е.'].join(' · ')),
              if (r.year != null && r.year!.isNotEmpty) field('Учебный год', r.year!),
            ]),
          ),
        ),
      if (others.isNotEmpty) ...[
        const SectionLabel('Другие семестры'),
        RowsCard(children: [
          for (final r in others)
            MenuRow(icon: 'gradebook', title: '${r.sem} семестр', detail: '${r.controlForm.isEmpty ? 'Контроль' : r.controlForm} · ${gradeBadge(r).word}', onTap: () => context.open('grade', {'dis': r.dis, 'sem': '${r.sem}'})),
        ]),
      ],
    ]);
  }
}

class CabinetPage extends StatefulWidget {
  const CabinetPage({super.key});

  @override
  State<CabinetPage> createState() => _CabinetPageState();
}

class _CabinetPageState extends State<CabinetPage> {
  String _filter = feedFilters.first;

  @override
  Widget build(BuildContext context) {
    final auth = context.app.auth;
    return PageScaffold(
      title: 'Уведомления кабинета',
      onRefresh: auth.feed.refresh,
      children: [
        AceView<AceFeed>(
          resource: auth.feed,
          signInTitle: 'Уведомления кабинета',
          signInText: 'Пропуски, оценки и приказы появятся после входа в кабинет студента.',
          builder: (context, feed) => _content(context, feed),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, AceFeed feed) {
    final c = context.pal;
    final items = filterFeed(feed.items, _filter);
    Widget stat(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: T.micro.copyWith(color: c.muted)), Text(value, style: T.heading.copyWith(color: c.text, fontSize: 20))]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SurfaceCard(color: c.tint, padding: const EdgeInsets.all(4), child: Row(children: [stat('Пропусков', '${feed.absences}'), stat('Новых', '${feed.unread}'), stat('Всего', '${feed.items.length}')])),
      const VGap(8),
      ChipRow(options: feedFilters, value: _filter, onChanged: (v) => setState(() => _filter = v)),
      const VGap(8),
      if (items.isEmpty)
        const EmptyBox(icon: 'knowledge', title: 'Здесь пусто', text: 'В этом разделе пока нет уведомлений.')
      else
        RowsCard(children: [for (final item in items) _FeedRow(item: item)]),
      const VGap(8),
      PrimaryButton(label: 'Обновить', secondary: true, onTap: context.app.auth.feed.refresh),
    ]);
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item});
  final AceFeedItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final absence = absenceOf(item);
    final lines = item.text.split('\n');
    final title = absence != null ? absence.dis : lines.first;
    final detail = absence != null ? 'Пропуск · ${absence.date ?? ''}' : [item.category, item.date].where((e) => e != null && e.isNotEmpty).join(' · ');
    final rest = lines.skip(1).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (item.isNew) Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: c.link, shape: BoxShape.circle)),
          Expanded(child: Text(title, style: T.subject.copyWith(color: c.text))),
        ]),
        Text(detail, style: T.caption.copyWith(color: c.muted)),
        if (absence == null && rest.isNotEmpty) Text(rest, style: T.caption.copyWith(color: c.muted)),
      ]),
    );
  }
}

class LogoutPage extends StatefulWidget {
  const LogoutPage({super.key});

  @override
  State<LogoutPage> createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> {
  bool _busy = false;
  bool _done = false;
  Object? _error;

  Future<void> _logout() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.app.auth.logout();
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return PageScaffold(
      title: 'Выход из аккаунта',
      children: [
        SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Токены, студенческий билет и зачётная книжка будут удалены с устройства. Личные заметки и настройки сохранятся.'.cased, style: T.body.copyWith(color: c.text)),
            const VGap(12),
            PrimaryButton(label: _done ? 'Вы вышли из аккаунта' : (_busy ? 'Удаляем данные…' : 'Выйти'), enabled: !_busy && !_done, danger: true, onTap: _logout),
          ]),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: ErrorBox(error: _error!)),
      ],
    );
  }
}

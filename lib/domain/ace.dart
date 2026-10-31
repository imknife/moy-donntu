int? _int(Object? v) {
  if (v == null || v == '') return null;
  return num.tryParse('$v')?.toInt();
}

String? _text(Object? v) => v == null ? null : '$v';

num? _num(Object? v) {
  if (v == null || v == '') return null;
  return v is num ? v : num.tryParse('$v');
}

class ZachRow {
  const ZachRow({
    required this.dis,
    required this.controlForm,
    required this.mark,
    required this.markNumber,
    required this.sem,
    required this.course,
    required this.hours,
    required this.zet,
    required this.teacherName,
    required this.dateExam,
    required this.year,
  });
  final String dis;
  final String controlForm;
  final String mark;
  final int? markNumber;
  final int sem;
  final int? course;
  final num? hours;
  final num? zet;
  final String? teacherName;
  final String? dateExam;
  final String? year;

  factory ZachRow.fromJson(Map<String, dynamic> j) => ZachRow(
        dis: _text(j['dis']) ?? '',
        controlForm: _text(j['controlForm']) ?? '',
        mark: _text(j['mark']) ?? '',
        markNumber: _int(j['markNumber']),
        sem: _int(j['sem']) ?? 0,
        course: _int(j['course']),
        hours: _num(j['hours']),
        zet: _num(j['zet']),
        teacherName: _text(j['teacherName']),
        dateExam: _text(j['dateExam'] ?? j['date']),
        year: _text(j['year']),
      );

  Map<String, dynamic> toJson() => {
        'dis': dis,
        'controlForm': controlForm,
        'mark': mark,
        'markNumber': markNumber,
        'sem': sem,
        'course': course,
        'hours': hours,
        'zet': zet,
        'teacherName': teacherName,
        'dateExam': dateExam,
        'year': year,
      };
}

class MarkShare {
  const MarkShare(this.mark, this.avg);
  final num mark;
  final num avg;
}

class ZachBook {
  const ZachBook({required this.studentName, required this.avgPoint, required this.currentSem, required this.rows, required this.share, required this.loadedAt});
  final String studentName;
  final num? avgPoint;
  final int? currentSem;
  final List<ZachRow> rows;
  final List<MarkShare> share;
  final int loadedAt;

  factory ZachBook.fromJson(Map<String, dynamic> j) => ZachBook(
        studentName: j['studentName'] as String? ?? '',
        avgPoint: j['avgPoint'] as num?,
        currentSem: (j['currentSem'] as num?)?.toInt(),
        rows: [for (final r in (j['rows'] as List? ?? const [])) ZachRow.fromJson(r as Map<String, dynamic>)],
        share: [for (final s in (j['share'] as List? ?? const [])) MarkShare(s['mark'] as num, s['avg'] as num)],
        loadedAt: (j['loadedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'studentName': studentName,
        'avgPoint': avgPoint,
        'currentSem': currentSem,
        'rows': [for (final r in rows) r.toJson()],
        'share': [for (final s in share) {'mark': s.mark, 'avg': s.avg}],
        'loadedAt': loadedAt,
      };
}

class StudentCard {
  const StudentCard({
    required this.fullName,
    this.university,
    this.number,
    this.issued,
    this.order,
    this.level,
    this.direction,
    this.profile,
    this.course,
    this.form,
    this.group,
    this.loadedAt = 0,
  });
  final String fullName;
  final String? university;
  final String? number;
  final String? issued;
  final String? order;
  final String? level;
  final String? direction;
  final String? profile;
  final int? course;
  final String? form;
  final String? group;
  final int loadedAt;

  factory StudentCard.fromJson(Map<String, dynamic> j) => StudentCard(
        fullName: j['fullName'] as String? ?? '',
        university: j['university'] as String?,
        number: j['number'] as String?,
        issued: j['issued'] as String?,
        order: j['order'] as String?,
        level: j['level'] as String?,
        direction: j['direction'] as String?,
        profile: j['profile'] as String?,
        course: (j['course'] as num?)?.toInt(),
        form: j['form'] as String?,
        group: j['group'] as String?,
        loadedAt: (j['loadedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'university': university,
        'number': number,
        'issued': issued,
        'order': order,
        'level': level,
        'direction': direction,
        'profile': profile,
        'course': course,
        'form': form,
        'group': group,
        'loadedAt': loadedAt,
      };
}

class AceFeedItem {
  const AceFeedItem({required this.id, required this.category, required this.kind, required this.text, required this.date, required this.time, required this.isNew});
  final String id;
  final String category;
  final String kind;
  final String text;
  final String? date;
  final String? time;
  final bool isNew;

  factory AceFeedItem.fromJson(Map<String, dynamic> j) => AceFeedItem(
        id: j['id'] as String,
        category: j['category'] as String? ?? '',
        kind: j['kind'] as String? ?? 'other',
        text: j['text'] as String? ?? '',
        date: j['date'] as String?,
        time: j['time'] as String?,
        isNew: j['isNew'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'category': category, 'kind': kind, 'text': text, 'date': date, 'time': time, 'isNew': isNew};
}

class AceFeed {
  const AceFeed({required this.items, required this.absences, required this.unread, required this.loadedAt});
  final List<AceFeedItem> items;
  final int absences;
  final int unread;
  final int loadedAt;

  factory AceFeed.fromJson(Map<String, dynamic> j) => AceFeed(
        items: [for (final i in (j['items'] as List? ?? const [])) AceFeedItem.fromJson(i as Map<String, dynamic>)],
        absences: (j['absences'] as num?)?.toInt() ?? 0,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        loadedAt: (j['loadedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'items': [for (final i in items) i.toJson()], 'absences': absences, 'unread': unread, 'loadedAt': loadedAt};
}

sealed class LoginResult {
  const LoginResult();
}

class LoginOk extends LoginResult {
  const LoginOk(this.token);
  final String token;
}

class LoginCaptcha extends LoginResult {
  const LoginCaptcha({required this.imageBase64, required this.key, required this.message});
  final String imageBase64;
  final String key;
  final String message;
}

class LoginTwoFactor extends LoginResult {
  const LoginTwoFactor({required this.email, required this.message});
  final String email;
  final String message;
}

class LoginError extends LoginResult {
  const LoginError(this.message);
  final String message;
}

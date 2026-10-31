import 'package:flutter/material.dart';

import '../domain/time_utils.dart';
import 'scope.dart';

void openLesson(BuildContext context, {required DateTime date, required String group, required int subgroup, required String key, required int slot}) {
  context.open('lesson', {'date': ymd(date), 'group': group, 'sub': '$subgroup', 'slot': '$slot', 'key': key});
}

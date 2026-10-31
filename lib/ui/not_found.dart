import 'package:flutter/material.dart';

import 'common.dart';

class NothingFound extends StatelessWidget {
  const NothingFound({super.key, this.hint = 'Проверьте написание или попробуйте другой запрос.', this.icon = 'search'});
  final String hint;
  final String icon;

  @override
  Widget build(BuildContext context) => EmptyBox(icon: icon, title: 'Ничего не найдено', text: hint);
}

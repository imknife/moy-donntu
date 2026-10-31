import 'package:flutter/material.dart';

import 'common.dart';

typedef PageBuilder = Widget Function(BuildContext context, Map<String, String> params);

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.text = 'Раздел появится в одном из следующих обновлений.'});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => PageScaffold(title: title, children: [EmptyBox(icon: 'sun', title: title, text: text)]);
}

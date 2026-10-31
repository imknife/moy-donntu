import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lab/ui/day_swipe.dart';

void main() {
  testWidgets('свайп влево листает вперёд, вправо назад', (tester) async {
    final steps = <int>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DaySwipe(onStep: steps.add, child: const SizedBox(width: 300, height: 200, child: Text('день'))),
      ),
    );
    await tester.fling(find.text('день'), const Offset(-200, 0), 1200);
    await tester.pumpAndSettle();
    await tester.fling(find.text('день'), const Offset(200, 0), 1200);
    await tester.pumpAndSettle();
    expect(steps, [1, -1]);
  });
}

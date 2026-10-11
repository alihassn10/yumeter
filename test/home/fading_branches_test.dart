import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/features/home/home_shell.dart';

void main() {
  Widget host(int index, {bool reduceMotion = false, VoidCallback? onTapA}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: FadingBranches(
            currentIndex: index,
            children: [
              GestureDetector(onTap: onTapA, child: const Text('tab A')),
              const Text('tab B'),
            ],
          ),
        ),
      );

  double opacityOf(WidgetTester tester, String text) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: find.text(text), matching: find.byType(AnimatedOpacity)),
      )
      .opacity;

  testWidgets('shows the selected tab and fades to the next', (tester) async {
    await tester.pumpWidget(host(0));
    expect(opacityOf(tester, 'tab A'), 1);
    expect(opacityOf(tester, 'tab B'), 0);

    await tester.pumpWidget(host(1));
    // Mid-fade, then settled.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, 'tab B'), 1);
    expect(opacityOf(tester, 'tab A'), 0);
  });

  testWidgets('a hidden tab ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(1, onTapA: () => taps++));
    await tester.tap(find.text('tab A'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('with reduced motion the switch is instant', (tester) async {
    await tester.pumpWidget(host(0, reduceMotion: true));
    await tester.pumpWidget(host(1, reduceMotion: true));
    final fade = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.text('tab B'), matching: find.byType(AnimatedOpacity)),
    );
    expect(fade.duration, Duration.zero);
  });
}

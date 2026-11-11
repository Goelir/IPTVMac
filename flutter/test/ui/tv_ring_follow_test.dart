import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/ui/tv.dart';

void main() {
  // A details sheet whose plot arrives from the network after it opened: the focused button moves without a focus change or a
  // scroll, long after the ring stopped following the focus change. The ring must still end up around the button.
  testWidgets('the ring follows the focused widget when the layout moves it later', (tester) async {
    final gap = ValueNotifier<double>(0);
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => TvShell(child: child!),
      home: Scaffold(
        body: ValueListenableBuilder<double>(
          valueListenable: gap,
          builder: (_, g, _) => Column(children: [SizedBox(height: g), FilledButton(autofocus: true, onPressed: () {}, child: const Text('Resume'))]),
        ),
      ),
    ));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16)); // well past the frames the ring follows a focus change
    }
    gap.value = 200;
    await tester.pump();
    await tester.pump();
    final ring = tester.getRect(find.byKey(const Key('tv-focus-ring')));
    final button = tester.getRect(find.byType(FilledButton));
    expect(ring.contains(button.center), isTrue, reason: 'ring $ring, button $button');
  });
}

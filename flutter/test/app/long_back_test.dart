import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/ui/tv.dart';

KeyEvent down() => const KeyDownEvent(physicalKey: PhysicalKeyboardKey.escape, logicalKey: LogicalKeyboardKey.goBack, timeStamp: Duration.zero);
KeyEvent repeat() => const KeyRepeatEvent(physicalKey: PhysicalKeyboardKey.escape, logicalKey: LogicalKeyboardKey.goBack, timeStamp: Duration.zero);
KeyEvent up() => const KeyUpEvent(physicalKey: PhysicalKeyboardKey.escape, logicalKey: LogicalKeyboardKey.goBack, timeStamp: Duration.zero);

void main() {
  late Future<void> Function() savedExit;
  late int exits;

  setUp(() {
    savedExit = tvExit;
    exits = 0;
    tvExit = () async => exits++;
  });
  tearDown(() {
    tvExit = savedExit;
    isTelevision = false;
    tvExitHooks.clear();
  });

  test('a short press goes on as a normal Back; a long press leaves the app once and eats its repeats and key-up', () {
    var t = DateTime(2027);
    final b = LongBackExit(clock: () => t);
    expect(b.handle(down()), false, reason: 'the key-down goes on');
    t = t.add(const Duration(milliseconds: 300));
    expect(b.handle(repeat()), false, reason: 'not held long enough');
    t = t.add(const Duration(milliseconds: 500));
    expect(b.handle(repeat()), true);
    expect(exits, 1);
    expect(b.handle(repeat()), true);
    expect(exits, 1, reason: 'once');
    expect(b.handle(up()), true, reason: 'the key-up must not also go Back');
    // a short press afterwards is normal again
    expect(b.handle(down()), false);
    expect(b.handle(up()), false);
    expect(exits, 1);
  });

  test('other keys are ignored', () {
    final b = LongBackExit();
    const k = KeyRepeatEvent(physicalKey: PhysicalKeyboardKey.enter, logicalKey: LogicalKeyboardKey.select, timeStamp: Duration.zero);
    expect(b.handle(k), false);
    expect(exits, 0);
  });

  test('leaving the app stops what plays first', () async {
    var stopped = 0;
    tvExitHooks.add(() => stopped++);
    tvExit = savedExit;
    await exitApp();
    expect(stopped, 1);
  });

  testWidgets('on a TV the shell closes the app when Back is held, and not when it is pressed', (t) async {
    isTelevision = true;
    await t.pumpWidget(MaterialApp(builder: (c, child) => TvShell(child: child!), home: const Scaffold(body: Center(child: Text('x')))));
    await t.sendKeyEvent(LogicalKeyboardKey.goBack, physicalKey: PhysicalKeyboardKey.escape);
    expect(exits, 0, reason: 'a short press');
    await t.sendKeyDownEvent(LogicalKeyboardKey.goBack, physicalKey: PhysicalKeyboardKey.escape);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await t.sendKeyRepeatEvent(LogicalKeyboardKey.goBack, physicalKey: PhysicalKeyboardKey.escape);
    expect(exits, 1);
    await t.sendKeyUpEvent(LogicalKeyboardKey.goBack, physicalKey: PhysicalKeyboardKey.escape);
    expect(exits, 1);
  });
}

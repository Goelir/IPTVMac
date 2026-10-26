import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:iptvmac/app/device.dart';

/// Android TV / Google TV / Fire TV: what the shell adds when [isTelevision] is true. On a phone or tablet none of this is in the tree.
///
/// The remote's arrows, Select and Back already work through Flutter's default shortcuts for every widget that can take focus. What
/// is added here: a focus ring seen from the couch, a safe margin around each screen, a rescue when focus is lost, a text field
/// that does not open the keyboard just because the cursor passed over it, and a bigger text size.

/// The route name of the player: it draws its own controls, so the ring stays away from it.
const playerRouteName = 'player';

/// Safe margin around a screen (TVs may crop the edge of the picture).
const tvMargin = EdgeInsets.symmetric(horizontal: 48, vertical: 27);

/// A little larger text on a TV, on top of the user's own font size.
const tvTextScale = 1.2;

/// How far a list builds beyond the screen on a TV: the remote can only move to rows and cells that exist (null = the default).
ScrollCacheExtent? tvCache(double pixels) => isTelevision ? ScrollCacheExtent.pixels(pixels) : null;

/// Wraps a screen's Scaffold in the safe margin (TV only; the background colour fills the margin).
class TvFrame extends StatelessWidget {
  const TvFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      isTelevision ? ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: Padding(padding: tvMargin, child: child)) : child;
}

/// Grows slightly while a descendant has focus (TV only). The ring is drawn by [TvShell].
class TvScale extends StatefulWidget {
  const TvScale({super.key, required this.child});
  final Widget child;
  @override
  State<TvScale> createState() => _TvScaleState();
}

class _TvScaleState extends State<TvScale> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    if (!isTelevision) return widget.child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedScale(scale: _focused ? 1.06 : 1, duration: const Duration(milliseconds: 120), child: widget.child),
    );
  }
}

DateTime? _entryUntil;

/// Call when the remote's Select replaces what is on screen with something new (a category opens its list, a series its page): the
/// first stop of the new content ([TvEntry]) then takes focus, which would otherwise fall back to where it was before (the rail).
/// Any arrow key cancels it.
void tvExpectEntry() {
  if (isTelevision) _entryUntil = DateTime.now().add(const Duration(seconds: 8));
}

bool _takeEntry() {
  final until = _entryUntil;
  _entryUntil = null;
  return until != null && DateTime.now().isBefore(until);
}

/// The first stop of a screen's content (TV only): takes focus when it appears and nothing has it, or when [tvExpectEntry] was called.
class TvEntry extends StatefulWidget {
  const TvEntry({super.key, required this.child});
  final Widget child;
  @override
  State<TvEntry> createState() => _TvEntryState();
}

class _TvEntryState extends State<TvEntry> {
  final _node = FocusNode(canRequestFocus: false, skipTraversal: true);

  @override
  void initState() {
    super.initState();
    if (isTelevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final f = FocusManager.instance.primaryFocus;
        if (!_takeEntry() && f != null && f is! FocusScopeNode) return;
        _node.descendants.where((n) => n.canRequestFocus).firstOrNull?.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => isTelevision ? Focus(focusNode: _node, child: widget.child) : widget.child;
}

bool _isSelect(LogicalKeyboardKey k) => k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter;

/// A text field for the remote: it is read-only (no keyboard) while the cursor merely rests on it; Select starts typing and opens the
/// keyboard; Done ([builder]'s `done`, for the TextField's onSubmitted), Up or Down (single line) or losing focus ends it. Off TV it
/// is just the field. [builder] must hand the [FocusNode] and `readOnly` to its TextField.
class TvEditable extends StatefulWidget {
  const TvEditable({super.key, this.focusNode, required this.builder});
  final FocusNode? focusNode;
  final Widget Function(BuildContext context, FocusNode node, bool readOnly, VoidCallback done) builder;

  @override
  State<TvEditable> createState() => _TvEditableState();
}

class _TvEditableState extends State<TvEditable> {
  late final FocusNode _own = FocusNode();
  FocusNode get _node => widget.focusNode ?? _own;
  var _editing = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_focusChanged);
  }

  @override
  void dispose() {
    _node.removeListener(_focusChanged);
    _own.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (!_node.hasFocus && _editing) setState(() => _editing = false);
  }

  void _start() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _node.context?.findAncestorStateOfType<EditableTextState>()?.requestKeyboard());
  }

  void _stop() {
    if (!_editing) return;
    setState(() => _editing = false);
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final dir = switch (k) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (!_editing) {
      if (e is KeyDownEvent && _isSelect(k)) {
        _start();
        return KeyEventResult.handled;
      }
      if (dir == null) return KeyEventResult.ignored;
      // Resting on the field: all four arrows move on (a text field would otherwise keep Left and Right for its cursor).
      Actions.maybeInvoke(context, DirectionalFocusIntent(dir, ignoreTextFields: false));
      return KeyEventResult.handled;
    }
    // Typing: left and right move the cursor; up and down leave the field (a single line has no use for them).
    if (dir == TraversalDirection.up || dir == TraversalDirection.down) {
      _stop();
      Actions.maybeInvoke(context, DirectionalFocusIntent(dir!, ignoreTextFields: false));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
      _stop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!isTelevision) return widget.builder(context, _node, false, () {});
    return Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _key, child: widget.builder(context, _node, !_editing, _stop));
  }
}

/// Scrolls a long text with the remote's Up and Down (a page that has nothing to focus would not scroll otherwise).
class TvScrollKeys extends StatelessWidget {
  const TvScrollKeys({super.key, required this.controller, required this.child});
  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => !isTelevision
      ? child
      : Focus(
          autofocus: true,
          onKeyEvent: (_, e) {
            if (e is KeyUpEvent || !controller.hasClients) return KeyEventResult.ignored;
            final down = e.logicalKey == LogicalKeyboardKey.arrowDown, up = e.logicalKey == LogicalKeyboardKey.arrowUp;
            if (!down && !up) return KeyEventResult.ignored;
            final p = controller.position;
            controller.animateTo((p.pixels + (down ? 1 : -1) * p.viewportDimension * 0.8).clamp(p.minScrollExtent, p.maxScrollExtent),
                duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
            return KeyEventResult.handled;
          },
          child: child,
        );
}

/// Around the whole app (MaterialApp.builder, TV only): draws the focus ring over whatever has focus, makes the text a little
/// larger, and puts focus back on something when it is lost (a dialog opened, a list rebuilt around the focused row).
class TvShell extends StatefulWidget {
  const TvShell({super.key, required this.child});
  final Widget child;
  @override
  State<TvShell> createState() => _TvShellState();
}

class _TvShellState extends State<TvShell> {
  Rect? _ring;
  var _follow = 0; // frames left to keep measuring: scrolling and the grow animation move the focused widget

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
    HardwareKeyboard.instance.addHandler(_key);
    WidgetsBinding.instance.addPostFrameCallback((_) => _rescue());
  }

  bool _key(KeyEvent e) {
    if (e is KeyDownEvent && {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight}.contains(e.logicalKey)) {
      _entryUntil = null; // the person is moving by hand now
    }
    return false;
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    HardwareKeyboard.instance.removeHandler(_key);
    super.dispose();
  }

  void _focusChanged() {
    _follow = 24;
    _measure();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rescue());
  }

  void _measure() {
    if (!mounted) return;
    final r = _ringRect();
    if (r != _ring) setState(() => _ring = r);
    if (_follow > 0) {
      _follow--;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  Rect? _ringRect() {
    final n = FocusManager.instance.primaryFocus;
    final ctx = n?.context;
    if (n == null || ctx == null || n is FocusScopeNode || !ctx.mounted) return null;
    if (ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null) return null; // a text field draws its own border
    if (ModalRoute.of(ctx)?.settings.name == playerRouteName) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !n.rect.isFinite) return null;
    final r = n.rect;
    return Rect.fromPoints(box.globalToLocal(r.topLeft), box.globalToLocal(r.bottomRight));
  }

  /// Nothing (or only a route's scope) has focus: take the first focusable thing of the top route.
  void _rescue() {
    if (!mounted) return;
    final f = FocusManager.instance.primaryFocus;
    if (f != null && f is! FocusScopeNode) return;
    final scope = f ?? FocusManager.instance.rootScope;
    final first = ReadingOrderTraversalPolicy().findFirstFocus(scope, ignoreCurrentFocus: true);
    if (first != null && first != scope) first.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = mq.textScaler.scale(14) / 14 * tvTextScale;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ring = dark ? Colors.white : const Color(0xFF1A1040);
    final edge = dark ? const Color(0xFF1A1040) : Colors.white;
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(scale)),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          if (_ring != null) _measure();
          return false;
        },
        child: Stack(textDirection: TextDirection.ltr, children: [
          Positioned.fill(child: widget.child),
          if (_ring != null)
            Positioned.fromRect(
              rect: _ring!.inflate(3),
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const Key('tv-focus-ring'),
                  decoration: BoxDecoration(border: Border.all(color: ring, width: 3), borderRadius: BorderRadius.circular(14)),
                  child: Padding(padding: const EdgeInsets.all(3), child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: edge, width: 1.5), borderRadius: BorderRadius.circular(11)))),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

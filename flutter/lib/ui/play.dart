import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/app/player_host.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/player/play_request.dart';
import 'package:iptvmac/player/player_screen.dart';
import 'package:iptvmac/ui/details_sheet.dart';
import 'package:iptvmac/ui/series_screen.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:provider/provider.dart';

/// Builds the player screen. Tests replace it to see what the shell hands to the player.
@visibleForTesting
Widget Function(PlayRequest, PlayerHost) playerBuilder = (r, h) => PlayerScreen(request: r, host: h);

/// A tap on an item: a series opens its episodes, a movie its details sheet, a channel (or a direct link) plays.
Future<void> openItem(BuildContext context, Item item, {List<Item> zapList = const []}) {
  final model = context.read<LibraryModel>();
  if (model.opensSeries(item)) {
    tvExpectEntry(); // the series page loads its episodes; its Play button takes focus when they are there
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SeriesScreen(series: item)));
  }
  // On a TV the sheet is also where a direct-link movie gets its favorite star (a phone uses a long press for that).
  if (item.type == ItemType.movie && (item.directURL == null || isTelevision)) return showItemDetails(context, item);
  return playItem(context, item, zapList: zapList);
}

/// Plays a movie or channel. With no stored password the model asks for it instead (the root shows the dialog).
Future<void> playItem(BuildContext context, Item item, {List<Item> zapList = const []}) async {
  final r = context.read<LibraryModel>().requestFor(item);
  if (r != null) await openPlayer(context, r, zapList: zapList);
}

/// Pushes the player. The host is the app's side of the contract in lib/player/play_request.dart.
Future<void> openPlayer(BuildContext context, PlayRequest r, {List<Item> zapList = const []}) async {
  final model = context.read<LibraryModel>();
  final nav = Navigator.of(context);
  var closed = false;
  final host = ShellPlayerHost(model, zapList: zapList, onClose: () {
    if (closed) return; // a second close must not pop the screen below
    closed = true;
    nav.pop(); // a real pop: the player screen blocks a plain back (PopScope) and asks us to leave
  }, onShowDetails: (item) => showItemDetails(nav.context, item, playing: true));
  await nav.push(MaterialPageRoute<void>(builder: (_) => playerBuilder(r, host), fullscreenDialog: true, settings: const RouteSettings(name: playerRouteName)));
  closed = true;
  model.reloadContinue();
}

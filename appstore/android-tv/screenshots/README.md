# TV screenshots: how to take them

The lead takes these from the emulator after the TV UI is merged. Nothing here has been run by me (the emulator belongs to another agent).

## Rules (hard)
- **Demo provider only.** Use the invented provider the Flutter tests/screens already use (`flutter/docs/screens` was made with it) or the open-licence review playlist (`https://goelir.github.io/IPTVMac/review/ReviewPlaylist.m3u`). **Never a real provider**: no real host, username, logo, channel name or password may appear in any frame, in the recent-apps card, or in the notification shade.
- Titles must be invented or open-licence (Blender films). No real channel logos, no real TV shows, no real brands.
- No source address visible on screen (Settings > Playlists shows addresses: do not capture it).
- 16:9, **1920x1080**, PNG or JPEG, **no alpha channel** (Play rejects alpha; `python3 appstore/android-tv/check-listing.py` checks every `tv-*.png` in this folder, or `file x.png` must say `RGB`, not `RGBA`).
- No frame, no device mock-up, no overlay text added; the system status bar is absent on a TV, keep it that way. The focus highlight on the selected item must be visible (it shows D-pad use).
- File names `tv-01-live.png` ... in this folder (`appstore/android-tv/screenshots/`), same order as the list below. Play takes 1 to 8 TV screenshots (memory: check the limits in the console); Amazon wants at least 3 for Fire TV (memory). Take 6.

## Commands (emulator `iptv_api36`, an Android TV or 1080p profile)

The emulator must be started by whoever owns it (headless is fine for screenshots: `emulator -avd iptv_api36 -no-window -no-audio -gpu host`). A normal phone AVD is made to look like a TV with:

```
adb -s emulator-5554 shell wm size 1920x1080
adb -s emulator-5554 shell wm density 320          # 1080p at 320 dpi = 960x540 dp, what a TV reports (the TV UI is laid out for that)
adb -s emulator-5554 shell settings put global window_animation_scale 0
adb -s emulator-5554 shell settings put global transition_animation_scale 0
adb -s emulator-5554 shell settings put global animator_duration_scale 0
```

Force the TV UI (the lead's debug switch, named in the app change as `FORCE_TV`; use the exact way that change documents, for example `--dart-define=FORCE_TV=true` for a debug run, or the intent extra if it is an extra) and install the demo build:

```
cd flutter && flutter build apk --debug --dart-define=FORCE_TV=true    # name and way: see the TV change
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n io.github.goelir.iptvmac/.MainActivity
```

Navigate with the remote keys only (this also proves the D-pad works):

```
adb -s emulator-5554 shell input keyevent KEYCODE_DPAD_DOWN     # DPAD_UP / DPAD_LEFT / DPAD_RIGHT / DPAD_CENTER (OK) / BACK
```

Capture (the screenshot is already 1920x1080 after `wm size`; `exec-out` avoids a CR/LF problem on the pipe):

```
adb -s emulator-5554 exec-out screencap -p > appstore/android-tv/screenshots/tv-01-live.png
file appstore/android-tv/screenshots/tv-01-live.png     # must say 1920 x 1080, 8-bit/color RGB (convert with `sips -s format png` or strip alpha if it says RGBA)
```

If the picture area stays black in the emulator, that is a known emulator limit (software rendering, no EGL): `docs`/`flutter/PLAN.md` "Phase 0 results". For the **player** frame use a real Android TV / Fire TV device, or the review playlist on a physical device with `scrcpy`/`adb exec-out screencap`, not the emulator.

When done, restore the emulator: `adb -s emulator-5554 shell wm size reset && adb -s emulator-5554 shell wm density reset`, and animation scales back to 1.

## The 6 screens (in this order)

1. **Live**: the channel grid/list of the demo provider with the focus ring on one channel; categories in the left menu. (Message: browse live TV with the arrow keys.)
2. **Search**: the search screen with a short word typed and instant results below, focus on the first result. (Message: instant search.)
3. **Movies**: the movie posters grid (gradient posters of invented titles, or the Blender films) with focus on one poster.
4. **Details**: a movie detail page with the Play button focused (plot text of the open-licence film; no real film).
5. **Player**: the built-in player with the control bar visible (needs a real device for the picture): the open-licence film "Sintel" or "Big Buck Bunny" playing, subtitles on if possible, seek bar and track buttons visible.
6. **Add source / welcome**: the add-source screen with M3U selected and the review playlist link typed (the link is public), showing the authorization sentence ("Use only sources you are authorized to access") if the welcome screen has it. (Message: your own source, no content included. It also helps the review.)

Credit line for the listing is already in `listing/*/full-description.txt` ("Sintel (c) Blender Foundation, CC BY 3.0").

## After you have the files
- Google Play: Store listing > Graphics > TV screenshots (upload `tv-0*.png`) and TV banner (`../graphics/play-tv-banner-1280x720.png`).
- Amazon: Fire TV screenshots, same files (check the size it asks for: 1920x1080 or 1280x720).
- Re-run `python3 appstore/android-tv/check-listing.py` (it checks the `tv-*.png` files here: size and alpha).

# IPTVMac for Android TV and Fire TV: store submission kit

For the owner (Eli). Everything the stores ask for is prepared, so the console work is copy and paste. **Nothing has been submitted, published or pushed.** Written 2026-10-26 on the branch that adds the TV UI; the TV UI itself comes from the other agents.

How facts are marked: **(memory)** = from my knowledge of the Play Console, the Amazon Developer Console or Android tooling, not re-read today (I had no web access for this task): the label or number may have moved, **check in the console**. **(measured)** = I ran it here. Unmarked = derived from this repository.

## 1. What is in this folder

| Path | What | Use |
|---|---|---|
| `listing/en-US/`, `listing/he-IL/` | `title.txt` (20/30), `short-description.txt` (73/80), `full-description.txt` (2669/4000), `release-notes.txt` (190/500), `keywords-amazon.txt` | paste into Play (en-US, Hebrew) and Amazon |
| `check-listing.py` | checks all lengths, forbidden words (price, rankings, other brands, emoji, ALL CAPS in the title), the privacy link, and the PNGs in `graphics/` and `screenshots/tv-*.png` (size and alpha) | `python3 appstore/android-tv/check-listing.py` |
| `play-console-answers.md` | the App content answers (ads, app access text with the review playlist and D-pad steps, content rating, target audience, Data safety, foreground services, other declarations), and the "why this is not a copyright problem" text | copy and paste |
| `graphics/` | `play-icon-512.png`, `play-feature-graphic-1024x500.png`, `play-tv-banner-1280x720.png`, `amazon-icon-512.png`, `amazon-icon-114.png` (made by `swift scripts/tv/store-graphics.swift`, same look as the in-app banner; the feature graphic and TV banner are 24-bit PNG without alpha as Play wants) | upload |
| `screenshots/README.md` | exact commands and the six screens for the 1920x1080 TV screenshots (the lead takes them later) | for the lead |

Sources of the facts: the iOS preparation (`appstore/CHECKLIST.md`, `age-rating.txt`, `content-rights.txt`, `ios/review-notes.txt`), the site's privacy and support pages (`scripts/site/legal.py`), the review playlist `https://goelir.github.io/IPTVMac/review/ReviewPlaylist.m3u` (Blender Foundation open films only), `flutter/README.md`, `flutter/PLAN.md`.

## 2. Decisions only you can take

| # | Decision | My recommendation |
|---|---|---|
| 1 | **Signing**: new upload key (Google re-signs) or enrol the existing key | **New upload key** (section 6). |
| 2 | **Developer account type** for Google Play | Check which you have. A *personal* account created after November 2023 must run a closed test with 12 testers for 14 days before Production is allowed (memory: check the numbers in the console). An *organization* account does not, but needs a D-U-N-S number. This decides the calendar: plan about 3 weeks, not 3 days. |
| 3 | **Public contact email**: Play shows the developer email on the listing | `scripts/site/build.py` has `CONTACT_EMAIL = "shayanaccs736@gmail.com"` (it is already public on the site pages). Decide that you are fine with it also on Google Play and Amazon (EU "trader" rules may also show an address and phone on the listing: memory, check). A dedicated address is cleaner. |
| 4 | **One Play listing for phone and TV** (same package `io.github.goelir.iptvmac`) | Yes: add the Android TV form factor to the existing app; one listing, one bundle. Amazon is a separate listing. |
| 5 | **Version codes** | The GitHub APKs use 2006 (arm64), 1006 (armv7), 4006 (x86_64) for version 1.0.3 (split per ABI). A Play bundle has ONE code (pubspec build number, `1.0.3+6` should give 6: check with `bundletool dump manifest`). With recommendation 1 the two installs are different apps to Android and the numbers never meet. If you choose option (b) in section 6, give the Play bundle a code above every GitHub code, for example `--build-number=10007`. |
| 6 | **Disable the GitHub update banner in store builds** | Yes (section 3, item 1). |
| 7 | **Fire TV: Vega OS** | Newer Amazon sticks run Vega OS, which cannot install an Android APK (memory: "Fire TV Stick 4K Select", 2025). The Amazon listing then reaches only Fire OS devices. Accept that. |

## 3. App changes needed before submission (for the lead; I did not touch `flutter/`)

1. **No GitHub update banner or "check for updates" row in the Play and Amazon builds** (a `--dart-define` flag, off in store builds). Play's Device and Network Abuse policy (memory) forbids an app distributed through Play from updating itself by any other method; our banner only opens a release page and installs nothing, but it points Play users at an APK with another signature, and a reviewer can flag it. The privacy page already describes the check as "Android version", so keep that bullet for the APK and add one for the stores.
2. **The welcome text must say that the user uses only authorized sources.** Today `onbWelcomeBody` is "Watch live channels, movies and series from your IPTV provider. Let's add your first source." There is no sentence about authorization anywhere in `flutter/lib` (checked with grep). Add one line to the welcome screen of all form factors, for example "IPTVMac includes no content. Use only sources you are authorized to access." (31 languages: the Apple strings are the source). The declaration text in `play-console-answers.md` relies on it.
3. **Manifest items for TV (memory: Android TV app quality requirements)**: `<uses-feature android:name="android.software.leanback" android:required="false"/>`, `<uses-feature android:name="android.hardware.touchscreen" android:required="false"/>`, an activity with `<category android:name="android.intent.category.LEANBACK_LAUNCHER"/>`, `android:banner="@drawable/tv_banner"` on the application or activity (the 320x180 banner already exists), no `android.hardware.*` feature that a TV lacks (camera, telephony, GPS, ...) marked as required, and no screen-orientation lock to portrait. Check them on the final bundle with the `bundletool dump manifest` line in section 7.
4. **Everything reachable with the D-pad**, including the privacy-policy link (Play wants a policy link inside the app (memory); `about_screens.dart` has it) and the source form (long address typing with a remote is painful: consider "paste from the phone" later, not needed for review).
5. If the TV build has no downloads, drop `FOREGROUND_SERVICE_DATA_SYNC` and the WorkManager service from the manifest: it removes one Play declaration (the video for it).
6. **The privacy page** (`scripts/site/legal.py`): add "Google Play / Amazon Appstore version: no update check, updates come from the store" and "your device" next to "your Mac". The phone-and-TV text on the page mentions the Mac in "What is stored".
7. **Phone screenshots** for the same Play listing: `flutter/docs/screens/*.png` are 540x1210 RGBA. Play wants no alpha and at most 2:1 (memory: 2.24:1 is too tall). Retake at 1080x1920 or crop; not part of this task.

## 4. Google Play Console, step by step

Labels are from memory and move often: search the console for the words in **bold**.

**A. Account**
1. play.google.com/console, developer account (one-time fee, about 25 USD, memory), identity verification, contact phone and email. Accept the Developer Distribution Agreement.
2. If it is a personal account: read decision 2 now. Start the closed test early.

**B. Create the app** (Home > **Create app**; skip if the phone app already exists there)
3. App name `IPTVMac: IPTV Player` (`listing/en-US/title.txt`), default language **English (United States)**, **App**, **Free** (a free app cannot become paid later), tick both declarations (policies, US export laws; the app uses only standard HTTPS/TLS).

**C. Dashboard tasks** (the "Set up your app" list; all answers are in `play-console-answers.md`, in this order)
4. Privacy policy `https://goelir.github.io/IPTVMac/privacy/`; App access (the review playlist text); Ads = No; Content rating; Target audience = 18 and over only; Data safety = no data collected; Government = No; Financial features = none; Health = none; News = No; Advertising ID = No; Foreground service permissions (media playback, and data sync if present); category **Video Players & Editors**; contact details.

**D. Store listing** (Grow > **Store presence > Main store listing**)
5. App name, short description (80), full description (4000): from `listing/en-US/`. **Manage translations** > add **Hebrew**: `listing/he-IL/` (the language tag may show as `iw-IL` or `he`).
6. Graphics: **App icon** `graphics/play-icon-512.png` (512x512 PNG, 32-bit, up to 1 MB, memory); **Feature graphic** `graphics/play-feature-graphic-1024x500.png` (1024x500, JPEG or 24-bit PNG, no alpha); phone screenshots (see section 3, item 7).

**E. The TV part**
7. **Form factors** (Test and release > **Advanced settings** > **Form factors**; the page has moved before): add **Android TV** (opt-in). New TV assets appear in the main store listing: **TV banner** `graphics/play-tv-banner-1280x720.png` (1280x720, no alpha) and **TV screenshots** (1920x1080, the six screens in `screenshots/README.md`; the minimum count is in the console, memory: at least 1 and up to 8).
8. TV apps are checked twice: the usual policy review and a TV quality check (D-pad, launcher, banner, no touch-only screens). Play shows the reasons next to the form factor if the bundle is not eligible.

**F. Testing and release**
9. Build the bundle (section 7). **Internal testing** (Test and release > Testing > **Internal testing**): create the track, add your own Google account as a tester, **Create new release**, upload `app-release.aab`, accept **Play App Signing** (it is mandatory for bundles; the choice of key is section 6), release notes from `listing/*/release-notes.txt` (format with the tags the console shows), **Save, Review release, Start rollout**. No policy review wait for internal testing (memory), usually minutes.
10. Install from the tester link on a real Android TV or Google TV (the opt-in link opens in a browser on a phone; then the TV's Play Store shows the app; memory). Run the review flow from `play-console-answers.md` section 3 with the remote.
11. **Closed testing** (needed first if decision 2 says so): create a track, add a Google Group or an email list of at least 12 people (memory) who opt in, keep the test running 14 days, then **Apply for production** (the Dashboard shows the task).
12. **Production**: **Create new release** (promote the tested bundle), countries (all unless you have a reason), release notes, **Send for review**. Review time for a new app is typically a few days, sometimes more than a week (memory). Turn on **Managed publishing** if you want to press the final button yourself.
13. After approval, check **Release > Reach and devices > Device catalog**: TV devices are supported, and a TV in the **Play Store** (search "IPTVMac") shows the app. Watch **Policy status** for the first weeks.

## 5. Amazon Appstore (Fire TV), step by step

Everything marked (memory) was not re-read today.

**A. Prepare the APK** (Amazon takes APKs; newer consoles also accept bundles, memory: use the APK, it is the safe path)
1. Fire TV devices are mostly 32-bit ARM user space, some 64-bit. Build one APK with both: `cd flutter && flutter build apk --release --target-platform android-arm,android-arm64` (about 70 MB, not measured). It needs the key from section 6: any key works for Amazon, but use the same upload key so you maintain one extra key only (memory: Amazon re-signs apps it distributes; check "App signing" in the console and whether it asks you to enable its DRM: say **No**).
2. `minSdk` is 26 (Fire OS 7 = Android 9 and later; Fire OS 5 and 6 sticks are excluded; memory). Test on a real Fire TV if you can: no Google Play Services there (the app has none).

**B. Console** (developer.amazon.com > Apps & Services > **Amazon Appstore** > **Add a new app**; the account is free, memory)
3. Sign in with an Amazon account, complete the developer profile (name, address, support email). The tax interview is asked only for paid apps (memory).
4. **Add a new app** > **Android** > App title `IPTVMac: IPTV Player` (`listing/en-US/title.txt`). If Amazon asks: Fire TV app = yes.
5. **App Information**: category (memory: Video or Entertainment), the app's **support contact**, **website** `https://goelir.github.io/IPTVMac/`, **privacy policy URL** `https://goelir.github.io/IPTVMac/privacy/`, **support page** `https://goelir.github.io/IPTVMac/support/`.
6. **Availability and Pricing**: countries, price **Free**, release date.
7. **Description**: title; **short description** (`listing/en-US/short-description.txt`; the maximum is not known to me, ours is 73 characters); **long description** (`full-description.txt`); **feature bullets** (up to 5, memory), use:
   - Plays your own M3U playlists and Xtream Codes logins; no content included
   - Made for the remote: browse and play with the directional pad
   - Instant search over all channels, movies and series
   - Built-in mpv player: subtitles, audio tracks, speed, catch-up
   - No account, no ads, no tracking; free and open source (GPL-3.0)
   **Keywords**: `listing/en-US/keywords-amazon.txt` (89 characters; the limit is not known to me: **check in the console**). Hebrew is a second language entry.
8. **Images and Multimedia** (memory, check the sizes the page prints): small icon `graphics/amazon-icon-114.png` (114x114 PNG), large icon `graphics/amazon-icon-512.png` (512x512 PNG), **Fire TV screenshots** (1920x1080 or 1280x720, memory: at least 3; the six from `screenshots/README.md`), optional video. Some versions ask for a Fire TV background image (1920x1080): use `graphics/play-tv-banner-1280x720.png` scaled up, or leave if optional.
9. **Content rating**: a questionnaire like IARC's (memory). Same answers as in `play-console-answers.md` section 4: no violence, sexuality, profanity, gambling, drugs; no user-to-user interaction; no purchases; **no unrestricted web browsing**; the app **does** access third-party content chosen by the user: say so where it asks. Pick the rating the console computes, and put "18+" in the long description (it is there: "Use only sources you are authorized to access").
10. **Compliance questions** (memory): ads = No; collects personal information = No (nothing leaves the device except to the user's own servers); uses an account = No; export compliance: standard HTTPS only (TLS).
11. **Binary files**: upload the APK. The console lists the Fire devices the manifest supports (**Device Support**): keep **Fire TV** devices ticked; untick Fire tablets and phones unless you tested them (the phone UI is supported by the same code, your decision). Languages supported: tick all 31 if the list is there.
12. **Submit**. Review takes about one to a few days (memory). The test notes field: paste the short text from `play-console-answers.md` section 9 plus the app-access steps (section 3).
13. **Fire OS notes**: the Fire TV remote has D-pad, OK, Back, Home, Menu, play/pause, rewind and fast-forward only (no number keys, no colour keys): the player must work with those. Voice (Alexa) is optional, skip. Back on the first screen must exit. Enable ADB debugging on the stick (Developer options) and install with `adb connect <ip>:5555 && adb install app-release.apk` for a test before submitting. A device with Vega OS cannot be used.

## 6. Signing decision

Today the GitHub APKs are signed with `~/.iptvmac-android/iptvmac-android.jks` (certificate SHA-256 `f7d45a43a096908cc065d1f43a5c1123edbeee24e474a0cd486209cc995cba51`). Google Play needs **Play App Signing** for every app bundle: Google holds the key that signs what users receive, and you sign your upload with an upload key.

| | (a) New upload key, Google makes the app-signing key | (b) Enrol the existing key into Play App Signing |
|---|---|---|
| What happens | Play creates a fresh app-signing key. You make a separate upload key. Installs from Play carry Google's certificate. | Your existing private key is exported (encrypted) and uploaded to Google; Play signs with it. Installs from Play and the GitHub APK carry the **same** certificate `f7d45a43...`. |
| Update between sources | **Not possible** either way: Android refuses to update an app with a different signature. A user must uninstall one to install the other (they lose local data, the in-app backup/restore covers sources and favourites). | Allowed by Android if the version code of the newer one is higher. The Play bundle code must exceed the GitHub codes (up to 4xxx), e.g. 10007. (Play itself normally updates only what it installed, memory.) |
| Risk | Almost none. The existing key never leaves your Mac. | **Irreversible**: you cannot leave Play App Signing, and a copy of your key is at Google forever. The key on the Mac stays needed for the GitHub channel. If you made a wrong export (wrong alias), the flow is fiddly. |
| Later | If Google ever has to replace the signing key, Play has a "key upgrade" for new installs only. | Same. |
| Amazon | Amazon is a third signature anyway (memory: it re-signs), so "one signature everywhere" does not exist. | same |

**Recommendation: (a).** Reasons: the GitHub APK audience is small and technical; Amazon will have a different signature whatever you choose, so (b) cannot give "one signature everywhere"; (b) is irreversible and puts the key that the existing channel depends on in a second place for a benefit that few users would use. (b) makes sense only if you expect many GitHub users to move to Play and want them to keep data. Tell GitHub users in the release notes that the store version is a separate install.

**How to do (a)** (the passwords are typed into the prompts: never in the command line, never in a chat, never in a file in this repository):

```
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
$JAVA_HOME/bin/keytool -genkeypair -v -keystore ~/.iptvmac-android/iptvmac-play-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

It asks for a keystore password, a key password, and your name; then back up `~/.iptvmac-android/` (a lost upload key can be reset through Play support, but it takes days; the GitHub key cannot be replaced at all). Point `flutter/android/key.properties` (git-ignored) at the new file while you build the Play bundle: keep the old file as `key.properties.github` and swap with `cp` (a cleaner way is for the lead to teach `flutter/android/app/build.gradle.kts` to read `key.play.properties` when `-Pplay` is passed; that file is outside my scope). Get the upload certificate fingerprint to compare later:

```
$JAVA_HOME/bin/keytool -list -v -keystore ~/.iptvmac-android/iptvmac-play-upload.jks -alias upload     # asks the password; read the SHA256 line
```

**How to do (b)** (only if you choose it):
1. Play Console > the app > **Test and release > App integrity** (or **Setup > App signing**; memory) > **Play app signing** > choose to **export and upload a key from a Java keystore**. The page lets you download `pepk.jar` and the `encryption_public_key.pem`.
2. List the alias (it asks the store password at the prompt): `$JAVA_HOME/bin/keytool -list -keystore ~/.iptvmac-android/iptvmac-android.jks`
3. Export (it asks the passwords at the prompt):
```
$JAVA_HOME/bin/java -jar pepk.jar --keystore=$HOME/.iptvmac-android/iptvmac-android.jks --alias=<THE ALIAS FROM STEP 2> --output=$HOME/play_signing_key.zip --include-cert --rsa-aes-encryption --encryption-key-path=$HOME/encryption_public_key.pem
```
4. Upload `play_signing_key.zip` in the console. Choose to create a **new upload key** (same keytool command as in (a)) so the signing key is not also your upload key. Then upload the bundle signed with the upload key.
5. After the first upload the page must show the app-signing certificate SHA-256 `f7d45a43...cba51`. If it does not, stop.
6. Delete `play_signing_key.zip` afterwards (it is encrypted for Google, still a copy of the key).

**The password rule:** the key and store passwords never go in a chat, an email, an issue, a script, a shell history or a prompt to any assistant, including me. They live in the prompts and in `~/.iptvmac-android/key.properties` (outside the repository, git-ignored). If a command must be non-interactive, use `read -s KSPASS; export KSPASS` and pass `--ks-pass=env:KSPASS` (bundletool) or `-storepass:env KSPASS` (jarsigner). If a password was ever pasted anywhere, treat the key as compromised: for the upload key, make a new one; for the GitHub key there is no replacement, so protect it.

## 7. Build and check the bundle

Verified here: the command below builds a bundle. **Measured 2026-10-26** in this worktree (no `key.properties`, so it is signed with the debug key; the real build uses the upload key): `flutter build appbundle --release` succeeded in 82 s of Gradle time; `build/app/outputs/bundle/release/app-release.aab` is **88,502,610 bytes (88.5 MB)**; ABIs `armeabi-v7a`, `arm64-v8a`, `x86_64`; target SDK 36, min SDK 26; every native library (`libmpv.so`, `libflutter.so`, `libapp.so`, `libsqlite3.so`, ...) has an ELF segment alignment of at least 16 KB, which Play requires for apps targeting Android 15 and later (memory); the native debug symbols (`.so.sym`) are inside the bundle. `jarsigner -verify` says "jar verified" and the signer is `CN=Android Debug` (SHA-256 `6E:7B:9E:E6:...:A0:81`, a debug key: **never upload this build**). The download size users see is much smaller than 88.5 MB (Play splits by ABI and language): `bundletool get-size total` tells you.

```
cd flutter
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=$HOME/Library/Android/sdk
flutter pub get && flutter gen-l10n && flutter build appbundle --release --dart-define=STORE_BUILD=true   # STORE_BUILD: no GitHub update banner or setting in a store build
AAB=build/app/outputs/bundle/release/app-release.aab
ls -l $AAB

# 1. Which key signed it? (note: /usr/bin/jarsigner is a stub; use the JDK one)
$JAVA_HOME/bin/jarsigner -verify -verbose:summary -certs $AAB          # must say "jar verified."
$JAVA_HOME/bin/keytool -printcert -jarfile $AAB | grep -E "Owner|SHA256"   # SHA256 must equal the UPLOAD key's, NOT "Android Debug", NOT the GitHub key's f7d45a43... unless you chose (b)

# 2. bundletool (not installed here: `brew install bundletool`; check the version and flags with `bundletool help`)
bundletool validate --bundle=$AAB
bundletool dump manifest --bundle=$AAB | grep -E "versionCode|versionName|minSdk|targetSdk|leanback|touchscreen|banner|LEANBACK_LAUNCHER|AD_ID"
bundletool build-apks --bundle=$AAB --output=$HOME/iptvmac.apks --connected-device     # the connected device must be a real TV or the TV emulator; signed with the debug key unless you add --ks=... --ks-key-alias=... --ks-pass=env:KSPASS
bundletool install-apks --apks=$HOME/iptvmac.apks
bundletool get-size total --apks=$HOME/iptvmac.apks
```

The same `jarsigner` and `keytool` lines work on the APK for Amazon (`app-release.apk`); for APKs `apksigner verify --print-certs app-release.apk` (in `$ANDROID_HOME/build-tools/<version>/`) is the stricter check.

## 8. Policy risks, honestly

IPTV players are a category that **both stores take down regularly**, not because the player is illegal but because users use them for pirated channels and because many listings promise channels. A rejection or removal is possible at any time, including after launch, and a policy strike on a Play developer account can affect the account (and other apps on it).

**Google Play policies that apply (memory: re-read them at play.google.com/about/developer-content-policy before submitting):**
- **Intellectual Property** (copyright; the policy also names apps that facilitate unauthorized access to copyrighted content). Risk: a reviewer or a rights holder sees the app used for pirated streams or a screenshot with real channel logos.
- **Deceptive Behavior** and **Metadata**: misleading titles and descriptions, "free TV/channels/movies", keyword stuffing, other brands. Risk if the listing sounds like a content service.
- **Restricted Content** (sexual content, UGC) and **minimum functionality**: an app that shows nothing without a source can be rejected as "not working" unless the review instructions give a working source. Hence the review playlist in App access.
- **Device and Network Abuse**: the self-update banner (section 3, item 1).
- Takedown notices (DMCA) can be filed against the listing independently of the review.

**Amazon content policies (memory):** apps may not infringe or facilitate infringement of intellectual property, may not preload content without rights, and Amazon asks for proof of rights on request; the Appstore also rejects listings that promise channels.

**Mitigations already built in:** no content and no default source or provider list; the user supplies M3U/Xtream sources and the app says so everywhere; the description never says "free channels" (the checker script bans "free" in the title and short description) and carries "Use only sources you are authorized to access"; no code to bypass copy protection and DRM streams do not play; the review playlist is open-licence films only; screenshots use invented titles, no real logos (rule in `screenshots/README.md`); target audience 18+; contact address and the support page on the site for rights-holder notices; GPL-3.0 source public; no ads, no analytics, no tracking. **Still to do:** the welcome-screen sentence (section 3, item 2). Other known IPTV players are on both stores (memory: for example TiviMate and IPTV Smarters Pro), which shows the neutral-player approach can pass, not that it always will.

If a rejection arrives: do not argue in anger; reply once with the text from `play-console-answers.md` section 9, point to the review playlist, offer to change whatever metadata they name, and keep a copy of the Policy status page. Do not resubmit unchanged repeatedly (repeated violations are counted).

## 9. Before you submit (checklist)

- [ ] `python3 appstore/android-tv/check-listing.py` says all ok (with the six TV screenshots added)
- [ ] The decisions in section 2 are made; the signing key choice is done and the keys are backed up (`~/.iptvmac-android/`)
- [ ] The app changes in section 3 are in the bundle (update banner off in store builds, welcome sentence, TV manifest items, privacy page updated and deployed: `curl -sI https://goelir.github.io/IPTVMac/privacy/` is 200)
- [ ] `curl -sI https://goelir.github.io/IPTVMac/review/ReviewPlaylist.m3u` is 200 and the app plays it on a TV (run `python3 appstore/check-review-playlist.py https://goelir.github.io/IPTVMac/review/ReviewPlaylist.m3u --online`)
- [ ] Bundle signed with the upload key (section 7 step 1), `versionCode` higher than the one before, `bundletool dump manifest` shows leanback and the banner
- [ ] Installed from an internal test track on a real TV and the full review flow was done with the remote only
- [ ] Screenshots contain no real provider, address, logo or channel
- [ ] The foreground-service videos exist (media playback, data sync) if the declarations ask
- [ ] Data safety = "no data collected" matches the privacy page; the privacy page says nothing the app does not do
- [ ] Listing texts do not claim channels, "free TV", rankings or other brands
- [ ] Amazon: APK tested on a real Fire TV (or reason noted), the Appstore DRM choice is No
- [ ] Nobody pasted a key password anywhere

## 10. What I could not verify

- **Every Play Console and Amazon Console label, limit and number** marked (memory): the closed-test rule (12 testers, 14 days), where **Form factors** is, TV screenshot count and sizes, IARC question wording and whether a "Yes, third-party content" question exists, Amazon image sizes, keyword and description limits, Amazon's review time and whether it accepts bundles. I had no web access; confirm on screen.
- **Policy texts** (Play Intellectual Property, Deceptive Behavior, Device and Network Abuse, Amazon content policy): quoted from memory, not re-read.
- That the Play bundle **passes the TV quality check**: the TV UI and manifest do not exist in my branch.
- **bundletool** commands: bundletool is not installed here (flags from memory; run `bundletool help`). **PEPK** flags are from memory; the console shows the exact command.
- That an Amazon-installed copy is re-signed by Amazon, and what the Amazon DRM option does.
- That **Vega OS** devices reject APKs (my reading of Amazon's 2025 announcement).
- Whether **Android developer verification** (Google's requirement, announced for 2026 in a few countries first, memory) affects the GitHub APKs: check developer.android.com/developer-verification for the key registration, it concerns sideloaded apps and the signing key `f7d45a43...`.
- Whether the Data safety "No" is accepted when the user's own provider receives the login; section 6 of `play-console-answers.md` has the conservative alternative.
- The **real picture on a TV**: the emulator renders black video (see `flutter/PLAN.md`), and I did not run any app. The **AAB size per device** was not measured.
- The **Hebrew listing** was written by me (same wording as the Mac Hebrew texts); a native read is advisable.
- That the contact address `shayanaccs736@gmail.com` is the one you want on a public store listing.

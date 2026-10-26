# Google Play Console: the answers to copy

Every answer for the "App content" pages of the Play Console, in the order the console shows them. How facts are marked: nothing = I derive it from the app itself (the code, the manifest, the privacy page); **(memory)** = from my knowledge of Play Console, not re-read today: check the label on screen. The questions change often, so the meaning of each answer is given, not only the word.

Facts you can quote (all true in this repository):
- Package `io.github.goelir.iptvmac`, version 1.0.3 (build 6) for phones; the TV release will have its own version.
- No account, no login of our own, no ads, no analytics, no tracking, no in-app purchase, no paid feature, no developer server. The app talks only to the servers the user adds, plus (phone/APK builds) one read of the public GitHub releases feed.
- Permissions in the manifest: INTERNET, WAKE_LOCK, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK, FOREGROUND_SERVICE_DATA_SYNC, POST_NOTIFICATIONS. No location, camera, microphone, contacts, storage, advertising ID.
- `usesCleartextTraffic="true"` (providers often serve plain `http://host:port`).
- Support page https://goelir.github.io/IPTVMac/support/ , privacy policy https://goelir.github.io/IPTVMac/privacy/ (Hebrew: /he/privacy/), source https://github.com/Goelir/IPTVMac, contact email as set in `scripts/site/build.py` (`CONTACT_EMAIL`).

---

## 1. Privacy policy (App content > Privacy policy)

URL: `https://goelir.github.io/IPTVMac/privacy/`

Before you submit: the page was written for the Mac and says "on your Mac" in several places and has an "Android version" bullet that mentions the GitHub update banner. For Play, ask the lead to add a "Google Play / Amazon Appstore version" bullet (no update check there, updates come from the store) and the words "your device" next to "your Mac". Play reads the policy and compares it with the Data safety form.

## 2. Ads (App content > Ads)

**Does your app contain ads? No.**

## 3. App access (App content > App access) (memory)

Choose **All or some functionality in my app is restricted**, then **Add new instructions**.
Name of the instruction: `Add the review playlist`
Paste this (it is the whole text, 1 field, plain text, under 1000 characters):

```
IPTVMac has no account or login, so no username or password is needed. It is a player: it contains no content and shows something only after the user adds a source. For review, use our open-licence playlist (Blender Foundation films, Creative Commons Attribution, 10 entries). With the TV remote (D-pad):
1. On first launch select "Add source" (OK).
2. Choose the "M3U" tab (D-pad right, OK).
3. Name: Review (type with the on-screen keyboard, or press OK on the field).
4. Playlist link: https://goelir.github.io/IPTVMac/review/ReviewPlaylist.m3u
5. Select "Next", then "Test connection" (it says Connected successfully), then "Save and sync".
6. Open the "Live" tab (D-pad up/down in the left menu): choose "Big Buck Bunny (HLS stream)" and press OK to play. Back returns to the list.
Movies has "Sintel Trailer (2010)"; Series has 3 entries. Search is in the left menu.
```

Tick nothing about "special locations or credentials": none are needed. If a reviewer cannot type a long address with a remote, the same playlist works on any phone with the APK; mention it in the console's free text if the field allows ("the Hebrew/English support page has the link as text to copy").

## 4. Content rating (App content > Content rating, IARC questionnaire) (memory)

Enter your email, then choose the category. My recommendation: **"All other app types"** / the utility-style category (the label changes: the old name was "Utility, Productivity, Communication or Other"). Reason: the app itself is a tool; the "Entertainment" category assumes the app ships entertainment content. If the console steers you to Entertainment, use it and keep the same answers: they are the same questions.

Answers (all describe the app as shipped; it has no content of its own):

| Question (paraphrased) | Answer |
|---|---|
| Violence (any kind, depicted or promoted by the app) | No |
| Blood, gore | No |
| Sexuality, nudity, sexual content | No |
| Profanity or crude humour | No |
| Fear, horror | No |
| Gambling or simulated gambling | No |
| Controlled substances (drugs, alcohol, tobacco) | No |
| Does the app allow users to interact or exchange content with each other (chat, sharing, user-generated content)? | No (favourites and history stay on the device) |
| Does the app share the user's location with other users? | No |
| Can users buy digital goods or content in the app? | No |
| Does the app provide unrestricted access to the internet or a web browser? | No. There is no browser and no web view. It opens only the playlist and stream addresses the user typed. The one Trailer link goes to the user's own browser outside the app. |
| Is the app a news or educational reference app? | No |

Expected result: the lowest age class in every region (PEGI 3 / ESRB Everyone or similar). That is a true description of the *app*, but not of what an IPTV source can deliver. Google Play has no "override to a higher rating" the way the App Store has (memory: you can only get a different rating by answering differently, or by an appeal to IARC). So the honest signal that this is for adults is the **Target audience: 18 and over** declaration below, the listing text ("use only sources you are authorized to access"), and the app's own welcome text. Do NOT tick "No" to any question just to keep the rating low where a real question about third-party or user-supplied content appears: if a question asks whether the app can show content that the developer does not control (some IARC versions have "does the app access third-party content that may be unrated"), answer **Yes**: it is true, and the rating rises to what the console computes.

## 5. Target audience and content (App content > Target audience) (memory)

- Target age group: tick **18 and over** only. Do not tick any group under 18.
- "Does your app appeal to children?" No.
- Store presence: "Is your app designed for children?" does not appear when only 18+ is chosen.
- Not a Families Policy app: do not join "Designed for Families".

Why 18+: IPTV lists in the real world often include adult channels. 18+ keeps the app out of the children's policy set and is the same decision as the 18+ override on iOS.

## 6. Data safety (App content > Data safety) (memory)

Recommended answers (my reading of Google's definitions; the owner confirms):

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| (everything after this is skipped by the console) | |

Why "No" is true: "collect" in the form means data transmitted off the device *to you or your partners*. The developer receives nothing: no server, no account, no analytics, crash-reporting or ads SDK (the Flutter app has no such dependency; see `flutter/pubspec.yaml`). Playlists, favourites, history, settings and the Xtream password stay on the device (the password in the Android Keystore through flutter_secure_storage). The only network traffic goes to servers the user typed in (the user's own provider), exactly like a browser or an FTP client. The provider is not the developer's partner and has no code in the app. Google's page lists data sent at the user's own request to a destination the user chose among the cases that are not "sharing" (memory: check the wording in the "Data collection and sharing" help page).

The conservative alternative, if you prefer to over-declare (Play policy bites harder on under-declaring than on over-declaring): answer **Yes** and declare only
- Personal info > **User IDs** (the Xtream username): Collected = yes, Shared = no, Purpose = **App functionality**, processed ephemerally = no, optional = no (it is entered by the user to use the app).
- Then "Is all of the user data collected by your app encrypted in transit?" must be **No**, because the app allows `http://` provider addresses (cleartext). Do not tick Yes.
- "Can users request that data be deleted?" **Yes**: deleting a source removes it, and uninstalling removes everything; the developer holds no copy.
I recommend the plain **No**, because the conservative form would publish "Data collected: User IDs" for an app that sends nothing to its developer, and that would contradict the privacy policy.

Other items on the page: Data safety needs the privacy policy URL (section 1). The form for the GitHub update check does not apply to the Play build if you disable that check there (see README, "App changes needed before submission").

## 7. Other declarations (App content)

| Page | Answer |
|---|---|
| Government apps | **No**, the app is not made by or for a government |
| Financial features | **None** of the listed features (no loans, banking, trading, crypto, payments) |
| Health | **No** health features. (If the console shows the "Health apps" declaration, tick "My app does not have any health features".) |
| News apps | **No**, not a news app |
| COVID-19 contact tracing and status | **Not** a contact tracing / status app |
| Data deletion (account deletion) | Not shown: no account. If asked "Does your app let users create an account?" **No** |
| Advertising ID | **No**, the app does not use the advertising ID (no AD_ID permission in the manifest; check the merged manifest after the final build with `bundletool dump manifest`) |
| Photo and video permissions | Not shown: the app requests none |
| Exact alarms / full-screen intents / VPN / accessibility | not used, nothing to declare |
| **Foreground service permissions** (Android 14, memory) | Declare **Media playback** (FOREGROUND_SERVICE_MEDIA_PLAYBACK: sound keeps playing with the screen off, with media notification controls) and **Data sync** (FOREGROUND_SERVICE_DATA_SYNC: a long download of a movie the user chose continues in the background). The console asks for a short description and a video link for each (unlisted YouTube video or a Drive link: a 30-second screen recording of playing a stream with the screen off, and of a download running). If the TV build removes downloads, remove the data sync service and its permission from the manifest first (lead) and skip that declaration. |

## 8. Store settings (Grow > Store presence > Store settings) (memory)

- App category: **Video Players & Editors** (Apps). Tags: video player, IPTV (pick what the list offers).
- Email: the contact address (shown publicly on the listing). Website: `https://goelir.github.io/IPTVMac/`. Phone: optional (needed for some account types, shown publicly: use none if allowed).
- External marketing: allow.

## 9. "Why this app is not a copyright problem" (declaration text)

Use this when Play asks, in the review notes field, in an appeal, or if a policy email arrives (Intellectual property / Deceptive behaviour). Keep the headings, they answer the questions a reviewer has.

```
IPTVMac is a general-purpose media player, like a browser or a video player. It does not contain, host, sell, link to or recommend any content, channel, playlist or provider. There is no default source and no provider list in the app, and the developer has no relationship with any IPTV provider and receives nothing from the app (no account, no server, no analytics).

How it works: the user types in a source that the user already has: an M3U playlist link or the Xtream Codes login of the user's own provider. The app downloads that list from the server the user chose and plays what that server serves to that user. Without such a source the app shows an empty welcome screen.

Authorization: the first-run welcome screen, the store listing, the website and the support page all say "Use only sources you are authorized to access." (The welcome screen says it only after the app change in README.md, "App changes needed before submission", item 2: today `onbWelcomeBody` does not. Do not paste this paragraph before that change is in the bundle you upload.) The app contains no code to bypass copy protection; DRM-protected streams (Widevine, FairPlay, PlayReady) do not play. It does not scrape, and it does not download from any public video site.

Everything we ship is licensed: the code is GPL-3.0 and owned by the developer; libmpv and FFmpeg are LGPL builds; the other libraries are listed in the in-app acknowledgements; the screenshots use invented titles and an open-licence film (Sintel, (c) Blender Foundation, CC BY 3.0, https://durian.blender.org).

For review we publish a playlist of open-licence films only (Blender Foundation: Big Buck Bunny, Sintel, Tears of Steel, Elephants Dream; Creative Commons Attribution): https://goelir.github.io/IPTVMac/review/ReviewPlaylist.m3u

Rights holders: if you believe a source that a user adds infringes your rights, the infringement is at the provider's server, which the developer neither operates nor can see. We will still answer any notice sent to the contact address on the Support page (https://goelir.github.io/IPTVMac/support/) and will cooperate with Google. Source code: https://github.com/Goelir/IPTVMac . Age: 18+ (target audience 18 and over).
```

The same text, shortened to fit a 500-character field:

```
IPTVMac is a general media player. It includes and recommends no content, channels, playlists or providers, and the developer receives nothing from it. Users add their own M3U link or Xtream login and are told to use only authorized sources; the app cannot play DRM-protected streams. For review: open-licence Blender Foundation films, https://goelir.github.io/IPTVMac/review/ReviewPlaylist.m3u . Contact: https://goelir.github.io/IPTVMac/support/ . Source: https://github.com/Goelir/IPTVMac
```

## 10. Release notes ("What's new")

`listing/en-US/release-notes.txt` and `listing/he-IL/release-notes.txt` (limit 500 characters each, memory). In the console they sit in the release page, between `<en-US>` and `<iw-IL>`-style tags (Play uses `iw-IL` for Hebrew, memory: check the language tag the console offers; some consoles show "Hebrew - עברית (iw-IL)").

## 11. Pre-launch report and "Android TV" declarations

- Play's pre-launch report runs the app on test devices; it will not see a TV remote flow. Do not worry about its crashes on non-TV devices if you only target TV, but check it.
- The TV form factor needs the manifest items listed in README.md, section "What the bundle must declare for TV".

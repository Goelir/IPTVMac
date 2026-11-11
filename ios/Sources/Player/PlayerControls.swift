import SwiftUI
import AVKit
import IPTVCore
import IPTVPlayer

// The controls of the player. One visual language, the Mac player's: white SF Symbols on dark translucent rounded surfaces over the
// picture. Landscape and iPad float a panel at the bottom; iPhone portrait puts the same controls under the video.

extension View {
    /// The floating dark translucent surface (the Mac player's control panel, as an iOS material).
    func playerSurface(radius: CGFloat = 20) -> some View {
        background {
            Color.black.opacity(0.62)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .overlay { RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white.opacity(0.12)) }
    }
}

struct PlayerPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PlayerButton: View {
    let symbol: String
    let label: String
    var font: Font = .title3
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(font).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
            .buttonStyle(PlayerPressStyle())
            .accessibilityLabel(label)
    }
}

/// AirPlay: the system route picker (a screen or a speaker), drawn in the player's white.
struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.tintColor = .white
        v.activeTintColor = .systemBlue
        v.prioritizesVideoDevices = true
        v.isAccessibilityElement = true
        v.accessibilityLabel = L("player.airplay")
        return v
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - Menus and buttons of the utility row

/// An icon (the compact floating panel) or an icon over a caption (the grid under the video in portrait).
struct UtilityLabel: View {
    let symbol: String
    let title: String
    let labeled: Bool
    var tint: Color = .white
    var body: some View {
        if labeled {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.title3).frame(height: 26)
                Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.75)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        } else {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
    }
}

struct SpeedButton: View {
    let player: PhonePlayer
    let labeled: Bool
    let action: () -> Void
    var body: some View {
        let tint: Color = player.speed == 1 ? .white : .yellow
        Button(action: action) {
            if labeled {
                VStack(spacing: 3) {
                    Text(PlaybackSpeed.label(player.speed)).font(.title3.weight(.bold).monospacedDigit()).frame(height: 26)
                    Text(L("player.speed")).font(.caption2).lineLimit(1).minimumScaleFactor(0.75)
                }
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text(PlaybackSpeed.label(player.speed)).font(.callout.weight(.bold).monospacedDigit()).foregroundStyle(tint)
                    .padding(.horizontal, 10).frame(minWidth: 44, minHeight: 30)
                    .background { RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.yellow.opacity(player.speed == 1 ? 0 : 0.18)) }
                    .overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(tint.opacity(0.5)) }
                    .frame(minHeight: 44)
            }
        }
        .buttonStyle(PlayerPressStyle())
        .accessibilityLabel(L("player.speed")).accessibilityValue(PlaybackSpeed.label(player.speed))
    }
}

struct SubtitleMenu: View {
    let player: PhonePlayer
    let labeled: Bool
    @Binding var importing: Bool
    @Binding var adjusting: Bool
    var body: some View {
        let subs = player.tracks.filter { $0.type == "sub" }
        Menu {
            Picker(L("player.subtitles"), selection: Binding(get: { player.subtitleSelection }, set: { player.selectSubtitle($0) })) {
                Text(L("player.off")).tag(0)
                ForEach(subs) { Text(TrackLabel.text(for: $0)).tag($0.id) }
            }
            Divider()
            Button { importing = true } label: { Label(L("player.addSubtitle"), systemImage: "doc.badge.plus") }
            Button { adjusting = true } label: { Label(L("player.subtitleAdjust"), systemImage: "textformat.size") }
        } label: {
            UtilityLabel(symbol: player.subtitleSelection == 0 ? "captions.bubble" : "captions.bubble.fill", title: L("player.subtitles"), labeled: labeled)
        }
        .menuOrder(.fixed)
        .accessibilityLabel(L("player.subtitles"))
    }
}

struct AudioMenu: View {
    let player: PhonePlayer
    let labeled: Bool
    var body: some View {
        let audio = player.tracks.filter { $0.type == "audio" }
        Menu {
            Picker(L("player.audio"), selection: Binding(get: { player.audioSelection }, set: { player.selectAudio($0) })) {
                ForEach(audio) { Text(TrackLabel.text(for: $0)).tag($0.id) }
            }
        } label: {
            UtilityLabel(symbol: "speaker.wave.2", title: L("player.audio"), labeled: labeled)
        }
        .menuOrder(.fixed)
        .disabled(audio.isEmpty)
        .accessibilityLabel(L("player.audio"))
    }
}

struct ScaleMenu: View {
    let player: PhonePlayer
    let labeled: Bool
    var body: some View {
        Menu {
            Picker(L("settings.videoScale"), selection: Binding(get: { player.videoScale }, set: { player.videoScale = $0; player.interact() })) {
                ForEach(VideoScale.allCases, id: \.self) { Text(player.scaleName($0)).tag($0) }
            }
        } label: {
            UtilityLabel(symbol: player.videoScale == .fit ? "rectangle.arrowtriangle.2.outward" : "rectangle.arrowtriangle.2.inward",
                         title: player.scaleName(player.videoScale), labeled: labeled)
        }
        .menuOrder(.fixed)
        .accessibilityLabel(L("settings.videoScale")).accessibilityValue(player.scaleName(player.videoScale))
    }
}

/// Marks of the series: where its intro starts and ends and where its credits start. Every episode then offers the skip buttons.
struct SkipMenu: View {
    let player: PhonePlayer
    let labeled: Bool
    var body: some View {
        if let sc = player.skipControls {
            Menu {
                Button(L("player.markIntroStart")) { sc.markIntroStart(position: player.position, duration: player.duration) }
                Button(L("player.markIntroEnd")) { sc.markIntroEnd(position: player.position, duration: player.duration) }
                Button(L("player.markCredits")) { sc.markCredits(position: player.position, duration: player.duration) }
                Divider()
                Button(L("player.skipForget"), role: .destructive) { sc.forget() }.disabled(sc.marks.isEmpty)
            } label: {
                UtilityLabel(symbol: sc.marks.isEmpty ? "forward.end" : "forward.end.fill", title: L("player.skipMenu"), labeled: labeled)
            }
            .menuOrder(.fixed)
            .accessibilityLabel(L("player.skipMenu"))
        }
    }
}

/// "Skip intro" / "Skip credits", over the picture while the marks of the series say so (and a short message after marking).
struct SkipOfferButton: View {
    let player: PhonePlayer
    var body: some View {
        if let sc = player.skipControls {
            VStack(alignment: .trailing, spacing: 8) {
                if let n = sc.notice {
                    Text(L(n == .saved ? "player.skipSaved" : "player.skipRefused")).font(.footnote).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .transition(.opacity)
                }
                if let offer = sc.offer, !player.upNext.isCounting {
                    Button { player.doSkip(offer) } label: {
                        Label(L(offer == .credits ? "player.skipCredits" : "player.skipIntro"), systemImage: "forward.end.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.black)
                            .padding(.horizontal, 16).padding(.vertical, 11).background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(PlayerPressStyle())
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: sc.offer)
            .animation(.easeInOut(duration: 0.2), value: sc.notice)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct SleepMenu: View {
    let player: PhonePlayer
    let labeled: Bool
    var body: some View {
        let left = player.sleepMinutesLeft
        Menu {
            Picker(L("player.sleep"), selection: Binding(get: { left == nil ? 0 : -1 }, set: { player.setSleep(minutes: $0) })) {
                Text(L("player.off")).tag(0)
                ForEach([15, 30, 45, 60, 90, 120], id: \.self) { Text(String(format: L("unit.minutes"), $0)).tag($0) }
            }
        } label: {
            UtilityLabel(symbol: left == nil ? "moon.zzz" : "moon.zzz.fill",
                         title: left.map { String(format: L("unit.minutesShort"), $0) } ?? L("player.sleep"), labeled: labeled,
                         tint: left == nil ? .white : .yellow)
        }
        .menuOrder(.fixed)
        .accessibilityLabel(L("player.sleep"))
        .accessibilityValue(left.map { String(format: L("unit.minutes"), $0) } ?? L("player.off"))
    }
}

/// Speed (movies only: a live stream cannot run faster than real time), subtitles, audio, aspect, sleep timer.
struct UtilityRow: View {
    let player: PhonePlayer
    var labeled = false
    @Binding var showSpeed: Bool
    @Binding var importing: Bool
    @Binding var adjusting: Bool
    var body: some View {
        HStack(spacing: labeled ? 8 : 0) {
            if !player.isLive { SpeedButton(player: player, labeled: labeled) { showSpeed = true; player.interact() }.frame(maxWidth: .infinity) }
            SubtitleMenu(player: player, labeled: labeled, importing: $importing, adjusting: $adjusting).frame(maxWidth: .infinity)
            AudioMenu(player: player, labeled: labeled).frame(maxWidth: .infinity)
            ScaleMenu(player: player, labeled: labeled).frame(maxWidth: .infinity)
            SkipMenu(player: player, labeled: labeled).frame(maxWidth: .infinity)
            SleepMenu(player: player, labeled: labeled).frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Transport

struct PlayPauseButton: View {
    let player: PhonePlayer
    var diameter: CGFloat = 72
    var body: some View {
        Button { if player.atEnd && !player.isLive { player.core.replay() } else { player.togglePause() } } label: {
            ZStack {
                Circle().fill(.black.opacity(0.55)).overlay(Circle().strokeBorder(.white.opacity(0.14)))
                if player.buffering && !player.paused {
                    ProgressView().controlSize(.large).tint(.white)
                } else {
                    Image(systemName: player.atEnd && !player.isLive ? "arrow.counterclockwise" : player.paused ? "play.fill" : "pause.fill")
                        .font(.system(size: diameter * 0.38, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .offset(x: player.paused && !player.atEnd ? diameter * 0.02 : 0)
                }
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(PlayerPressStyle())
        .accessibilityLabel(player.atEnd && !player.isLive ? L("player.replay") : L(player.paused ? "downloads.play" : "downloads.pause"))
    }
}

/// Skip back / play / skip forward for movies; previous channel / play / next channel for live.
struct TransportCluster: View {
    let player: PhonePlayer
    var compact = false
    var body: some View {
        let step = player.seekStep
        HStack(spacing: compact ? 20 : 40) {
            if player.isLive {
                PlayerButton(symbol: "backward.end.fill", label: L("player.channelPrev"), font: compact ? .title3 : .title2) { player.zap(-1) }
                    .opacity(player.canZapPrevious ? 1 : 0.35).disabled(!player.canZapPrevious)
            } else {
                PlayerButton(symbol: "gobackward.\(step)", label: String(format: L("player.skipBack"), String(format: L("unit.seconds"), step)),
                             font: compact ? .title2 : .largeTitle) { player.skip(by: -Double(step)); player.touchControls() }
            }
            PlayPauseButton(player: player, diameter: compact ? 56 : 72)
            if player.isLive {
                PlayerButton(symbol: "forward.end.fill", label: L("player.channelNext"), font: compact ? .title3 : .title2) { player.zap(1) }
                    .opacity(player.canZapNext ? 1 : 0.35).disabled(!player.canZapNext)
            } else {
                PlayerButton(symbol: "goforward.\(step)", label: String(format: L("player.skipForward"), String(format: L("unit.seconds"), step)),
                             font: compact ? .title2 : .largeTitle) { player.skip(by: Double(step)); player.touchControls() }
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
        .environment(\.layoutDirection, .leftToRight)      // playback controls are not mirrored in right-to-left languages (Apple's rule)
    }
}

/// Elapsed time, the bar, the time left.
struct SeekRow: View {
    let player: PhonePlayer
    let containerWidth: CGFloat
    var body: some View {
        HStack(spacing: 10) {
            Text(SeekBarMath.format(player.position)).frame(minWidth: 40, alignment: .trailing)
            PlayerSeekBar(position: player.position, duration: player.duration, preview: player.preview, containerWidth: containerWidth,
                          scrubbing: Binding(get: { player.scrubbing }, set: { player.scrubbing = $0 }),
                          onSeek: { player.seek(to: $0) }, onScrub: { player.previewAt($0) }, onSkip: { player.skip(by: $0 * Double(player.seekStep)) })
            Text("\u{2212}" + SeekBarMath.format(max(player.duration - player.position, 0))).frame(minWidth: 48, alignment: .leading)
        }
        .font(.caption.weight(.medium).monospacedDigit())
        .foregroundStyle(.white.opacity(0.9))
        .environment(\.layoutDirection, .leftToRight)      // the timeline runs left to right in every language
        .environment(\.layoutDirection, .leftToRight)      // the time bar stays left to right in Hebrew and Arabic
    }
}

// MARK: - Title, programme guide, up next, errors

/// Now / next of a live channel (when the provider has a guide), or the programme line under a movie's title.
struct ProgrammeLines: View {
    @Environment(PhoneModel.self) private var model
    let player: PhonePlayer
    var body: some View {
        let now = Date()
        let upcoming = model.schedule.filter { $0.end > now }
        if player.isLive, let cur = upcoming.first {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(L("epg.now")): \(cur.title)  \(cur.start.formatted(date: .omitted, time: .shortened))\u{2013}\(cur.end.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote).lineLimit(1)
                if upcoming.count > 1 {
                    Text("\(L("epg.next")): \(upcoming[1].title)  \(upcoming[1].start.formatted(date: .omitted, time: .shortened))")
                        .font(.footnote).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
            }
        }
    }
}

struct TitleBar: View {
    @Environment(PhoneModel.self) private var model
    let player: PhonePlayer
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button { player.onClose?() } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.55), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.12)))
                    .frame(width: 48, height: 48).contentShape(Rectangle())
            }
            .buttonStyle(PlayerPressStyle()).accessibilityLabel(L("player.close"))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(player.request.title).font(.headline).lineLimit(1)
                    if let q = player.quality { QualityBadge(label: q) }
                }
                ProgrammeLines(player: player)
            }
            .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
            Spacer(minLength: 8)
            if let item = player.request.item { DetailsButton(item: item); FavoriteButton(item: item) }
            if player.canPiP {
                PlayerButton(symbol: "pip.enter", label: L("player.pip")) { player.startPiP() }.accessibilityIdentifier("player.pip")
            }
            RoutePicker().frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
    }
}

/// Opens the details of what plays while it keeps playing: a movie's sheet, a series' screen (an episode's item is its series).
/// Nothing for a source without provider details (M3U) or a live channel.
struct DetailsButton: View {
    @Environment(PhoneModel.self) private var model
    @Environment(UIState.self) private var ui
    let item: Item
    var body: some View {
        if model.hasInfo(item) {
            PlayerButton(symbol: "info.circle", label: L("info.details")) { open(item, model: model, ui: ui) }
                .accessibilityIdentifier("player.details")
        }
    }
}

@MainActor func open(_ item: Item, model: PhoneModel, ui: UIState) {
    if item.type == .series { model.openSeries = item } else { ui.openInfo = item }
}

struct FavoriteButton: View {
    @Environment(PhoneModel.self) private var model
    let item: Item
    var body: some View {
        let fav = model.isFavorite(item)
        PlayerButton(symbol: fav ? "star.fill" : "star", label: L(fav ? "fav.remove" : "fav.add")) { model.toggleFavorite(item) }
            .foregroundStyle(fav ? Color.yellow : .white)
            .accessibilityIdentifier("player.favorite")
    }
}

struct UpNextCard: View {
    let player: PhonePlayer
    var body: some View {
        if let next = player.upNext.episode {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(L("next.title")): \(String(format: "S%02dE%02d", next.season, next.number)) \(next.title)").font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(String(format: L("next.in"), player.upNext.secondsLeft)).font(.caption).monospacedDigit().foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText(countsDown: true))
                }
                Spacer(minLength: 4)
                Button(L("next.now")) { player.playUpNextNow() }.buttonStyle(.borderedProminent).squared().controlSize(.small)
                Button(L("next.cancel")) { player.upNext.cancel() }.buttonStyle(.bordered).squared().controlSize(.small).tint(.white)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .playerSurface(radius: 16)
        }
    }
}

struct ErrorCard: View {
    let player: PhonePlayer
    var body: some View {
        if let message = player.error {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
                Text(message).font(.headline).multilineTextAlignment(.center)
                Text(L("player.errorHint")).font(.footnote).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button(L("player.retry")) { player.retry() }.buttonStyle(.borderedProminent).squared()
                    Button(L("player.close")) { player.onClose?() }.buttonStyle(.bordered).squared().tint(.white)
                }.padding(.top, 4)
            }
            .foregroundStyle(.white)
            .padding(20).frame(maxWidth: 420)
            .playerSurface(radius: 20)
            .padding(24)
            .accessibilityElement(children: .contain)
        }
    }
}

/// The picture's quality tag ("4K", "FHD", "HD", "SD") next to the title.
struct QualityBadge: View {
    let label: String
    var body: some View {
        Text(label).font(.caption2.weight(.heavy)).padding(.horizontal, 5).padding(.vertical, 1)
            .overlay { RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.white.opacity(0.85), lineWidth: 1) }
            .fixedSize()
    }
}

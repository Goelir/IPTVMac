import SwiftUI
import UIKit
import UniformTypeIdentifiers
import IPTVCore
import IPTVPlayer

/// The full-screen player. iPad and iPhone landscape: the picture fills the screen, a title bar and a floating panel fade in over it.
/// iPhone portrait: the picture on top, the title, programme and controls below it. Gestures live on the picture (GestureSurface),
/// the state in PhonePlayer; this view only lays it out. Always dark, like the system's video players.
struct PlayerScreen: View {
    @Environment(PhoneModel.self) private var model
    let player: PhonePlayer
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSpeed = false
    @State private var importing = false
    @State private var adjusting = false
    @State private var width: CGFloat = 0
    @State private var rotatedFromPortrait = false

    /// iPhone held upright: video on top, the rest below.
    private var split: Bool { vSize == .regular && hSize == .compact }
    private var visible: Bool { player.controlsVisible }
    /// The failure card stands alone: no bar of dead controls behind it.
    private var transportVisible: Bool { visible && player.error == nil }
    /// The up-next card has its own buttons: the big ones step aside while it counts down.
    private var clusterVisible: Bool { transportVisible && !player.upNext.isCounting }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if split { splitLayout } else { fullLayout }
            VolumeHost(view: player.levels.volumeView).frame(width: 1, height: 1).allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(visible && !split ? .automatic : .hidden)
        .coordinateSpace(name: "player")
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .sheet(isPresented: $showSpeed) { SpeedSheet(player: player) }
        .sheet(isPresented: $adjusting) { SubtitleAdjustSheet(player: player) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { if case .success(let u) = $0 { player.addSubtitle(u) } }
        .onChange(of: showSpeed || adjusting || importing) { _, open in
            player.sheetOpen = open
            if !open { player.touchControls() }
        }
        .task(id: player.request.id) {   // the guide of the channel being watched, refreshed every minute
            if let item = player.request.item, player.request.isLive { await model.watchSchedule(of: item) } else { model.schedule = [] }
        }
        .task {
            player.configure(model: model)
            rotatedFromPortrait = PlayerOrientation.enter()
            #if DEBUG
            try? await Task.sleep(for: .seconds(2.5))          // -playerSheet speed|subtitles: open a sheet for screenshots
            switch UserDefaults.standard.string(forKey: "playerSheet") { case "speed": showSpeed = true; case "subtitles": adjusting = true; default: break }
            #endif
        }
        .onDisappear { PlayerOrientation.leave(rotated: rotatedFromPortrait) }
        .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: player.upNext.episode?.id)
        .accessibilityAddTraits(.isModal)
    }

    /// A touch on any control keeps the controls up long enough to use a menu (a menu cannot say when it closes).
    private var touchDown: some Gesture { DragGesture(minimumDistance: 0).onChanged { _ in player.interact() } }

    private var handlers: GestureSurface.Handlers {
        .init(singleTap: { player.singleTap(side: $0) }, doubleTap: { player.doubleTap(side: $0) },
              scrubBegan: { player.scrubBegan() }, scrubChanged: { player.scrubChanged(translation: $0, width: $1) },
              scrubEnded: { player.scrubEnded(commit: $0) },
              levelBegan: { player.levelBegan(side: $0) }, levelChanged: { player.levelChanged(side: $0, translationY: $1, height: $2) },
              levelEnded: { player.levelEnded(side: $0, translationY: $1, velocityY: $2) },
              pinchEnded: { player.pinchEnded(scale: $0) }, hold: { player.hold($0) })
    }

    // MARK: Landscape and iPad

    private var fullLayout: some View {
        ZStack {
            VideoSurface(view: player.view).ignoresSafeArea()
            GestureSurface(handlers: handlers, live: player.isLive).ignoresSafeArea()
            Color.black.opacity(transportVisible ? 0.32 : 0).ignoresSafeArea().allowsHitTesting(false)   // the controls stay readable over a white picture
            PlayerHUD(player: player)
            VStack(spacing: 0) {
                TitleBar(player: player).padding(.horizontal, 10).padding(.top, 10)
                    .background(alignment: .top) {
                        LinearGradient(colors: [.black.opacity(0.7), .black.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 130).ignoresSafeArea(edges: .top).allowsHitTesting(false)
                    }
                    .offset(y: visible || reduceMotion ? 0 : -8)
                    .opacity(visible ? 1 : 0).allowsHitTesting(visible)
                    .simultaneousGesture(touchDown)
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    UpNextCard(player: player).frame(maxWidth: .infinity, alignment: .trailing)
                    SkipOfferButton(player: player)
                    bottomPanel
                        .offset(y: transportVisible || reduceMotion ? 0 : 8)
                        .opacity(transportVisible ? 1 : 0).allowsHitTesting(transportVisible)
                        .simultaneousGesture(touchDown)
                }
                .padding(.horizontal, 12).padding(.bottom, 6)
            }
            TransportCluster(player: player)
                .opacity(clusterVisible ? 1 : 0).allowsHitTesting(clusterVisible)
            ErrorCard(player: player)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: visible)
    }

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            if !player.isLive { SeekRow(player: player, containerWidth: width).padding(.horizontal, 6) }
            HStack(spacing: 0) {
                if player.isLive { LiveBadge(player: player).padding(.leading, 10) }
                UtilityRow(player: player, showSpeed: $showSpeed, importing: $importing, adjusting: $adjusting)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 2)
        .playerSurface()
        .frame(maxWidth: 720)
    }

    // MARK: iPhone portrait

    private var splitLayout: some View {
        GeometryReader { g in
            VStack(spacing: 0) {
                ZStack {
                    VideoSurface(view: player.view)
                    GestureSurface(handlers: handlers, live: player.isLive)
                    PlayerHUD(player: player)
                    VStack {
                        HStack {
                            Button { player.onClose?() } label: {
                                Image(systemName: "chevron.down").font(.body.weight(.semibold)).frame(width: 40, height: 40)
                                    .background(Color.black.opacity(0.55), in: Circle())
                                    .frame(width: 48, height: 48).contentShape(Rectangle())
                            }
                            .buttonStyle(PlayerPressStyle()).accessibilityLabel(L("player.close"))
                            Spacer()
                            RoutePicker().frame(width: 44, height: 44)
                        }
                        .padding(.horizontal, 6)
                        Spacer()
                        if !player.isLive { SeekRow(player: player, containerWidth: width).padding(.horizontal, 12) }
                    }
                    .foregroundStyle(.white)
                    .background {
                        LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0), .init(color: .clear, location: 0.38),
                                               .init(color: .clear, location: 0.6), .init(color: .black.opacity(0.75), location: 1)],
                                       startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
                    }
                    .offset(y: visible || reduceMotion ? 0 : 6)
                    .opacity(visible ? 1 : 0).allowsHitTesting(visible)
                    TransportCluster(player: player, compact: true).opacity(clusterVisible ? 1 : 0).allowsHitTesting(clusterVisible)
                    VStack { Spacer(); UpNextCard(player: player).padding(.horizontal, 8).padding(.bottom, 44) }
                    VStack { Spacer(); SkipOfferButton(player: player).padding(.horizontal, 10).padding(.bottom, 52) }
                    ErrorCard(player: player).scaleEffect(0.85)
                }
                .frame(height: g.size.width * 9 / 16)
                .clipped()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: visible)
                infoPanel
            }
        }
    }

    private var infoPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(player.request.title).font(.title3.weight(.semibold)).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                        if let q = player.quality { QualityBadge(label: q) }
                    }
                    ProgrammeLines(player: player).foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                    if !player.isLive { SpeedButton(player: player, labeled: true) { showSpeed = true; player.interact() } }
                    SubtitleMenu(player: player, labeled: true, importing: $importing, adjusting: $adjusting)
                    AudioMenu(player: player, labeled: true)
                    ScaleMenu(player: player, labeled: true)
                    SleepMenu(player: player, labeled: true)
                    if let item = player.request.item { DetailsTile(item: item); FavoriteTile(item: item) }
                }
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// "Live": a tap reloads the channel, which starts it again at the live edge (after a pause or a long buffer it is behind).
struct LiveBadge: View {
    let player: PhonePlayer
    var body: some View {
        Button { player.retry(); player.touchControls() } label: {
            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text(L("player.live")).font(.caption.weight(.bold))
            }
            .padding(.vertical, 8).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.white).fixedSize()
    }
}

/// The details tile of the portrait grid (the landscape title bar has an info button).
private struct DetailsTile: View {
    @Environment(PhoneModel.self) private var model
    @Environment(UIState.self) private var ui
    let item: IPTVCore.Item
    var body: some View {
        if model.hasInfo(item) {
            Button { open(item, model: model, ui: ui) } label: { UtilityLabel(symbol: "info.circle", title: L("info.details"), labeled: true) }
                .buttonStyle(PlayerPressStyle())
                .accessibilityLabel(L("info.details"))
        }
    }
}

/// The favorite toggle as a tile of the portrait grid (the landscape title bar has a plain star).
private struct FavoriteTile: View {
    @Environment(PhoneModel.self) private var model
    let item: IPTVCore.Item
    var body: some View {
        let fav = model.isFavorite(item)
        Button { model.toggleFavorite(item) } label: {
            UtilityLabel(symbol: fav ? "star.fill" : "star", title: L(fav ? "fav.remove" : "fav.add"), labeled: true, tint: fav ? .yellow : .white)
        }
        .buttonStyle(PlayerPressStyle())
        .accessibilityLabel(L(fav ? "fav.remove" : "fav.add"))
    }
}

private struct VideoSurface: UIViewRepresentable {
    let view: MPVVideoView
    func makeUIView(context: Context) -> MPVVideoView { view }
    func updateUIView(_ uiView: MPVVideoView, context: Context) {}
}

/// The MPVolumeView that lets the volume gesture change the system volume (it also keeps the system volume HUD from covering the picture).
private struct VolumeHost: UIViewRepresentable {
    let view: UIView
    /// SwiftUI puts the view at the centre of the screen: inside a clipping box, parked far outside it, its slider thumb (a white dot) cannot show.
    func makeUIView(context: Context) -> UIView {
        let box = UIView()
        box.clipsToBounds = true
        box.isUserInteractionEnabled = false
        view.frame = CGRect(x: -2000, y: -2000, width: 10, height: 10)
        box.addSubview(view)
        return box
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Rotation: an iPhone starts a video in landscape (the picture fills the screen) and goes back to portrait when it closes; after that the
/// player follows the device. iPad is left alone. Switched off with the `playerStartsLandscape` default (no settings screen for it).
@MainActor enum PlayerOrientation {
    private static var scene: UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    /// True when the interface was turned from portrait to landscape.
    static func enter() -> Bool {
        guard let scene else { return false }
        let now = scene.effectiveGeometry.interfaceOrientation
        #if DEBUG
        if let forced = UserDefaults.standard.string(forKey: "playerOrientation") {      // screenshots and UI tests, any device
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: forced == "landscape" ? .landscape : .portrait)) { _ in }
            return false
        }
        #endif
        guard UIDevice.current.userInterfaceIdiom == .phone, now.isPortrait,
              UserDefaults.standard.object(forKey: "playerStartsLandscape") as? Bool ?? true else { return false }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { _ in }
        return true
    }

    static func leave(rotated: Bool) {
        guard rotated, let scene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
        Task { try? await Task.sleep(for: .milliseconds(600)); scene.requestGeometryUpdate(.iOS(interfaceOrientations: .allButUpsideDown)) { _ in } }
    }
}

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import IPTVPlayer

/// Hosts the player's single video view. The view is moved here (and to the PiP window), never recreated.
struct PlayerSurface: NSViewRepresentable {
    let model: PlayerModel
    /// Asked at attach time (not captured): while the PiP panel owns the video, SwiftUI still refreshes the main
    /// window's old surface (with its old inputs, e.g. during the full-screen transition) and it must not steal
    /// the view back, or the PiP window goes black.
    var active: () -> Bool = { true }
    func makeNSView(context: Context) -> NSView { let h = NSView(); if active() { attach(h) }; return h }
    func updateNSView(_ h: NSView, context: Context) { if active() { attach(h) } }
    static func dismantleNSView(_ h: NSView, coordinator: ()) { h.subviews.forEach { $0.removeFromSuperview() } }
    private func attach(_ h: NSView) {
        let v = model.videoView
        guard v.superview !== h else { return }
        v.removeFromSuperview()
        v.frame = h.bounds
        v.autoresizingMask = [.width, .height]
        h.addSubview(v)
    }
}

struct PlayerScreen: View {
    @Environment(AppModel.self) var model
    let request: PlayRequest
    let pm: PlayerModel
    @State private var showCatchup = false
    @State private var importing = false
    @FocusState private var focused: Bool
    @State private var showBars = true
    @State private var hideTask: Task<Void, Never>?
    @State private var showSpeed = false
    @AppStorage("subScale") private var subScale = 1.0
    @AppStorage("subDelay") private var subDelay = 0.0

    var body: some View {
        ZStack {
            Color.black
            PlayerSurface(model: pm, active: { [model] in !model.pip })
            if let err = pm.error {
                VStack(spacing: 12) {
                    Text(err).foregroundStyle(.white)
                    Text(L("player.errorHint")).font(.caption).foregroundStyle(.white.opacity(0.7))
                    Button(L("player.retry")) { pm.retry() }
                }
            }
            if let next = model.upNext {
                VStack {
                    Spacer()
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(L("next.title")): \(String(format: "S%02dE%02d", next.season, next.number)) \(next.title)").lineLimit(1)
                            Text(String(format: L("next.in"), model.upNextSeconds)).font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                        Button(L("next.now")) { model.playUpNextNow() }.buttonStyle(.borderedProminent)
                        Button(L("next.cancel")) { model.cancelUpNext() }
                    }
                    .padding(14).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                    .padding(.bottom, 90)
                }
            }
            VStack {
                HStack {
                    Button { model.stopPlayback() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.title).lineLimit(1)
                        epgLines
                    }
                    Spacer()
                    if let item = request.item {
                        Button { model.toggleFavorite(item) } label: {
                            Image(systemName: model.isFavorite(item) ? "star.fill" : "star").font(.title2)
                                .foregroundStyle(model.isFavorite(item) ? .yellow : .white)
                        }.buttonStyle(.plain).help(L(model.isFavorite(item) ? "fav.remove" : "fav.add"))
                    }
                }.padding().background(.black.opacity(0.5))
                Spacer()
                controls
            }
            .foregroundStyle(.white)
            .opacity(barsVisible ? 1 : 0).allowsHitTesting(barsVisible)
            .animation(.easeInOut(duration: 0.2), value: barsVisible)
        }
        .onContinuousHover { if case .active = $0 { revealBars() } }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true; revealBars() }
        .onKeyPress(.escape) { model.stopPlayback(); return .handled }
        .onKeyPress(.space) { revealBars(); pm.mpv.togglePause(); return .handled }
        .onKeyPress(.leftArrow) { revealBars(); pm.mpv.seek(by: -10); return .handled }
        .onKeyPress(.rightArrow) { revealBars(); pm.mpv.seek(by: 10); return .handled }
        .onKeyPress("2") { if !request.isLive { revealBars(); pm.toggleDoubleSpeed() }; return .handled }
        .onKeyPress("[") { if !request.isLive { revealBars(); pm.stepSpeed(up: false) }; return .handled }
        .onKeyPress("]") { if !request.isLive { revealBars(); pm.stepSpeed(up: true) }; return .handled }
        .onKeyPress("f") { NSApp.keyWindow?.toggleFullScreen(nil); return .handled }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            providers.first?.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                if let d = data as? Data, let u = URL(dataRepresentation: d, relativeTo: nil) { Task { @MainActor in pm.mpv.addSubtitle(u) } }
            }
            return true
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { r in
            if case .success(let u) = r {
                let access = u.startAccessingSecurityScopedResource()
                pm.mpv.addSubtitle(u)
                if access { u.stopAccessingSecurityScopedResource() }
            }
        }
        .sheet(isPresented: $showCatchup) {
            if let item = request.item {
                CatchupView(item: item) { url, title in
                    showCatchup = false
                    model.startPlayback(PlayRequest(title: title, url: url, isLive: false, item: nil))
                }
            }
        }
        .task {   // SwiftUI re-applies the toolbar whenever its content changes, so keep the full-screen state enforced
            while !Task.isCancelled { model.updateToolbar(); try? await Task.sleep(for: .milliseconds(300)) }
        }
        .onDisappear { model.updateToolbar() }
        .task(id: request.id) { if let item = request.item, request.isLive { await model.watchSchedule(of: item) } else { model.schedule = [] } }
        .onChange(of: subScale) { pm.applySubtitleStyle() }
        .onChange(of: subDelay) { pm.applySubtitleStyle() }
        .onChange(of: showSpeed) { if !showSpeed { focused = true; revealBars() } }   // the popover had the keyboard focus and the bar's 3 s timer
    }

    /// Now / next from the channel's EPG (live channels only; empty when the provider has no guide).
    @ViewBuilder private var epgLines: some View {
        let now = Date()
        let upcoming = model.schedule.filter { $0.end > now }
        if request.isLive, let cur = upcoming.first {
            Text("\(L("epg.now")): \(cur.title)  \(cur.start.formatted(date: .omitted, time: .shortened))–\(cur.end.formatted(date: .omitted, time: .shortened))")
                .font(.caption).lineLimit(1)
            if upcoming.count > 1 {
                Text("\(L("epg.next")): \(upcoming[1].title)  \(upcoming[1].start.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            }
        }
    }

    private var barsVisible: Bool { showBars || showSpeed || pm.paused || pm.error != nil }

    /// Title bar and controls fade out after 3 s without mouse movement, so a full-screen video shows nothing on top.
    private func revealBars() {
        showBars = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !showSpeed else { return }
            showBars = false
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button { pm.mpv.togglePause() } label: { Image(systemName: pm.paused ? "play.fill" : "pause.fill") }
            if !request.isLive {
                Slider(value: Binding(get: { pm.position }, set: { pm.mpv.seek(to: $0) }), in: 0...max(pm.duration, 1))
                Text("\(fmt(pm.position)) / \(fmt(pm.duration))").monospacedDigit().font(.caption)
            } else { Spacer() }
            if !request.isLive {   // a live stream cannot run faster than real time
                SpeedButton(speed: pm.speed, set: pm.setSpeed, open: $showSpeed)
            }
            trackMenu(type: "sub", title: L("player.subtitles"), prop: "sid", icon: "captions.bubble")
            trackMenu(type: "audio", title: L("player.audio"), prop: "aid", icon: "speaker.wave.2")
            if request.item?.tvArchive == true && request.isLive {
                Button { showCatchup = true } label: { Image(systemName: "clock.arrow.circlepath") }.help(L("player.catchup"))
            }
            Button { model.enterPiP() } label: { Image(systemName: "pip.enter") }.help(L("player.pip"))
            Button { NSApp.keyWindow?.toggleFullScreen(nil) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help(L("player.fullscreen"))
        }
        .buttonStyle(.plain).font(.title3).padding().background(.black.opacity(0.5))
    }

    private func label(_ t: Track) -> String {
        let name = [t.lang, t.title].compactMap { $0 }.joined(separator: " ")
        return (t.selected ? "✓ " : "") + (name.isEmpty ? "#\(t.id)" : name)
    }

    private func trackMenu(type: String, title: String, prop: String, icon: String) -> some View {
        Menu {
            if type == "sub" { Button(L("player.off")) { pm.mpv.setProperty("sid", "no") } }
            ForEach(pm.tracks.filter { $0.type == type }) { t in
                Button(label(t)) { pm.mpv.setProperty(prop, String(t.id)) }
            }
            if type == "sub" { Divider(); Button(L("player.addSubtitle")) { importing = true } }
        } label: { Image(systemName: icon) }
        .menuStyle(.borderlessButton).fixedSize().help(title)
    }

    private func fmt(_ s: Double) -> String {
        let t = Int(max(s, 0)); return String(format: "%d:%02d:%02d", t / 3600, t % 3600 / 60, t % 60)
    }
}

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import IPTVPlayer

/// Hosts the player's single video view. The view is moved here (and to the PiP window), never recreated.
struct PlayerSurface: NSViewRepresentable {
    let model: PlayerModel
    func makeNSView(context: Context) -> NSView { let h = NSView(); attach(h); return h }
    func updateNSView(_ h: NSView, context: Context) { attach(h) }
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
    @AppStorage("subScale") private var subScale = 1.0
    @AppStorage("subDelay") private var subDelay = 0.0

    var body: some View {
        ZStack {
            Color.black
            PlayerSurface(model: pm)
            if let err = pm.error {
                VStack(spacing: 12) {
                    Text(err).foregroundStyle(.white)
                    Text(L("player.errorHint")).font(.caption).foregroundStyle(.white.opacity(0.7))
                    Button(L("player.retry")) { pm.retry() }
                }
            }
            VStack {
                HStack {
                    Button { model.stopPlayback() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }.buttonStyle(.plain)
                    Text(request.title).lineLimit(1)
                    Spacer()
                }.padding().background(.black.opacity(0.5))
                Spacer()
                controls
            }
            .foregroundStyle(.white)
        }
        .ignoresSafeArea()
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(.escape) { model.stopPlayback(); return .handled }
        .onKeyPress(.space) { pm.mpv.togglePause(); return .handled }
        .onKeyPress(.leftArrow) { pm.mpv.seek(by: -10); return .handled }
        .onKeyPress(.rightArrow) { pm.mpv.seek(by: 10); return .handled }
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
        .onChange(of: subScale) { pm.applySubtitleStyle() }
        .onChange(of: subDelay) { pm.applySubtitleStyle() }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button { pm.mpv.togglePause() } label: { Image(systemName: pm.paused ? "play.fill" : "pause.fill") }
            if !request.isLive {
                Slider(value: Binding(get: { pm.position }, set: { pm.mpv.seek(to: $0) }), in: 0...max(pm.duration, 1))
                Text("\(fmt(pm.position)) / \(fmt(pm.duration))").monospacedDigit().font(.caption)
            } else { Spacer() }
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

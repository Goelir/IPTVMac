import SwiftUI
import AppKit
import IPTVCore

struct OnboardingView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    let isFirstRun: Bool
    @State private var step = 0
    @State private var kind: AccountKind = .xtream
    @State private var name = ""
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var status: String?
    @State private var ok = false
    @State private var busy = false
    @State private var saving = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var forward = true
    @State private var logoShown = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: step == 0 ? .center : .leading, spacing: 16) {
                switch step {
                case 0: welcome
                case 1: source
                default: testStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: step == 0 ? .center : .topLeading)
            .id(step)
            .transition(stepTransition)
            ZStack {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(i == step ? Color.accentColor : Color.primary.opacity(0.18))
                            .frame(width: i == step ? 18 : 6, height: 6)
                    }
                }.accessibilityHidden(true)
                HStack {
                    if !isFirstRun { Button(L("player.close")) { dismiss() } }
                    Spacer()
                    if step > 0 { Button(L("onb.back")) { go(-1); ok = false; status = nil }.disabled(saving) }
                    if step < 2 {
                        Button(L("onb.next")) { go(1) }.disabled(step == 1 && !formValid)
                            
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button(L("onb.save")) { Task { saving = true; await save(); saving = false } }.buttonStyle(.borderedProminent).disabled(!ok || saving)
                    }
                }
            }
        }
        .padding(28).frame(minWidth: 520, minHeight: 420)
        .clipped()
        .onAppear { withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) { logoShown = true } }
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let edge: Edge = forward ? .trailing : .leading
        return .asymmetric(insertion: .move(edge: edge).combined(with: .opacity),
                           removal: .move(edge: edge == .trailing ? .leading : .trailing).combined(with: .opacity))
    }

    private func go(_ delta: Int) {
        forward = delta > 0
        withAnimation(.smooth(duration: 0.3)) { step += delta }
    }

    @ViewBuilder private var welcome: some View {
        if let url = l10nBundle.url(forResource: "logo", withExtension: "png"), let img = NSImage(contentsOf: url) {
            Image(nsImage: img).resizable().scaledToFit().frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                .scaleEffect(logoShown || reduceMotion ? 1 : 0.88).opacity(logoShown || reduceMotion ? 1 : 0)
                .accessibilityHidden(true)
        }
        Text(L("onb.welcome.title")).font(.largeTitle.weight(.semibold)).multilineTextAlignment(.center)
        Text(L("onb.welcome.body")).font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 400)
    }

    @ViewBuilder private var source: some View {
        Text(L("onb.where.title")).font(.title.weight(.semibold))
        Picker(L("field.kind"), selection: $kind) {
            Text(L("kind.xtream")).tag(AccountKind.xtream)
            Text(L("kind.m3u")).tag(AccountKind.m3u)
        }.pickerStyle(.segmented)
        Text(kind == .xtream ? L("onb.where.xtream") : L("onb.where.m3u")).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        Form {
            TextField(L("field.name"), text: $name)
            if kind == .xtream {
                TextField(L("field.server"), text: $server, prompt: Text("http://host:8080"))
                TextField(L("field.username"), text: $username)
                SecureField(L("field.password"), text: $password)
            } else {
                TextField(L("field.url"), text: $url, prompt: Text("http://example.com/list.m3u"))
            }
        }
        .motion(value: kind)
    }

    @ViewBuilder private var testStep: some View {
        Text(L("onb.test")).font(.title.weight(.semibold))
        HStack {
            Button(L("onb.test")) { Task { await test() } }.disabled(busy)
            if busy { ProgressView().controlSize(.small) }
        }
        if let status {
            Label(status, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? .green : .red).transition(.opacity)
        }
    }

    private var formValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (kind == .xtream ? !server.isEmpty && !username.isEmpty : !url.isEmpty)
    }

    private func test() async {
        busy = true; ok = false; status = nil
        defer { busy = false }
        do {
            if kind == .xtream {
                guard let u = XtreamURLs(server: server, username: username, password: password) else { throw IPTVError.badConfig }
                try await XtreamClient(urls: u).authenticate()
            } else {
                guard let u = URL(string: url.trimmingCharacters(in: .whitespaces)), u.scheme != nil, u.host != nil else { throw IPTVError.badConfig }
                var r = URLRequest(url: u); r.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
                let (d, _) = try await apiSession.data(for: r)
                guard String(decoding: d, as: UTF8.self).drop(while: { $0.isWhitespace || $0 == "\u{FEFF}" }).hasPrefix("#EXTM3U")
                else { throw IPTVError.badResponse }
            }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { ok = true; status = L("onb.test.ok") }
        } catch { withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { status = "\(L("onb.test.fail")): \(error.localizedDescription)" } }
    }

    private func save() async {
        let a = kind == .xtream
            ? Account(name: name, kind: .xtream, server: server, username: username)
            : Account(name: name, kind: .m3u, url: url)
        await model.addAccount(a, password: kind == .xtream ? password : nil)
        finish()
    }

    /// On first run this view IS the window's root content: dismiss() there closes the whole window (looks like a crash).
    /// RootView swaps to the main UI by itself once an account exists, so only the sheet variant is dismissed.
    private func finish() { if !isFirstRun { dismiss() } }
}

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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch step {
            case 0:
                if let url = l10nBundle.url(forResource: "logo", withExtension: "png"), let img = NSImage(contentsOf: url) {
                    Image(nsImage: img).resizable().scaledToFit().frame(width: 120, height: 120)
                }
                Text(L("onb.welcome.title")).font(.largeTitle)
                Text(L("onb.welcome.body"))
            case 1:
                Text(L("onb.where.title")).font(.title)
                Picker(L("field.kind"), selection: $kind) {
                    Text(L("kind.xtream")).tag(AccountKind.xtream)
                    Text(L("kind.m3u")).tag(AccountKind.m3u)
                }.pickerStyle(.segmented)
                Text(kind == .xtream ? L("onb.where.xtream") : L("onb.where.m3u")).foregroundStyle(.secondary)
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
            default:
                Text(L("onb.test")).font(.title)
                HStack {
                    Button(L("onb.test")) { Task { await test() } }.disabled(busy)
                    if busy { ProgressView().controlSize(.small) }
                }
                if let status { Text(status).foregroundStyle(ok ? .green : .red) }
            }
            Spacer()
            HStack {
                if !isFirstRun { Button(L("player.close")) { dismiss() } }
                Spacer()
                if step > 0 { Button(L("onb.back")) { step -= 1; ok = false; status = nil }.disabled(saving) }
                if step < 2 {
                    Button(L("onb.next")) { step += 1 }.disabled(step == 1 && !formValid)
                } else {
                    Button(L("onb.save")) { Task { saving = true; await save(); saving = false } }.buttonStyle(.borderedProminent).disabled(!ok || saving)
                }
            }
        }
        .padding(28).frame(minWidth: 520, minHeight: 420)
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
            ok = true; status = L("onb.test.ok")
        } catch { status = "\(L("onb.test.fail")): \(error.localizedDescription)" }
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

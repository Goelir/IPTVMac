import SwiftUI
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch step {
            case 0:
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
                if step > 0 { Button(L("onb.back")) { step -= 1; ok = false; status = nil } }
                if step < 2 {
                    Button(L("onb.next")) { step += 1 }.disabled(step == 1 && !formValid)
                } else {
                    Button(L("onb.save")) { Task { await save() } }.buttonStyle(.borderedProminent).disabled(!ok)
                }
            }
        }
        .padding(28).frame(minWidth: 520, minHeight: 420)
    }

    private var formValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (kind == .xtream ? !server.isEmpty && !username.isEmpty && !password.isEmpty : !url.isEmpty)
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
        dismiss()
    }
}

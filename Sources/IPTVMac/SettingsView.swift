import SwiftUI
import IPTVCore

struct SettingsView: View {
    @Environment(AppModel.self) var model
    @AppStorage("prefSubLang") private var subLang = ""
    @AppStorage("prefAudioLang") private var audioLang = ""
    @AppStorage("subScale") private var subScale = 1.0
    @AppStorage("subDelay") private var subDelay = 0.0
    @State private var editing: Account?
    @State private var newPassword = ""

    var body: some View {
        Form {
            Section(L("settings.accounts")) {
                ForEach(model.accounts) { a in
                    HStack {
                        Text(a.name)
                        Spacer()
                        if a.kind == .xtream { Button(L("settings.changePassword")) { newPassword = ""; editing = a } }
                        Button(L("settings.delete"), role: .destructive) { model.deleteAccount(a) }
                    }
                }
                Button(L("account.add")) { model.showGuide = true }
            }
            Section {
                TextField(L("settings.language.sub"), text: $subLang, prompt: Text("he,en"))
                TextField(L("settings.language.audio"), text: $audioLang, prompt: Text("he,en"))
                Slider(value: $subScale, in: 0.5...3) { Text("\(L("settings.subscale")): \(subScale, specifier: "%.1f")") }
                Stepper("\(L("settings.subdelay")): \(subDelay, specifier: "%.1f")", value: $subDelay, in: -30...30, step: 0.5)
            }
            Button(L("settings.guide")) { model.showGuide = true }
        }
        .formStyle(.grouped).frame(width: 480).padding()
        .sheet(item: $editing) { a in
            VStack(alignment: .leading, spacing: 12) {
                Text(a.name).font(.headline)
                SecureField(L("settings.newPassword"), text: $newPassword)
                HStack {
                    Spacer()
                    Button(L("player.close")) { editing = nil }
                    Button(L("onb.save")) {
                        if let id = a.id, !newPassword.isEmpty {
                            try? model.secrets.setPassword(newPassword, for: id)
                            model.account = a
                            Task { await model.sync() }
                        }
                        editing = nil
                    }.buttonStyle(.borderedProminent).disabled(newPassword.isEmpty)
                }
            }.padding(24).frame(width: 360)
        }
    }
}

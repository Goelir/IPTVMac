import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) var model
    @AppStorage("prefSubLang") private var subLang = ""
    @AppStorage("prefAudioLang") private var audioLang = ""
    @AppStorage("subScale") private var subScale = 1.0
    @AppStorage("subDelay") private var subDelay = 0.0

    var body: some View {
        Form {
            Section(L("settings.accounts")) {
                ForEach(model.accounts) { a in
                    HStack {
                        Text(a.name)
                        Spacer()
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
    }
}

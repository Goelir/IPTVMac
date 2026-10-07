import SwiftUI
import IPTVCore
import IPTVPlayer

/// One tab per topic; each tab is its own file-level view so the settings can grow without one giant form.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label(L("settings.tab.general"), systemImage: "gearshape") }
            PlayerSettings().tabItem { Label(L("settings.tab.player"), systemImage: "play.rectangle") }
            PlaylistSettings().tabItem { Label(L("settings.tab.playlists"), systemImage: "list.bullet.rectangle") }
        }
        .frame(width: 540, height: 500)
    }
}

struct GeneralSettings: View {
    @Environment(AppModel.self) var model
    @AppStorage("autoCheckUpdates") private var autoCheck = true
    @AppStorage("autoInstallUpdates") private var autoInstall = true

    var body: some View {
        Form {
            Section(L("downloads.title")) {
                HStack {
                    Text(model.downloads.folderPath ?? L("downloads.notChosen")).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                    Spacer()
                    Button(L("downloads.change")) { model.downloads.chooseFolder() }
                }
            }
            Section {
                Text(String(format: L("update.current"), model.currentVersion)).foregroundStyle(.secondary)
                Toggle(L("update.auto"), isOn: $autoCheck)
                Toggle(L("update.autoInstall"), isOn: $autoInstall).disabled(!autoCheck)
                HStack {
                    Button(L("update.checkNow")) { Task { await model.checkForUpdates(manual: true) } }
                    switch model.updateStatus {
                    case .upToDate: Text(L("update.upToDate")).foregroundStyle(.secondary)
                    case .devBuild: Text(L("update.devBuild")).foregroundStyle(.secondary)
                    case .downloading: ProgressView().controlSize(.small)
                    case .ready: Text(String(format: L("update.ready"), model.update?.version ?? "")).foregroundStyle(.green)
                    case .available: Text(String(format: L("update.available"), model.update?.version ?? ""))
                    case .failed(let m): Text(m).foregroundStyle(.red).lineLimit(2)
                    case .none: EmptyView()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct PlayerSettings: View {
    static let seekSteps = [5, 10, 15, 30, 60]
    @AppStorage("prefSubLang") private var subLang = ""
    @AppStorage("prefAudioLang") private var audioLang = ""
    @AppStorage("subScale") private var subScale = 1.0
    @AppStorage("subDelay") private var subDelay = 0.0
    @AppStorage("openFullscreen") private var openFullscreen = true
    @AppStorage("autoNextEpisode") private var autoNext = true
    @AppStorage("seekStep") private var seekStep = 10
    @AppStorage("barsHideSeconds") private var barsHide = 3
    @AppStorage("showClock") private var showClock = false
    @AppStorage("videoScale") private var videoScale = VideoScale.fit
    @AppStorage("bufferSize") private var bufferSize = BufferSize.normal

    var body: some View {
        Form {
            Section {
                Toggle(L("settings.fullscreen"), isOn: $openFullscreen)
                Toggle(L("settings.autoNext"), isOn: $autoNext)
                Toggle(L("settings.clock"), isOn: $showClock)
            }
            Section {
                Picker(L("settings.seekStep"), selection: $seekStep) {
                    ForEach(Self.seekSteps, id: \.self) { Text(String(format: L("unit.seconds"), $0)).tag($0) }
                }
                Picker(L("settings.barsHide"), selection: $barsHide) {
                    ForEach([2, 3, 5, 10], id: \.self) { Text(String(format: L("unit.seconds"), $0)).tag($0) }
                    Text(L("settings.never")).tag(0)
                }
            }
            Section {
                Picker(L("settings.videoScale"), selection: $videoScale) {
                    ForEach(VideoScale.allCases, id: \.self) { Text(L("settings.scale.\($0.rawValue)")).tag($0) }
                }
                Text(L("settings.videoScaleHint")).font(.caption).foregroundStyle(.secondary)
                Picker(L("settings.buffer"), selection: $bufferSize) {
                    ForEach(BufferSize.allCases, id: \.self) { Text(L("settings.buffer.\($0.rawValue)")).tag($0) }
                }
                Text(L("settings.bufferHint")).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                TextField(L("settings.language.sub"), text: $subLang, prompt: Text("he,en"))
                TextField(L("settings.language.audio"), text: $audioLang, prompt: Text("he,en"))
                Slider(value: $subScale, in: 0.5...3) { Text("\(L("settings.subscale")): \(subScale, specifier: "%.1f")") }
                Stepper("\(L("settings.subdelay")): \(subDelay, specifier: "%.1f")", value: $subDelay, in: -30...30, step: 0.5)
            }
        }
        .formStyle(.grouped)
    }
}

struct PlaylistSettings: View {
    @Environment(AppModel.self) var model
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
            Button(L("settings.guide")) { model.showGuide = true }
        }
        .formStyle(.grouped)
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

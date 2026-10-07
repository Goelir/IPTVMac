import SwiftUI
import UniformTypeIdentifiers
import IPTVCore

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
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("hiddenCategoryWords") private var hiddenWords = ""
    @State private var language = InterfaceLanguage.current

    var body: some View {
        Form {
            Section {
                Picker(L("settings.appearance"), selection: $appearance) {
                    Text(L("settings.system")).tag("system")
                    Text(L("appearance.light")).tag("light")
                    Text(L("appearance.dark")).tag("dark")
                }.onChange(of: appearance) { _, v in Appearance.apply(v) }
                Picker(L("settings.interfaceLanguage"), selection: $language) {
                    Text(L("settings.system")).tag("system")
                    Text("עברית").tag("he"); Text("English").tag("en"); Text("العربية").tag("ar")
                }.onChange(of: language) { _, v in InterfaceLanguage.set(v) }
                Text(L("settings.languageRestart")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("settings.hideCategories")) {
                TextField(L("settings.hideCategories.words"), text: $hiddenWords, prompt: Text("xxx, adult"))
                    .task(id: hiddenWords) {                   // applied once typing pauses, not on every key
                        try? await Task.sleep(for: .milliseconds(600))
                        if !Task.isCancelled { model.hiddenCategoriesChanged() }
                    }
                Text(L("settings.hideCategories.note")).font(.caption).foregroundStyle(.secondary)
            }
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
    @AppStorage("prefSubLang") private var subLang = ""
    @AppStorage("prefAudioLang") private var audioLang = ""
    @AppStorage("subScale") private var subScale = 1.0
    @AppStorage("subDelay") private var subDelay = 0.0
    @AppStorage("openFullscreen") private var openFullscreen = true
    @AppStorage("autoNextEpisode") private var autoNext = true

    var body: some View {
        Form {
            Section {
                Toggle(L("settings.fullscreen"), isOn: $openFullscreen)
                Toggle(L("settings.autoNext"), isOn: $autoNext)
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
    @AppStorage("refreshHours") private var refreshHours = 0
    @State private var clearing: ClearKind?
    @State private var message: String?

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
                Picker(L("settings.refresh"), selection: $refreshHours) {
                    ForEach([0, 6, 12, 24], id: \.self) { Text(L("settings.refresh.\($0)")).tag($0) }
                }
            }
            Section(L("settings.backup")) {
                HStack {
                    Button(L("backup.export")) { exportBackup() }
                    Button(L("backup.import")) { importBackup() }
                }
                Text(L("backup.warn")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("settings.clearData")) {
                ForEach(ClearKind.allCases) { k in Button(L("clear.\(k.rawValue)")) { clearing = k } }
            }
            Button(L("settings.guide")) { model.showGuide = true }
        }
        .formStyle(.grouped)
        .confirmationDialog(clearing.map { L("clear.\($0.rawValue)") } ?? "", isPresented: Binding(get: { clearing != nil }, set: { if !$0 { clearing = nil } }),
                            titleVisibility: .visible, presenting: clearing) { kind in
            Button(L("clear.confirm"), role: .destructive) { model.clear(kind) }
        } message: { kind in Text(L("clear.\(kind.rawValue).warn")) }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button(L("player.close")) {} }
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

    private func exportBackup() {
        let p = NSSavePanel()
        p.allowedContentTypes = [.json]; p.nameFieldStringValue = "IPTVMac backup.json"; p.message = L("backup.warn")
        guard p.runModal() == .OK, let url = p.url else { return }
        report("backup.exported") { try await model.exportBackup(to: url) }
    }

    private func importBackup() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.json]; p.allowsMultipleSelection = false
        guard p.runModal() == .OK, let url = p.url else { return }
        report("backup.imported") { try await model.importBackup(from: url) }
    }

    private func report(_ done: String, _ op: @escaping () async throws -> Void) {
        Task {
            do { try await op(); message = L(done) }
            catch BackupError.tooLarge { message = L("backup.error.tooLarge") }
            catch BackupError.unsupportedVersion { message = L("backup.error.version") }
            catch BackupError.invalid { message = L("backup.error.invalid") }
            catch { message = "\(L("backup.failed")): \(error.localizedDescription)" }
        }
    }
}

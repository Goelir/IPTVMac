import SwiftUI
import UniformTypeIdentifiers
import IPTVCore
import IPTVAppKit

enum SettingsRoute: Hashable { case edit(Int64), about, privacy, acknowledgements }

/// Sources, refresh, look, language, hidden categories, backup, clearing data, About. (No updater: the App Store updates the app. No downloads.)
struct SettingsScreen: View {
    @Environment(PhoneModel.self) private var model
    @Environment(UIState.self) private var ui
    @State private var path: [SettingsRoute] = []
    @State private var adding = false

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                SourcesSection(adding: $adding)
                PreferencesSection()
                BackupSection()
                ClearSection()
                Section {
                    NavigationLink(value: SettingsRoute.about) { Label(L("settings.about"), systemImage: "info.circle") }
                }.brandRows()
            }
            .scrollContentBackground(.hidden).background(Brand.canvas)
            .navigationTitle(L("settings.title"))
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .edit(let id): if let a = model.playlist(id: id) { SourceFormView(mode: .edit(a), draft: SourceDraft(), presentation: .pushed) }
                case .about: AboutScreen()
                case .privacy: PrivacyScreen()
                case .acknowledgements: AcknowledgementsScreen()
                }
            }
            .sheet(isPresented: $adding) { NavigationStack { SourceFormView(mode: .add, draft: SourceDraft(), presentation: .sheet) }.formSheet() }
            .task(id: ui.debugSheet) {
                #if DEBUG
                switch ui.debugSheet {
                case "about": path = [.about]
                case "privacy": path = [.about, .privacy]
                case "acks": path = [.about, .acknowledgements]
                case "edit": if let id = model.accounts.first?.id { path = [.edit(id)] }
                case "add": adding = true
                default: break
                }
                #endif
            }
        }
    }
}

private struct SourcesSection: View {
    @Environment(PhoneModel.self) private var model
    @Binding var adding: Bool
    @State private var deleting: Account?

    var body: some View {
        Section {
            ForEach(model.accounts) { a in
                NavigationLink(value: SettingsRoute.edit(a.id ?? 0)) {
                    HStack(spacing: 12) {
                        Image(systemName: a.kind == .xtream ? "server.rack" : "list.bullet.rectangle").foregroundStyle(Brand.accentText).frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.name)
                            Text([a.kind == .xtream ? L("kind.xtream") : L("kind.m3u"), a.kind == .xtream ? a.username : nil].compactMap { $0 }.joined(separator: " · "))
                                .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                            if a.kind == .xtream, let s = model.subscriptions[a.id ?? 0] { SubscriptionLine(info: s).font(.footnote) }
                        }
                    }
                }
                .swipeActions { Button(L("settings.delete"), role: .destructive) { deleting = a } }
                .contextMenu { Button(L("settings.delete"), role: .destructive) { deleting = a } }
            }
            Button { adding = true } label: { Label(L("account.add"), systemImage: "plus.circle.fill") }
        } header: { Text(L("settings.accounts")) } footer: {
            if model.syncing { HStack(spacing: 8) { ProgressView().controlSize(.small); Text(syncStatusText(model.syncProgress)) } }
            else if let m = model.syncMessage { Text("\(L("sync.failed")): \(m)").foregroundStyle(.orange) }
        }
        .brandRows()
        .task { for a in model.accounts { await model.refreshSubscription(a) } }
        .confirmationDialog(deleting?.name ?? "", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible, presenting: deleting) { a in
            Button(L("settings.delete"), role: .destructive) { model.deleteAccount(a) }
        } message: { _ in Text(L("source.delete.warn")) }
    }
}

private struct PreferencesSection: View {
    @Environment(PhoneModel.self) private var model
    @Environment(\.openURL) private var openURL
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("refreshHours") private var refreshHours = 0
    @AppStorage("hiddenCategoryWords") private var hiddenWords = ""
    @AppStorage("favoritesSortAZ") private var favoritesAZ = false

    private var languageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale(identifier: code).localizedString(forIdentifier: code)?.localizedCapitalized ?? code
    }

    var body: some View {
        Section {
            Picker(L("settings.refresh"), selection: $refreshHours) {
                ForEach([0, 6, 12, 24], id: \.self) { Text(L("settings.refresh.\($0)")).tag($0) }
            }.pickerStyle(.navigationLink)
            Picker(L("settings.appearance"), selection: $appearance) {
                Text(L("settings.system")).tag("system")
                Text(L("appearance.light")).tag("light")
                Text(L("appearance.dark")).tag("dark")
            }
            Toggle(L("settings.favoritesAZ"), isOn: $favoritesAZ).onChange(of: favoritesAZ) { model.favoritesOrderChanged() }
        }.brandRows()
        Section {
            LabeledContent(L("settings.interfaceLanguage")) { Text(languageName) }
            Button { if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) } } label: { Label(L("settings.openIOS"), systemImage: "arrow.up.forward.app") }
        } footer: { Text(L("settings.language.note")) }.brandRows()
        Section {
            TextField(L("settings.hideCategories.words"), text: $hiddenWords, prompt: Text(verbatim: "xxx, adult"))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .task(id: hiddenWords) {                    // applied once typing pauses, not on every key
                    try? await Task.sleep(for: .milliseconds(600))
                    if !Task.isCancelled { model.hiddenCategoriesChanged() }
                }
        } header: { Text(L("settings.hideCategories")) } footer: { Text(L("settings.hideCategories.note")) }.brandRows()
    }
}

/// The backup as a file the document picker can save.
private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct BackupSection: View {
    @Environment(PhoneModel.self) private var model
    @State private var document: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        Section {
            Button { Task { await prepareExport() } } label: { Label(L("backup.export"), systemImage: "square.and.arrow.up") }
            Button { importing = true } label: { Label(L("backup.import"), systemImage: "square.and.arrow.down") }
        } header: { Text(L("settings.backup")) } footer: { Text(L("backup.warn")) }
        .brandRows()
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "IPTVMac backup") { r in
            switch r { case .success: message = L("backup.exported"); Haptics.success(); case .failure(let e): message = "\(L("backup.failed")): \(e.localizedDescription)" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { r in
            guard case .success(let url) = r else { return }
            Task { await importBackup(url) }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button(L("player.close")) {} }
    }

    private func prepareExport() async {
        do { document = BackupDocument(data: try await model.db.dbQueue.read { try Backup.make($0).encoded() }); exporting = true }
        catch { message = "\(L("backup.failed")): \(error.localizedDescription)" }
    }

    private func importBackup(_ url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do { try await model.importBackup(from: url); message = L("backup.imported"); Haptics.success() }
        catch BackupError.tooLarge { message = L("backup.error.tooLarge") }
        catch BackupError.unsupportedVersion { message = L("backup.error.version") }
        catch BackupError.invalid { message = L("backup.error.invalid") }
        catch { message = "\(L("backup.failed")): \(error.localizedDescription)" }
    }
}

private struct ClearSection: View {
    @Environment(PhoneModel.self) private var model
    @State private var clearing: ClearKind?

    var body: some View {
        Section(L("settings.clearData")) {
            ForEach(ClearKind.allCases) { k in Button(L("clear.\(k.rawValue)"), role: .destructive) { clearing = k } }
        }
        .brandRows()
        .confirmationDialog(clearing.map { L("clear.\($0.rawValue)") } ?? "", isPresented: Binding(get: { clearing != nil }, set: { if !$0 { clearing = nil } }),
                            titleVisibility: .visible, presenting: clearing) { kind in
            Button(L("clear.confirm"), role: .destructive) { model.clear(kind); if kind == .images { ImageStore.shared.clear() }; Haptics.success() }
        } message: { kind in Text(L("clear.\(kind.rawValue).warn")) }
    }
}

// MARK: About

struct AboutScreen: View {
    @Environment(\.openURL) private var openURL
    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    LogoTile(size: 84)
                    Text(L("app.name")).font(.title2.weight(.bold))
                    Text("\(L("about.version")) \(version)").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }
            Section { Text(L("onb.noChannels")).font(.callout).foregroundStyle(.secondary) }.brandRows()
            Section {
                NavigationLink(value: SettingsRoute.privacy) { Label(L("about.privacy"), systemImage: "hand.raised") }
                NavigationLink(value: SettingsRoute.acknowledgements) { Label(L("about.acknowledgements"), systemImage: "doc.text") }
                Button { if let u = URL(string: "https://github.com/Goelir/IPTVMac") { openURL(u) } } label: { Label(L("about.source"), systemImage: "chevron.left.forwardslash.chevron.right") }
            }.brandRows()
        }
        .scrollContentBackground(.hidden).background(Brand.canvas)
        .navigationTitle(L("settings.about")).navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(L("about.privacy.body").components(separatedBy: "\n\n"), id: \.self) { Text($0).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(20).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(Brand.canvas)
        .navigationTitle(L("about.privacy")).navigationBarTitleDisplayMode(.inline)
    }
}

/// The notices and licence texts (about 100 KB): a text view, not one giant `Text`.
struct AcknowledgementsScreen: View {
    var body: some View {
        NoticeText(text: (Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) }) ?? "")
            .ignoresSafeArea(edges: .bottom)
            .background(Brand.canvas)
            .navigationTitle(L("about.acknowledgements")).navigationBarTitleDisplayMode(.inline)
    }
}

private struct NoticeText: UIViewRepresentable {
    let text: String
    func makeUIView(context: Context) -> UITextView {
        let v = UITextView()
        v.isEditable = false; v.backgroundColor = .clear; v.alwaysBounceVertical = true
        v.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .monospacedSystemFont(ofSize: 12, weight: .regular))
        v.adjustsFontForContentSizeCategory = true
        v.textColor = .label; v.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 32, right: 16)
        v.text = text
        return v
    }
    func updateUIView(_ v: UITextView, context: Context) {}
}

/// "Syncing… 42%": the sync status line, with the percentage once the sync reports one.
func syncStatusText(_ progress: Double?) -> String {
    guard let progress else { return L("sync.running") }
    return "\(L("sync.running")) \(progress.formatted(.percent.precision(.fractionLength(0))))"
}

/// "Expires 12 Mar 2027 · Days left: 140": orange within a week, red once it ended. Nothing when the panel gave no date.
struct SubscriptionLine: View {
    let info: SubscriptionInfo
    var body: some View {
        if let end = info.expires {
            let state = info.state()
            let date = end.formatted(date: .abbreviated, time: .omitted)
            Text(state == .expired ? String(format: L("sub.expired"), date)
                                   : "\(String(format: L("sub.expires"), date)) · \(String(format: L("sub.daysLeft"), info.daysLeft() ?? 0))")
                .font(.caption).foregroundStyle(state == .expired ? .red : state == .soon ? .orange : .secondary)
        }
    }
}

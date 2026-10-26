import SwiftUI
import IPTVCore
import IPTVAppKit

/// First run (no sources yet): who we are, what is not included, and how to add a source. Phone: the welcome, then the form.
/// iPad: both side by side.
struct OnboardingView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var path: [SourceDraft] = []
    @State private var draft = SourceDraft()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if sizeClass == .regular {
                    HStack(spacing: 48) {
                        Welcome(showsAction: false) { _ in }.frame(maxWidth: 460, maxHeight: 660)
                        SourceFormView(mode: .add, draft: draft, presentation: .embedded)
                            .frame(width: 480, height: 660)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
                            .shadow(color: .black.opacity(0.14), radius: 30, y: 14)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Welcome(showsAction: true) { path = [$0 ?? SourceDraft()] }
                }
            }
            .background { WelcomeGround() }
            .navigationDestination(for: SourceDraft.self) { SourceFormView(mode: .add, draft: $0, presentation: .pushed) }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            #if DEBUG
            if ["add", "addfilled"].contains(UserDefaults.standard.string(forKey: "uiSheet")), sizeClass != .regular { path = [SourceDraft()] }
            #endif
        }
    }
}

extension SourceDraft: Hashable {
    public func hash(into h: inout Hasher) { h.combine(kind); h.combine(name); h.combine(server); h.combine(username); h.combine(url) }
}

private struct WelcomeGround: View {
    var body: some View {
        ZStack(alignment: .top) {
            Brand.canvas
            RadialGradient(colors: [Color.accentColor.opacity(0.30), .clear], center: .top, startRadius: 0, endRadius: 460).frame(height: 520)
        }.ignoresSafeArea()
    }
}

/// The app icon, drawn: the logo's blue-to-violet tile with the TV mark.
struct LogoTile: View {
    var size: CGFloat = 112
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.55, blue: 0.94), Color(red: 0.48, green: 0.31, blue: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image("LogoMark").resizable().scaledToFit().padding(size * 0.1)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 0.3, green: 0.2, blue: 0.8).opacity(0.5), radius: size * 0.28, y: size * 0.12)
        .accessibilityHidden(true)
    }
}

private struct Welcome: View {
    let showsAction: Bool
    /// The draft to start the form with (a pasted link), or nil for an empty one.
    let start: (SourceDraft?) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.dynamicTypeSize) private var type
    @State private var shown = false

    private var actions: some View {
        VStack(spacing: 12) {
            Button { Haptics.tap(); start(nil) } label: { Text(L("account.add")).font(.headline).frame(maxWidth: .infinity, minHeight: 36) }
                .buttonStyle(.borderedProminent).controlSize(.large)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { hint; PasteLink { var d = SourceDraft(); d.apply(pasted: $0); start(d) } }
                VStack(spacing: 8) { hint; PasteLink { var d = SourceDraft(); d.apply(pasted: $0); start(d) } }
            }
        }
        .frame(maxWidth: 460)
    }
    private var hint: some View { Text(L("onb.paste.hint")).font(.subheadline).foregroundStyle(.secondary) }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 22) {
                    LogoTile(size: 112)
                        .scaleEffect(shown || reduce ? 1 : 0.88).opacity(shown || reduce ? 1 : 0)
                    VStack(spacing: 10) {
                        Text(L("onb.welcome.title")).font(.largeTitle.weight(.bold)).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                        Text(L("onb.welcome.body")).font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Text(L("onb.welcome.rights")).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: 460)
                    Label { Text(L("onb.noChannels")).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) } icon: {
                        Image(systemName: "info.circle").foregroundStyle(Brand.accentText)
                    }
                    .padding(14).frame(maxWidth: 460, alignment: .leading)
                    .background(Brand.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    if showsAction && type.isAccessibilitySize { actions }          // big text: the buttons scroll with the page
                }
                .padding(.horizontal, 24).padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsAction && !type.isAccessibilitySize {
                actions.padding(.horizontal, 24).padding(.bottom, 12).padding(.top, 8).frame(maxWidth: .infinity)
            }
        }
        .onAppear { withAnimation(reduce ? nil : .smooth(duration: 0.5)) { shown = true } }
    }
}

/// The system paste control: reads the clipboard without the "allow paste" prompt. A provider link becomes a ready form.
struct PasteLink: View {
    let done: (String) -> Void
    var body: some View {
        PasteButton(payloadType: String.self) { strings in
            guard let s = strings.first?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return }
            Haptics.success(); done(s)
        }
        .labelStyle(.titleAndIcon).buttonBorderShape(.capsule).tint(.accentColor)
    }
}

extension SourceDraft {
    /// A pasted provider link fills the form: the whole Xtream login when the link holds one, else the playlist link.
    mutating func apply(pasted s: String) {
        if let l = Self.xtreamLogin(inLink: s) {
            kind = .xtream; server = l.server; username = l.username; password = l.password
        } else if Self.isWebLink(s) {
            kind = .m3u; url = s
        } else if kind == .xtream, server.isEmpty { server = s }
        if name.isEmpty, let host = URL(string: server.isEmpty ? url : server)?.host { name = host }
    }
}

// MARK: The form

/// Add a source, or edit one: type, fields that say what is wrong while you type, a connection test, and one big button.
struct SourceFormView: View {
    enum Mode: Equatable { case add, edit(Account) }
    let mode: Mode
    let presentation: Presentation
    @State private var draft: SourceDraft
    @State private var state = TestState.idle
    @State private var confirmDelete = false
    @FocusState private var focus: Field?
    @Environment(PhoneModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduce

    enum Presentation { case pushed, sheet, embedded }
    enum Field: Hashable { case name, server, username, password, url }
    enum TestState: Equatable { case idle, testing, ok, failed(String) }

    init(mode: Mode, draft: SourceDraft, presentation: Presentation) {
        self.mode = mode; self.presentation = presentation
        var d = draft
        if case .edit(let a) = mode { d.kind = a.kind; d.name = a.name; d.server = a.server ?? ""; d.username = a.username ?? ""; d.url = a.url ?? "" }
        _draft = State(initialValue: d)
    }

    private var editing: Account? { if case .edit(let a) = mode { a } else { nil } }
    private var leavesOnSave: Bool { presentation == .sheet || editing != nil }     // first run: the root swaps to the library by itself

    var body: some View {
        Form {
            if presentation == .embedded {
                Text(L("account.add")).font(.title2.weight(.bold)).listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 12, leading: 4, bottom: 0, trailing: 0))
            }
            if editing == nil {
                Section {
                    Picker(L("field.kind"), selection: $draft.kind) {
                        Text(L("kind.xtream")).tag(AccountKind.xtream)
                        Text(L("kind.m3u")).tag(AccountKind.m3u)
                    }.pickerStyle(.segmented).listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } footer: {
                    Text(draft.kind == .xtream ? L("onb.where.xtream") : L("onb.where.m3u")).fixedSize(horizontal: false, vertical: true)
                }.brandRows()
            }
            Section {
                TextField(L("field.name"), text: $draft.name).focused($focus, equals: .name).submitLabel(.next)
                    .textInputAutocapitalization(.words).onSubmit { focus = draft.kind == .xtream ? .server : .url }
                if draft.kind == .xtream {
                    TextField(L("field.server"), text: $draft.server, prompt: Text(verbatim: "http://host:8080")).focused($focus, equals: .server).submitLabel(.next)
                        .keyboardType(.URL).textContentType(.URL).onSubmit { focus = .username }
                    TextField(L("field.username"), text: $draft.username).focused($focus, equals: .username).submitLabel(.next)
                        .textContentType(.username).onSubmit { focus = .password }
                    SecureField(editing == nil ? L("field.password") : L("settings.newPassword"), text: $draft.password).focused($focus, equals: .password).submitLabel(.go)
                        .textContentType(.password).onSubmit { focus = nil }
                } else {
                    TextField(L("field.url"), text: $draft.url, prompt: Text(verbatim: "https://example.com/list.m3u"), axis: .vertical).focused($focus, equals: .url).lineLimit(1...4)
                        .keyboardType(.URL).textContentType(.URL).submitLabel(.go).onSubmit { focus = nil }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if draft.kind == .xtream && draft.serverLooksWrong { problem(L("field.server.invalid")) }
                    if draft.kind == .m3u && draft.urlLooksWrong { problem(L("field.url.invalid")) }
                }
            }
            .textInputAutocapitalization(.never).autocorrectionDisabled().brandRows()
            if editing == nil {
                Section {
                    HStack(spacing: 10) {
                        Text(L("onb.paste.hint")).foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        PasteLink { draft.apply(pasted: $0) }
                    }
                }.brandRows()
            }
            if model.accounts.isEmpty, let m = model.syncMessage {      // saving failed (disk, keychain): say so instead of doing nothing
                Section { Label(m, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }.brandRows()
            }
            if case .failed(let m) = state {
                Section { Label(m, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }.brandRows()
            } else if state == .ok {
                Section { Label(L("onb.test.ok"), systemImage: "checkmark.circle.fill").foregroundStyle(.green) }.brandRows()
            }
            if presentation == .embedded { Section { primaryButton }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            if editing != nil {
                Section {
                    Button { Task { await test() } } label: { HStack { Text(L("onb.test")); if state == .testing { ProgressView() } } }.disabled(!draft.canTest || state == .testing)
                } footer: { if draft.kind == .xtream { Text(L("settings.password.note")) } }.brandRows()
                Section { Button(L("settings.delete"), role: .destructive) { confirmDelete = true } }.brandRows()
            }
        }
        .scrollContentBackground(.hidden).background(Brand.canvas)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(presentation == .embedded ? "" : editing == nil ? L("account.add") : L("settings.editSource")).navigationBarTitleDisplayMode(.inline)
        .toolbar(presentation == .embedded ? .hidden : .visible, for: .navigationBar)
        .toolbar { if presentation == .sheet { ToolbarItem(placement: .cancellationAction) { Button(L("common.cancel")) { dismiss() } } } }
        .safeAreaInset(edge: .bottom, spacing: 0) { if presentation != .embedded { primaryBar } }
        .onChange(of: draft) { if state != .testing { state = .idle } }
        .motion(value: state)
        .confirmationDialog(editing?.name ?? "", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("settings.delete"), role: .destructive) { if let a = editing { dismiss(); model.deleteAccount(a) } }
        } message: { Text(L("source.delete.warn")) }
        .task {
            #if DEBUG
            if UserDefaults.standard.string(forKey: "uiSheet") == "addfilled", editing == nil { draft.name = "Home"; draft.server = "http://192.168.1.20:8080"; draft.username = "eli" }
            #endif
        }
    }

    private func problem(_ s: String) -> some View {
        Label(s, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red).font(.footnote).fixedSize(horizontal: false, vertical: true)
    }

    // The one big button: test first, then save and sync (editing may save at once).
    private var primaryButton: some View {
        let ready = state == .ok || editing != nil
        return Button { ready ? Task { await save() } : Task { await test() } } label: {
            HStack(spacing: 8) {
                if state == .testing { ProgressView().tint(.white); Text(L("onb.test.running")) }
                else { Text(ready ? L("onb.save") : L("onb.test")) }
            }
            .font(.headline).frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        .disabled(!draft.canTest || state == .testing)
    }

    private var primaryBar: some View {
        VStack(spacing: 0) { primaryButton.padding(16) }.background(.bar)
    }

    private func test() async {
        focus = nil; state = .testing
        do {
            try await LibraryModel.testConnection(kind: draft.kind, server: draft.server, username: draft.username, password: draft.password, url: draft.url)
            Haptics.success(); state = .ok
        } catch { Haptics.failure(); state = .failed("\(L("onb.test.fail")): \(error.localizedDescription)") }
    }

    private func save() async {
        if let a = editing {
            var updated = a
            let d = draft.makeAccount().account
            updated.name = d.name; updated.server = d.server; updated.username = d.username; updated.url = d.url
            if leavesOnSave { dismiss() }
            await model.updateAccount(updated, password: draft.password.isEmpty ? nil : draft.password)
        } else {
            let (a, pw) = draft.makeAccount()
            if leavesOnSave { dismiss() }
            await model.addAccount(a, password: pw)
        }
    }
}

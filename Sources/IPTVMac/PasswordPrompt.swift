import SwiftUI
import IPTVCore

/// Asks for the account password when none is stored (the app no longer uses the Keychain).
struct PasswordPrompt: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    let account: Account
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("password.title")).font(.title2)
            Text(String(format: L("password.body"), account.name)).foregroundStyle(.secondary)
            SecureField(L("field.password"), text: $password).onSubmit(save)
            HStack {
                Spacer()
                Button(L("player.close")) { dismiss() }
                Button(L(password.isEmpty ? "password.none" : "onb.save")) { save() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 420)
    }

    private func save() {
        Task { await model.savePassword(password, for: account) }
    }
}

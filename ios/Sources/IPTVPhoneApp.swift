import SwiftUI

@main struct IPTVPhoneApp: App {
    @State private var model: PhoneModel

    init() {
        #if DEBUG
        DebugLaunch.prepare()
        #endif
        // Logos and posters: a bigger share of the shared URL cache (it also backs "Clear image cache").
        URLCache.shared = URLCache(memoryCapacity: 48 << 20, diskCapacity: 400 << 20)
        let m = PhoneModel()
        m.loadAccounts()          // before the first frame: a returning user must not see the welcome screen for an instant
        _model = State(initialValue: m)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    await model.start()
                    #if DEBUG
                    await PlayerDebug.runIfRequested(model)   // -uiState player-*: opens the player on a generated test stream
                    #endif
                }
        }
    }
}

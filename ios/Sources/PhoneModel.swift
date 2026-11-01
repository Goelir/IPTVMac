import Foundation
import Observation
import IPTVCore
import IPTVAppKit

/// The iOS app model: everything shared (accounts, search, sync, favorites...) is LibraryModel; this adds the player.
@MainActor @Observable
final class PhoneModel: LibraryModel {
    var player: PhonePlayer?

    init() {
        let opened: (db: AppDatabase, movedAside: String?)
        var failure: String?
        do { opened = try AppDatabase.openRecovering(path: try AppDatabase.defaultPath()) }
        catch {   // no disk: an in-memory database keeps the app usable, nothing is saved this session
            opened = (try! AppDatabase(), nil); failure = error.localizedDescription
        }
        super.init(db: opened.db, secrets: KeychainSecretStore(legacy: DatabaseSecretStore(db: opened.db)), dbMovedAside: opened.movedAside)   // passwords in the iOS Keychain
        syncMessage = failure
    }

    override func startPlayback(_ r: PlayRequest) {
        // The next channel or episode goes through the player that is already running: replace() saves the old position through
        // onSaveProgress, which reads `playing`, so that is switched only afterwards.
        if let p = player { p.replace(with: r); playing = r; return }
        playing = r
        let p = PhonePlayer(request: r)
        p.onSaveProgress = { [weak self] position, duration in
            guard let self, let cur = self.playing else { return }
            self.saveProgress(cur, position: position, duration: duration)
        }
        player = p
    }

    override func stopPlayback() {
        player?.close(); player = nil
        playing = nil
    }
}

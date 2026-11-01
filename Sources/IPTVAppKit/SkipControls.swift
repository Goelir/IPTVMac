import Foundation
import Observation
import IPTVCore

/// The skip buttons of the episode that is playing: the marks of its series, the button to show now, and marking new ones.
/// The player calls `update` with every tick of its clock and draws `offer`; the menu items call the `mark…` functions.
@MainActor @Observable
public final class SkipControls {
    /// A short message for the player to show for a moment after marking.
    public enum Notice: Equatable { case saved, refused }

    public private(set) var marks: SkipMarks
    public private(set) var offer: SkipOffer?
    public private(set) var notice: Notice?
    @ObservationIgnored private let save: (SkipMarks) -> Void
    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    @ObservationIgnored private let noticeSeconds: Double

    public init(marks: SkipMarks, noticeSeconds: Double = 3, save: @escaping (SkipMarks) -> Void) {
        self.marks = marks; self.noticeSeconds = noticeSeconds; self.save = save
    }

    public func update(position: Double, duration: Double) {
        let o = SkipLogic.offer(marks, position: position, duration: duration)
        if o != offer { offer = o }
    }

    public func markIntroStart(position: Double, duration: Double) { apply(SkipLogic.markIntroStart(marks, position: position, duration: duration), position, duration) }
    public func markIntroEnd(position: Double, duration: Double) { apply(SkipLogic.markIntroEnd(marks, position: position, duration: duration), position, duration) }
    public func markCredits(position: Double, duration: Double) { apply(SkipLogic.markCredits(marks, position: position, duration: duration), position, duration) }

    /// Forgets all three marks of the series.
    public func forget() {
        marks = SkipMarks(); save(marks); offer = nil; show(.saved)
    }

    private func apply(_ new: SkipMarks?, _ position: Double, _ duration: Double) {
        guard let new else { show(.refused); return }
        marks = new; save(new); update(position: position, duration: duration); show(.saved)
    }

    private func show(_ n: Notice) {
        notice = n
        noticeTask?.cancel()
        noticeTask = Task { [weak self, noticeSeconds] in
            try? await Task.sleep(for: .seconds(noticeSeconds))
            if !Task.isCancelled { self?.notice = nil }
        }
    }
}

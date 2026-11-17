import Foundation
import Observation
import StoreKit

/// Optional tips through Apple's In-App Purchase: four consumable products that unlock nothing (every feature is free for everyone).
/// The products and their prices live in App Store Connect; until they are approved `products` stays empty and the About screen
/// shows no tip section at all. Nothing is stored: a tip has no effect inside the app besides the thank-you line.
@MainActor @Observable
final class TipJar {
    static let shared = TipJar()
    static let productIDs = ["tip_small", "tip_coffee", "tip_lunch", "tip_super"]   // as created in App Store Connect; shown by price

    enum Status: Equatable { case idle, buying(String), thanked, pending, failed }

    private(set) var products: [Product] = []
    private(set) var status = Status.idle
    @ObservationIgnored private var listener: Task<Void, Never>?
    private let ids: [String]

    init(ids: [String] = TipJar.productIDs) { self.ids = ids }

    /// At launch: finishes tips that completed outside the app (Ask to Buy approved later, an interrupted purchase).
    func listen() {
        guard listener == nil else { return }
        listener = Task {
            for await result in Transaction.unfinished { if case .verified(let t) = result { await t.finish() } }
            for await result in Transaction.updates { if case .verified(let t) = result { await t.finish() } }
        }
    }

    /// The tips in price order; empty when the store has none for this app yet or there is no network.
    func load() async {
        guard products.isEmpty else { return }
        products = ((try? await Product.products(for: ids)) ?? []).sorted { $0.price < $1.price }
    }

    func buy(_ product: Product) async {
        guard status != .buying(product.id) else { return }
        status = .buying(product.id)
        do {
            switch try await product.purchase() {
            case .success(.verified(let t)): await t.finish(); status = .thanked
            case .success(.unverified(let t, _)): await t.finish(); status = .failed   // Apple could not verify it: no thank-you
            case .pending: status = .pending                                            // Ask to Buy: `listen()` finishes it later
            case .userCancelled: status = .idle
            @unknown default: status = .idle
            }
        } catch { status = .failed }
    }
}

import Foundation

private let l10nBundle: Bundle = {
    if let u = Bundle.main.resourceURL?.appendingPathComponent("IPTVMac_IPTVMac.bundle"), let b = Bundle(url: u) { return b }
    return Bundle.module
}()

func L(_ key: String) -> String { NSLocalizedString(key, bundle: l10nBundle, comment: "") }

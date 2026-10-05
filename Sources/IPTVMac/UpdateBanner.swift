import SwiftUI
import IPTVCore

struct UpdateBanner: View {
    @Environment(AppModel.self) var model

    var body: some View {
        if !model.updateBannerDismissed, let line = content {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.tint)
                line
                Spacer()
                if let page = model.update?.pageURL, model.updateStatus != .downloading {
                    Link(L("update.notes"), destination: page)
                }
                Button(L("update.later")) { model.updateBannerDismissed = true }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.bar)
        }
    }

    private var version: String { model.update?.version ?? "" }

    private var content: AnyView? {
        switch model.updateStatus {
        case .available:
            return AnyView(HStack {
                Text(String(format: L("update.available"), version))
                Button(L("update.now")) { Task { await model.installUpdate() } }.buttonStyle(.borderedProminent)
            })
        case .downloading:
            return AnyView(HStack { ProgressView().controlSize(.small); Text(L("update.downloading")) })
        case .ready:
            return AnyView(HStack {
                Text(String(format: L("update.ready"), version))
                Button(L("update.restart")) { model.restartToUpdate() }.buttonStyle(.borderedProminent)
            })
        case .failed(let m):
            return AnyView(HStack {
                Text("\(L("update.failed")): \(m)").foregroundStyle(.red).lineLimit(2)
                if let page = model.update?.pageURL { Link(L("update.manual"), destination: page) }
            })
        case .none, .upToDate, .devBuild:
            return nil
        }
    }
}

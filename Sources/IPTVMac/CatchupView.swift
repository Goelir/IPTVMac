import SwiftUI
import IPTVCore

struct CatchupView: View {
    @Environment(AppModel.self) var model
    let item: Item
    let onPlay: (URL, String) -> Void
    @State private var entries: [EPGEntry] = []
    @State private var loading = true
    @State private var manualStart = Date().addingTimeInterval(-3600)
    @State private var minutes = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(L("catchup.title")): \(item.name)").font(.headline)
            if loading { ProgressView() }
            else if entries.isEmpty {
                Text(L("catchup.noEpg")).foregroundStyle(.secondary)
                DatePicker(L("catchup.pick"), selection: $manualStart,
                           in: Date().addingTimeInterval(-Double(max(item.archiveDays, 1)) * 86400)...Date())
                Stepper("\(L("catchup.duration")): \(minutes)", value: $minutes, in: 5...480, step: 5)
                Button(L("player.catchup")) { play(manualStart, minutes) }.buttonStyle(.borderedProminent)
            } else {
                List(entries, id: \.start) { e in
                    HStack {
                        Text(e.start.formatted(date: .abbreviated, time: .shortened)).monospacedDigit().foregroundStyle(.secondary)
                        Text(e.title)
                    }.contentShape(Rectangle()).onTapGesture { play(e.start, max(Int(e.end.timeIntervalSince(e.start) / 60), 1)) }
                }
            }
        }
        .padding().frame(minWidth: 480, minHeight: 360)
        .task {
            if let urls = model.xtreamURLs() {
                let cutoff = Date().addingTimeInterval(-Double(max(item.archiveDays, 1)) * 86400)
                let all = (try? await XtreamClient(urls: urls).epgArchive(streamId: item.streamId)) ?? []
                entries = all.filter { $0.end < Date() && $0.start > cutoff }.sorted { $0.start > $1.start }
            }
            loading = false
        }
    }

    private func play(_ start: Date, _ mins: Int) {
        guard let urls = model.xtreamURLs() else { return }
        onPlay(urls.timeshift(id: item.streamId, start: start, minutes: mins), "\(item.name) — \(start.formatted(date: .abbreviated, time: .shortened))")
    }
}

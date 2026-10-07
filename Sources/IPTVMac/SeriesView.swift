import SwiftUI
import IPTVCore

struct SeriesView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    let series: Item
    @State private var episodes: [Episode] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(series.name).font(.title2.weight(.semibold)).lineLimit(2)
                Spacer()
                Button(L("player.close")) { dismiss() }
            }
            if loading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).transition(.opacity) }
            else if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else {
                List {
                    let bySeason = Dictionary(grouping: episodes, by: \.season)
                    ForEach(bySeason.keys.sorted(), id: \.self) { s in
                        Section {
                            ForEach(bySeason[s] ?? []) { e in
                                HStack(spacing: 10) {
                                    Text("\(e.number)").monospacedDigit().foregroundStyle(.secondary).frame(minWidth: 28, alignment: .trailing)
                                    Text(e.title).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                        .onTapGesture { dismiss(); model.playEpisode(e, of: series, in: episodes) }
                                    Button { model.download([e], of: series) } label: { Image(systemName: "arrow.down.circle") }
                                        .buttonStyle(IconButtonStyle()).help(L("downloads.add")).accessibilityLabel(L("downloads.add"))
                                }
                                .padding(.vertical, 2).hoverHighlight(radius: 6)
                            }
                        } header: {
                            HStack {
                                Text("\(L("series.season")) \(s)").font(.headline)
                                Spacer()
                                Button(L("downloads.season")) { model.download(bySeason[s] ?? [], of: series) }
                            }
                        }
                    }
                }
            }
        }
        .padding().frame(minWidth: 520, minHeight: 480)
        .motion(value: loading)
        .task {
            guard let a = model.playlist(id: series.accountId) else { return }
            do {
                episodes = try await SyncService(db: model.db).episodes(account: a, password: a.id.flatMap { model.secrets.password(for: $0) }, seriesId: series.streamId)
            } catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

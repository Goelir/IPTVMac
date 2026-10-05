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
        VStack(alignment: .leading) {
            HStack {
                Text(series.name).font(.title2)
                Spacer()
                Button(L("player.close")) { dismiss() }
            }
            if loading { ProgressView() }
            else if let error { Text(error).foregroundStyle(.red) }
            else {
                List {
                    ForEach(Dictionary(grouping: episodes, by: \.season).keys.sorted(), id: \.self) { s in
                        Section("\(L("series.season")) \(s)") {
                            ForEach(episodes.filter { $0.season == s }) { e in
                                Text("\(e.number). \(e.title)").contentShape(Rectangle())
                                    .onTapGesture { dismiss(); model.playEpisode(e, of: series) }
                            }
                        }
                    }
                }
            }
        }
        .padding().frame(minWidth: 520, minHeight: 480)
        .task {
            guard let a = model.account else { return }
            do {
                episodes = try await SyncService(db: model.db).episodes(account: a, password: a.id.flatMap { model.secrets.password(for: $0) }, seriesId: series.streamId)
            } catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

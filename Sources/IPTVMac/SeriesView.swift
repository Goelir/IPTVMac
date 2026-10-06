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
                    let bySeason = Dictionary(grouping: episodes, by: \.season)
                    ForEach(bySeason.keys.sorted(), id: \.self) { s in
                        Section {
                            ForEach(bySeason[s] ?? []) { e in
                                HStack {
                                    Text("\(e.number). \(e.title)").frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                        .onTapGesture { dismiss(); model.playEpisode(e, of: series, in: episodes) }
                                    Button { model.download([e], of: series) } label: { Image(systemName: "arrow.down.circle") }
                                        .buttonStyle(.plain).help(L("downloads.add"))
                                }
                            }
                        } header: {
                            HStack {
                                Text("\(L("series.season")) \(s)")
                                Spacer()
                                Button(L("downloads.season")) { model.download(bySeason[s] ?? [], of: series) }
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

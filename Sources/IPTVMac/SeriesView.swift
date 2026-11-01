import SwiftUI
import IPTVCore
import IPTVAppKit

struct SeriesView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    let series: Item
    @State private var episodes: [Episode] = []
    @State private var loading = true
    @State private var error: String?
    @State private var info: ItemInfo?
    @State private var progress: [String: EpisodeProgress] = [:]      // where each episode was left, by episode id

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(series.name).font(.title2.weight(.semibold)).lineLimit(2)
                Spacer()
                Button(L("player.close")) { dismiss() }
            }
            if let info, info.hasContent { SeriesHeader(series: series, info: info).transition(.opacity) }
            if loading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).transition(.opacity) }
            else if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else {
                ScrollViewReader { proxy in
                List {
                    let bySeason = Dictionary(grouping: episodes, by: \.season)
                    let next = WatchProgress.upNext(episodes, progress: progress)?.episode.streamId
                    ForEach(bySeason.keys.sorted(), id: \.self) { s in
                        Section {
                            ForEach((bySeason[s] ?? []).sorted { $0.number < $1.number }) { e in
                                let p = progress[e.streamId]
                                HStack(spacing: 10) {
                                    Text("\(e.number)").monospacedDigit().foregroundStyle(.secondary).frame(minWidth: 28, alignment: .trailing)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(e.title).lineLimit(2)
                                        if e.streamId == next { Text(L("next.title")).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor) }
                                        if let p, !p.isWatched, p.fraction > 0.01 {
                                            HStack(spacing: 8) {
                                                ProgressView(value: p.fraction).progressViewStyle(.linear).frame(maxWidth: 140)
                                                Text(String(format: L("downloads.eta"), String(format: L("unit.minutesShort"), max(1, Int(((p.duration - p.position) / 60).rounded(.up))))))
                                                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                    .onTapGesture { dismiss(); model.playEpisode(e, of: series, in: episodes) }
                                    if p?.isWatched == true {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary).help(L("series.watched")).accessibilityLabel(L("series.watched"))
                                    }
                                    Button { model.download([e], of: series) } label: { Image(systemName: "arrow.down.circle") }
                                        .buttonStyle(IconButtonStyle()).help(L("downloads.add")).accessibilityLabel(L("downloads.add"))
                                }
                                .padding(.vertical, 2).hoverHighlight(radius: 6).id(e.streamId)
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
                .onAppear {   // a long series opens at the episode that comes next
                    guard let t = WatchProgress.upNext(episodes, progress: progress)?.episode.streamId else { return }
                    DispatchQueue.main.async { proxy.scrollTo(t, anchor: .center) }
                }
                }
            }
        }
        .padding().frame(minWidth: 520, minHeight: 480)
        .motion(value: loading)
        .motion(value: info)
        .task {
            guard let a = model.playlist(id: series.accountId) else { return }
            info = await model.cachedInfo(series)        // from an earlier visit; the episodes request below refreshes it for free
            do {
                episodes = try await SyncService(db: model.db).episodes(account: a, password: a.id.flatMap { model.secrets.password(for: $0) }, seriesId: series.streamId)
                progress = (try? await model.db.dbQueue.read { try WatchProgress.episodeProgress($0, accountId: series.accountId) }) ?? [:]
            } catch { self.error = error.localizedDescription }
            loading = false
            if let fresh = await model.cachedInfo(series) { info = fresh }
        }
    }
}

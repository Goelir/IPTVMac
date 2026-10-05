import SwiftUI
import AppKit
import IPTVCore

struct DownloadsView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss

    var body: some View {
        let d = model.downloads
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("downloads.title")).font(.title2)
                Spacer()
                Button(L("player.close")) { dismiss() }
            }
            if d.entries.isEmpty {
                ContentUnavailableView(L("downloads.empty"), systemImage: "arrow.down.circle")
            } else {
                List(d.entries) { e in row(e) }
            }
            Text(L("downloads.hint")).font(.caption).foregroundStyle(.secondary)
        }
        .padding().frame(minWidth: 560, minHeight: 360)
    }

    @ViewBuilder
    private func row(_ e: DownloadEntry) -> some View {
        let d = model.downloads
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(e.title).lineLimit(1)
                switch e.state {
                case .done: Text(L("downloads.done")).font(.caption).foregroundStyle(.green)
                case .failed(let m): Text(m).font(.caption).foregroundStyle(.red).lineLimit(2)
                case .queued: Text(L("downloads.queued")).font(.caption).foregroundStyle(.secondary)
                case .active, .paused:
                    ProgressView(value: e.progress)
                    Text("\(ByteCountFormatter.string(fromByteCount: e.received, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: e.total, countStyle: .file))")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Spacer()
            switch e.state {
            case .done:
                Button { model.stopPlayback(); dismiss(); model.startPlayback(PlayRequest(title: e.title, url: e.file, isLive: false, item: nil)) } label: { Image(systemName: "play.fill") }.help(L("downloads.play"))
                Button { NSWorkspace.shared.activateFileViewerSelecting([e.file]) } label: { Image(systemName: "folder") }.help(L("downloads.reveal"))
                Button { d.remove(e.id, trashFile: true) } label: { Image(systemName: "trash") }.help(L("downloads.delete"))
            case .active, .queued:
                Button { d.pause(e.id) } label: { Image(systemName: "pause.fill") }.help(L("downloads.pause"))
                Button { d.remove(e.id) } label: { Image(systemName: "xmark") }.help(L("downloads.cancel"))
            case .paused, .failed:
                Button { d.resume(e.id) } label: { Image(systemName: "arrow.clockwise") }.help(L("downloads.resume"))
                Button { d.remove(e.id) } label: { Image(systemName: "xmark") }.help(L("downloads.cancel"))
            }
        }.buttonStyle(.plain)
    }
}

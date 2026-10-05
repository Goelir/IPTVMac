import Foundation
import AppKit
import Observation
import IPTVCore

struct DownloadEntry: Identifiable {
    enum State: Equatable { case queued, active, paused, done, failed(String) }
    let id = UUID()
    var title: String
    var url: URL?               // nil for finished entries restored after a restart (their URL carries the password: never stored)
    var file: URL
    var state: State = .queued
    var received: Int64 = 0
    var total: Int64 = 0
    var resumeData: Data?
    var retries = 0
    var progress: Double { total > 0 ? Double(received) / Double(total) : 0 }
}

/// Downloads movies/episodes into a user-chosen folder, one at a time (many providers allow a single connection).
/// ponytail: unfinished downloads are not kept across restarts (their URLs contain the password); only finished files are listed.
@MainActor @Observable
final class DownloadManager: NSObject, URLSessionDownloadDelegate {
    var entries: [DownloadEntry] = []
    var folderPath: String? { didSet { UserDefaults.standard.set(folderPath, forKey: "downloadFolder") } }
    @ObservationIgnored private var tasks: [UUID: URLSessionDownloadTask] = [:]
    @ObservationIgnored private lazy var session: URLSession = {
        let c = URLSessionConfiguration.ephemeral          // the URL holds the account password: nothing on the URL cache
        c.timeoutIntervalForRequest = 60
        return URLSession(configuration: c, delegate: self, delegateQueue: nil)
    }()

    var activeCount: Int { entries.filter { $0.state == .active || $0.state == .queued }.count }

    override init() {
        super.init()
        folderPath = UserDefaults.standard.string(forKey: "downloadFolder")
        if let data = UserDefaults.standard.data(forKey: "downloadsDone"),
           let rows = try? JSONDecoder().decode([[String]].self, from: data) {
            entries = rows.compactMap { r in
                guard r.count == 2, FileManager.default.fileExists(atPath: r[1]) else { return nil }
                var e = DownloadEntry(title: r[0], url: nil, file: URL(fileURLWithPath: r[1])); e.state = .done
                return e
            }
        }
    }

    // MARK: Folder

    /// Asks for the folder the first time (or when the old one is gone). False if the user cancels.
    func ensureFolder() -> Bool {
        if let p = folderPath, FileManager.default.isWritableFile(atPath: p) { return true }
        return chooseFolder()
    }

    @discardableResult
    func chooseFolder() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.message = L("downloads.chooseFolder"); panel.prompt = L("downloads.choose")
        panel.directoryURL = folderPath.map { URL(fileURLWithPath: $0) } ?? FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let u = panel.url else { return false }
        folderPath = u.path
        return true
    }

    // MARK: Queue

    func contains(_ url: URL) -> Bool { entries.contains { $0.url == url && $0.state != .done && !isFailed($0) } }
    private func isFailed(_ e: DownloadEntry) -> Bool { if case .failed = e.state { return true }; return false }

    /// Queues a download. Returns false when no folder was chosen.
    @discardableResult
    func add(title: String, url: URL, ext: String?) -> Bool {
        guard ensureFolder(), let dir = folderPath, !contains(url) else { return folderPath != nil }
        let name = DownloadNaming.fileName(title: title, ext: ext) { n in
            FileManager.default.fileExists(atPath: "\(dir)/\(n)") || self.entries.contains { $0.file.lastPathComponent == n && $0.file.deletingLastPathComponent().path == dir }
        }
        entries.append(DownloadEntry(title: title, url: url, file: URL(fileURLWithPath: dir).appendingPathComponent(name)))
        pump()
        return true
    }

    private func pump() {
        guard !entries.contains(where: { $0.state == .active }),
              let i = entries.firstIndex(where: { $0.state == .queued }) else { return }
        start(i)
    }

    private func start(_ i: Int) {
        let e = entries[i]
        let t: URLSessionDownloadTask
        if let d = e.resumeData { t = session.downloadTask(withResumeData: d) }
        else if let u = e.url { t = session.downloadTask(with: u) }
        else { return }
        t.taskDescription = "\(e.id.uuidString)|\(e.file.path)"
        tasks[e.id] = t
        entries[i].state = .active; entries[i].resumeData = nil
        t.resume()
    }

    func pause(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        if entries[i].state == .queued { entries[i].state = .paused; return }
        guard entries[i].state == .active, let t = tasks.removeValue(forKey: id) else { return }
        entries[i].state = .paused
        t.cancel { [weak self] data in Task { @MainActor in
            if let self, let j = self.entries.firstIndex(where: { $0.id == id }) { self.entries[j].resumeData = data }
            self?.pump()
        } }
    }

    func resume(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }), entries[i].url != nil else { return }
        switch entries[i].state { case .paused, .failed: entries[i].state = .queued; entries[i].retries = 0; pump(); default: break }
    }

    /// Cancels a running/queued/failed download, or drops a finished one from the list (keepFile false moves the file to the Trash).
    func remove(_ id: UUID, trashFile: Bool = false) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        tasks.removeValue(forKey: id)?.cancel()
        if trashFile { try? FileManager.default.trashItem(at: entries[i].file, resultingItemURL: nil) }
        entries.remove(at: i)
        saveDone(); pump()
    }

    private func saveDone() {
        let rows = entries.filter { $0.state == .done }.map { [$0.title, $0.file.path] }
        UserDefaults.standard.set(try? JSONEncoder().encode(rows), forKey: "downloadsDone")
    }

    private func finish(_ id: UUID, error: String?) {
        tasks[id] = nil
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        if let error { entries[i].state = .failed(error) } else { entries[i].state = .done; entries[i].received = max(entries[i].received, entries[i].total) }
        saveDone(); pump()
    }

    // MARK: URLSessionDownloadDelegate (background queue)

    private nonisolated static func parse(_ t: URLSessionTask) -> (UUID, String)? {
        guard let d = t.taskDescription, let bar = d.firstIndex(of: "|"), let id = UUID(uuidString: String(d[..<bar])) else { return nil }
        return (id, String(d[d.index(after: bar)...]))
    }

    nonisolated func urlSession(_ s: URLSession, downloadTask t: URLSessionDownloadTask, didWriteData written: Int64,
                                totalBytesWritten done: Int64, totalBytesExpectedToWrite total: Int64) {
        guard done / 262_144 != (done - written) / 262_144, let (id, _) = Self.parse(t) else { return }   // ~every 256 KB
        Task { @MainActor in
            guard let i = self.entries.firstIndex(where: { $0.id == id }) else { return }
            self.entries[i].received = done; self.entries[i].total = max(total, 0)
        }
    }

    nonisolated func urlSession(_ s: URLSession, downloadTask t: URLSessionDownloadTask, didFinishDownloadingTo tmp: URL) {
        guard let (id, path) = Self.parse(t) else { return }
        let code = (t.response as? HTTPURLResponse)?.statusCode ?? 200
        var failure: String?
        if !(200..<300).contains(code) { failure = "HTTP \(code)" }
        else {
            do { try FileManager.default.moveItem(at: tmp, to: URL(fileURLWithPath: path)) }   // the temp file is deleted when this returns
            catch { failure = error.localizedDescription }
        }
        Task { @MainActor in self.finish(id, error: failure) }
    }

    nonisolated func urlSession(_ s: URLSession, task t: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let (id, _) = Self.parse(t) else { return }
        let ns = error as NSError
        let data = ns.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        Task { @MainActor in
            guard let i = self.entries.firstIndex(where: { $0.id == id }), self.entries[i].state == .active else { return }  // paused/removed: ignore
            self.tasks[id] = nil
            if ns.code != NSURLErrorCancelled, self.entries[i].retries < 3 {       // dropped connection: resume where it stopped
                self.entries[i].retries += 1; self.entries[i].resumeData = data; self.entries[i].state = .queued
                try? await Task.sleep(for: .seconds(2)); self.pump()
            } else { self.finish(id, error: error.localizedDescription) }
        }
    }
}

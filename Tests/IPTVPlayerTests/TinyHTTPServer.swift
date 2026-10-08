import Foundation
import Darwin

/// A throwaway HTTP/1.1 server on 127.0.0.1 that serves one file, with or without byte-range support, and counts connections.
/// Plain POSIX sockets: no window, no entitlement, no network beyond the loopback.
final class TinyHTTPServer: @unchecked Sendable {
    let port: UInt16
    private let listener: Int32
    private let body: Data
    private let ranges: Bool
    private let lock = NSLock()
    private var connections = 0
    var connectionCount: Int { lock.withLock { connections } }

    init?(body: Data, ranges: Bool) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1"); addr.sin_port = 0
        let bound = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) } }
        guard bound == 0, named == 0, listen(fd, 8) == 0 else { close(fd); return nil }
        listener = fd; port = UInt16(bigEndian: addr.sin_port); self.body = body; self.ranges = ranges
        Thread.detachNewThread { [self] in
            while true {
                let c = accept(listener, nil, nil)
                if c < 0 { return }
                lock.withLock { connections += 1 }
                Thread.detachNewThread { [self] in serve(c) }
            }
        }
    }

    func stop() { shutdown(listener, SHUT_RDWR); close(listener) }

    private func serve(_ c: Int32) {
        defer { close(c) }
        var req = Data(), buf = [UInt8](repeating: 0, count: 4096)
        while req.range(of: Data("\r\n\r\n".utf8)) == nil, req.count < 16384 {
            let n = read(c, &buf, buf.count)
            if n <= 0 { return }
            req.append(contentsOf: buf[0..<n])
        }
        let text = String(decoding: req, as: UTF8.self)
        var lo = 0, hi = body.count - 1, partial = false
        if ranges, let line = text.split(separator: "\r\n").first(where: { $0.lowercased().hasPrefix("range:") }),
           let eq = line.firstIndex(of: "=") {
            let parts = line[line.index(after: eq)...].split(separator: "-", omittingEmptySubsequences: false)
            if let a = Int(parts[0].trimmingCharacters(in: .whitespaces)) { lo = min(a, body.count); partial = true }
            if parts.count > 1, let b = Int(parts[1].trimmingCharacters(in: .whitespaces)) { hi = min(b, body.count - 1) }
        }
        let slice = lo <= hi ? body[lo...hi] : Data()
        var head = partial ? "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes \(lo)-\(hi)/\(body.count)\r\n" : "HTTP/1.1 200 OK\r\n"
        head += "Content-Type: video/mp4\r\nContent-Length: \(slice.count)\r\n" + (ranges ? "Accept-Ranges: bytes\r\n" : "") + "Connection: close\r\n\r\n"
        let out = Data(head.utf8) + slice
        out.withUnsafeBytes { p in
            var off = 0
            while off < p.count { let n = write(c, p.baseAddress! + off, p.count - off); if n <= 0 { return }; off += n }
        }
    }
}

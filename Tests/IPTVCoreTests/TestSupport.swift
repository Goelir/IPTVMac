import Foundation
import GRDB
@testable import IPTVCore

func makeDB() throws -> (AppDatabase, Int64) {
    let db = try AppDatabase()
    let id = try db.dbQueue.write { d -> Int64 in
        var a = Account(name: "t", kind: .xtream, server: "http://h", username: "u")
        try a.insert(d)
        return a.id!
    }
    return (db, id)
}

func addAccount(_ db: AppDatabase, _ name: String) throws -> Int64 {
    try db.dbQueue.write { d in
        var a = Account(name: name, kind: .m3u, url: "http://h/\(name).m3u")
        try a.insert(d)
        return a.id!
    }
}

func addItem(_ db: AppDatabase, _ aid: Int64, _ name: String, type: ItemType = .live,
             cat: String? = "1", sid: String? = nil) throws {
    try db.dbQueue.write { d in
        var i = Item(accountId: aid, type: type, name: name, streamId: sid ?? name, categoryId: cat)
        try i.insert(d)
    }
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (code, data) = Self.handler!(request)
        let resp = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

func mockSession() -> URLSession {
    let c = URLSessionConfiguration.ephemeral
    c.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: c)
}

func actionOf(_ r: URLRequest) -> String {
    URLComponents(url: r.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "action" }?.value ?? ""
}

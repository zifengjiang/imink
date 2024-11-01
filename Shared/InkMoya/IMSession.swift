import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol IMSessionType {
    var plugins: [PluginType] { get set }
    func request(api targetType: TargetType) async throws -> (Data, HTTPURLResponse)
}

public struct IMSession: IMSessionType {
    public static var shared: IMSession = IMSession(urlSession: URLSession.shared)

    private let urlSession: URLSession
    public var plugins: [PluginType] = []

    public init(urlSession: URLSession) {
        self.urlSession = urlSession
    }

    public func request(api target: TargetType) async throws -> (Data, HTTPURLResponse) {
        let request = plugins.reduce(target.request) { $1.prepare($0, target: target) }
        plugins.forEach { $0.willSend(request, target: target) }
        do {
            let (data, resp) = try await urlSession._ink_data(for: request)
            guard let httpResp = resp as? HTTPURLResponse else {
                throw IMSessionError.responseNotHTTP
            }
            plugins.forEach { $0.didReceive(.success((data, httpResp)), target: target) }
            return (data, httpResp)
        } catch let error {
            plugins.forEach { $0.didReceive(.failure(error), target: target) }
            throw error
        }
    }
}

extension IMSession {

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await urlSession._ink_data(for: request)
    }
}

enum IMSessionError: Error {
    case responseNotHTTP
}

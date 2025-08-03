import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol TargetType {
    var baseURL: URL { get }
    var path: String { get }
    var method: RequestMethod { get }
    var headers: [String: String]? { get }
    var querys: [(String, String?)]? { get }
    var data: MediaType? { get }
    var sampleData: Data { get }
}

extension TargetType {
    public var url: URL {
        let url = baseURL.appendingPathComponent(path)
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        if let querys = querys {
            let queryItems = querys.map { name, value in
                URLQueryItem(name: name, value: value)
            }
            urlComponents.queryItems = queryItems
        }
        return urlComponents.url!
    }

    public var request: URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = self.method.rawValue

        if let headers = self.headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        if let data = self.data {
            switch data {
            case .jsonData(let data):
                request.addValue(
                    "application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONEncoder().encode(data)
            case .form(let form):
                request.addValue(
                    "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                let queryItems = form.map { name, value in
                    URLQueryItem(name: name, value: value)
                }
                var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                urlComponents.queryItems = queryItems
                request.httpBody = urlComponents.query?.data(using: .utf8)
            case .data(let data):
                request.addValue(
                    "application/octet-stream", forHTTPHeaderField: "Content-Type")
                request.addValue(data.count.description, forHTTPHeaderField: "Content-Length")
                request.httpBody = data
            }
        }

        return request
    }
}

import Foundation
import os.log

/// 同步失败诊断。
///
/// SplatNet 3 出错时服务端常常只回一个没有 body 的 4xx/5xx，之前我们只把
/// `HTTP 400` 写进 UI 文案，看不出「到底是哪个请求、发了什么请求头、服务端说了什么」。
/// 这里把最近一次失败（以及失败请求的快照）落到 `AppUserDefaults.lastSyncDebug`，
/// 真机可以直接从 app group 的 plist 里读出来：
///
///     "lastSyncDebug" => "{\"status\":400,\"query\":\"CoopHistoryQuery\",...}"
///
public enum SyncDiagnostics {

    public struct RequestSnapshot: Codable {
        public var method: String
        public var url: String
        public var headers: [String: String]
        /// 请求体前 300 字符（GraphQL 的 variables 很小，通常能完整看到）
        public var bodyPrefix: String
    }

    public struct Snapshot: Codable {
        public var loggedAt: String
        /// 失败发生在哪一步：`bullet_tokens` / `graphql` / `other`
        public var api: String
        /// GraphQL operation 名（如 `CoopHistoryQuery`），非 GraphQL 请求为 nil
        public var query: String?
        public var method: String
        public var url: String
        /// 没有拿到 HTTP 响应（网络层错误）时为 nil
        public var status: Int?
        /// 实际发送的 `X-Web-View-Ver`
        public var webVersion: String
        /// `bundled` = 打包内置的 build；`remote` = 运行时从 jsdelivr 拿到的 build
        public var webVersionSource: String
        public var requestHeaders: [String: String]
        public var requestBodyPrefix: String
        /// 服务端响应体前 400 字符（空 body 时是 `""`）
        public var responseBody: String
        public var error: String
        /// 补充说明（如「换 build 重试后成功」）
        public var note: String?
    }

    private static let lock = NSLock()
    private static var _last: Snapshot?
    private static var _lastRequest: (api: String?, request: RequestSnapshot)?

    /// 最近一次失败快照
    public static var last: Snapshot? {
        lock.lock()
        defer { lock.unlock() }
        return _last
    }

    /// 把即将发出的请求记下来，失败时就能原样回放「我们到底发了什么」。
    /// 只记录 SplatNet 3 的请求，避免把 NSO 的登录请求也存进 prefs。
    public static func noteRequest(_ request: URLRequest) {
        guard let url = request.url,
              url.host == "api.lp1.av5ja.srv.nintendo.net" else {
            return
        }

        var headers: [String: String] = [:]
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            // Cookie 里有 `_gtoken`（相当于登录票据），落盘前脱敏
            if key.lowercased() == "cookie" {
                headers[key] = redactCookies(value)
            } else {
                headers[key] = value
            }
        }

        let body = request.httpBody.flatMap { String(data: $0.prefix(600), encoding: .utf8) } ?? ""
        let snapshot = RequestSnapshot(
            method: request.httpMethod ?? "GET",
            url: url.absoluteString,
            headers: headers,
            bodyPrefix: String(body.prefix(300))
        )

        let api = url.path.contains("bullet_tokens") ? "bullet_tokens" : (url.path.contains("graphql") ? "graphql" : nil)
        lock.lock()
        _lastRequest = (api, snapshot)
        lock.unlock()
    }

    public static func clear() {
        lock.lock()
        _last = nil
        _lastRequest = nil
        lock.unlock()
    }

    /// 记录一次失败。会立刻写进 `AppUserDefaults.lastSyncDebug` + 系统日志。
    public static func noteFailure(
        api: String,
        query: String?,
        webVersion: String,
        webVersionSource: String,
        status: Int?,
        responseBody: String?,
        error: String
    ) {
        lock.lock()
        let request = _lastRequest?.request
        lock.unlock()

        let body = (responseBody ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshot = Snapshot(
            loggedAt: ISO8601DateFormatter().string(from: Date()),
            api: api,
            query: query,
            method: request?.method ?? "POST",
            url: request?.url ?? "-",
            status: status,
            webVersion: webVersion,
            webVersionSource: webVersionSource,
            requestHeaders: request?.headers ?? [:],
            requestBodyPrefix: request?.bodyPrefix ?? "",
            responseBody: String(body.prefix(400)),
            error: error,
            note: nil
        )

        lock.lock()
        _last = snapshot
        lock.unlock()

        if let data = try? JSONEncoder().encode(snapshot),
           let json = String(data: data, encoding: .utf8) {
            AppUserDefaults.shared.lastSyncDebug = json
            os_log(
                "syncDebug %{public}@",
                log: .default,
                type: .error,
                json
            )
        }
    }

    /// 给 UI 用的一行摘要，例如：
    /// `HTTP 400 · CoopHistoryQuery · X-Web-View-Ver=10.0.0-4787c271(bundled) · body=""`
    public static func oneLine(_ snapshot: Snapshot) -> String {
        var parts: [String] = []
        parts.append(snapshot.status.map { "HTTP \($0)" } ?? "无响应")
        if let query = snapshot.query, !query.isEmpty {
            parts.append(query)
        } else {
            parts.append(snapshot.api)
        }
        parts.append("X-Web-View-Ver=\(snapshot.webVersion)(\(snapshot.webVersionSource))")
        let body = snapshot.responseBody.isEmpty ? "空" : snapshot.responseBody
        parts.append("body=\(body.count > 160 ? String(body.prefix(160)) + "…" : body)")
        return parts.joined(separator: " · ")
    }

    private static func redactCookies(_ value: String) -> String {
        value.split(separator: ";").map { pair -> String in
            let text = pair.trimmingCharacters(in: .whitespaces)
            guard let equals = text.firstIndex(of: "=") else { return text }
            let name = text[text.startIndex..<equals]
            return "\(name)=<redacted>"
        }.joined(separator: "; ")
    }
}

// MARK: - 版本服务可用性日志

/// 远端版本服务拿到了新 build：`X-Web-View-Ver` 会被换成它。
func logSyncVersion(bundled: String, remote: String) {
    os_log(
        "syncVersion bundled=%{public}@ remote=%{public}@",
        log: .default,
        type: .info,
        bundled,
        remote
    )
}

/// 远端版本服务不可用：只能继续用打包内置的 build，服务端可能因此拒绝请求。
func logSyncVersionFallback(bundled: String) {
    os_log(
        "syncVersion fallback=bundled(%{public}@) remote=unavailable",
        log: .default,
        type: .error,
        bundled
    )
}

// MARK: - 版本探测器

extension SyncDiagnostics {
    /// 400/403 后换一个 build 重试成功：记下「哪个 build 能用」，下次就不会再撞。
    static func noteRecovered(query: String, status: Int, responseBody: String?, retriedWith: String) {
        recordProbe(
            query: query,
            status: status,
            responseBody: responseBody,
            retriedWith: retriedWith,
            outcome: "换 build 重试后成功（原始 \(status) 是 X-Web-View-Ver 过期导致的）"
        )
    }

    /// 换 build 也失败：说明 400 不是版本头引起的，把两次结果都留下来。
    static func noteVersionProbeFailed(
        query: String,
        status: Int,
        responseBody: String?,
        retriedWith: String,
        retryError: String
    ) {
        recordProbe(
            query: query,
            status: status,
            responseBody: responseBody,
            retriedWith: retriedWith,
            outcome: "换 build（\(retriedWith)）后仍然失败：\(retryError)"
        )
    }

    private static func recordProbe(
        query: String,
        status: Int,
        responseBody: String?,
        retriedWith: String,
        outcome: String
    ) {
        lock.lock()
        let request = _lastRequest?.request
        let version = _last?.webVersion ?? "-"
        let versionSource = _last?.webVersionSource ?? "-"
        let body = (responseBody ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshot = Snapshot(
            loggedAt: ISO8601DateFormatter().string(from: Date()),
            api: "graphql",
            query: query,
            method: request?.method ?? "POST",
            url: request?.url ?? "-",
            status: status,
            webVersion: version,
            webVersionSource: versionSource,
            requestHeaders: request?.headers ?? [:],
            requestBodyPrefix: request?.bodyPrefix ?? "",
            responseBody: String(body.prefix(400)),
            error: "graphql[\(query)] 返回 \(status)",
            note: "\(outcome)（重试用 \(retriedWith)）"
        )
        _last = snapshot
        lock.unlock()

        if let data = try? JSONEncoder().encode(snapshot),
           let json = String(data: data, encoding: .utf8) {
            AppUserDefaults.shared.lastSyncDebug = json
            os_log("syncVersionProbe %{public}@", log: .default, type: .error, json)
        }
    }
}

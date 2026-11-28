import Foundation

private struct SplatNetRemoteConfiguration: Decodable {
    let webAppVersion: String
    let graphQLQueries: [String: String]

    private enum CodingKeys: String, CodingKey {
        case webAppVersion = "web_app_ver"
        case graphQLQueries = "graphql_queries"
    }
}

public class SN3Client {
    public static let shared = try! SN3Client()
    private var session: IMSessionType = IMSession.shared
    private let internalAuthorizationStorage: SN3AuthorizationStorage

    /// 版本服务（jsdelivr / raw.githubusercontent）里 SplatNet 3 元数据的镜像。
    /// 国内网络访问 cdn.jsdelivr.net 经常失败，一旦失败就只能用打包内置的旧 build，
    /// 而旧 build 很可能被服务端拒绝（400）。
    private static let remoteConfigurationURLs = [
        "https://cdn.jsdelivr.net/gh/nintendoapis/nintendo-app-versions/data/splatnet3-app.json",
        "https://fastly.jsdelivr.net/gh/nintendoapis/nintendo-app-versions/data/splatnet3-app.json",
        "https://gcore.jsdelivr.net/gh/nintendoapis/nintendo-app-versions/data/splatnet3-app.json",
        "https://raw.githubusercontent.com/nintendoapis/nintendo-app-versions/main/data/splatnet3-app.json",
    ]

    public var webVersion: String
    /// `bundled` = 打包内置的 build；`remote` = 运行时从版本服务拿到的 build
    private var webVersionSource = "bundled"
    /// 打包内置的 build（App 发版时的那份）
    private let bundledWebVersion: String
    /// 版本服务声明的 build；拿不到就是 nil
    private var remoteWebVersion: String?
    /// 出现 400/403 时是否已经试过切到另一个 build（只试一次，避免打转）
    private var hasTriedAlternateWebVersion = false

    /// 诊断/日志用的版本描述：`10.0.0-4787c271(bundled)`
    public var webVersionSourceLabel: String { webVersionSource }
    private var graphQLHashMap: [String: String]
    private var hasAttemptedWebConfigurationRefresh = false
    private var gameServiceToken: String? = nil
    private var hasLoadedWebVersion = false
    private var country = "US"
    private var accountLanguage = "en-US"
    private var interfaceLanguage = "en-GB"

    public var authorizationStorage: SN3AuthorizationStorage {
        internalAuthorizationStorage
    }

    public init() throws {
        let webViewDataUrl = Bundle.main.url(forResource: "splatnet3_webview_data", withExtension: "json")
        let webViewData = try JSONDecoder().decode(SN3WebViewData.self, from: try Data(contentsOf: webViewDataUrl!))
        self.webVersion = webViewData.version
        self.bundledWebVersion = webViewData.version
        self.graphQLHashMap = webViewData.graphql.hash_map
        self.internalAuthorizationStorage = AuthorizationMemoryStorage()

//        try await refreshBullet()
    }
    
    public func setToken(_ token: String) async throws{
        self.gameServiceToken = token
        try await refreshBullet()
    }

    public func setToken(
        _ token: String,
        country: String,
        accountLanguage: String,
        interfaceLanguage: String
    ) async throws {
        self.country = country
        self.accountLanguage = accountLanguage
        self.interfaceLanguage = interfaceLanguage
        try await setToken(token)
    }

    /// 依次尝试多个镜像，拿到 SplatNet 3 的 build 号与 hash_map。
    private func loadRemoteConfiguration() async -> SplatNetRemoteConfiguration? {
        for urlString in Self.remoteConfigurationURLs {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(
                url: url,
                cachePolicy: .reloadRevalidatingCacheData,
                timeoutInterval: 8
            )
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let configuration = try? JSONDecoder().decode(
                      SplatNetRemoteConfiguration.self,
                      from: data
                  ),
                  !configuration.webAppVersion.isEmpty else {
                continue
            }
            return configuration
        }
        return nil
    }

    private func apply(_ configuration: SplatNetRemoteConfiguration) {
        if configuration.webAppVersion != bundledWebVersion {
            logSyncVersion(bundled: bundledWebVersion, remote: configuration.webAppVersion)
        }
        remoteWebVersion = configuration.webAppVersion
        webVersion = configuration.webAppVersion
        webVersionSource = "remote"
        graphQLHashMap.merge(configuration.graphQLQueries) { _, remote in remote }
    }

    @MainActor
    func refreshWebConfigurationIfAvailable() async {
        guard !hasAttemptedWebConfigurationRefresh else {
            return
        }
        hasAttemptedWebConfigurationRefresh = true

        guard let configuration = await loadRemoteConfiguration() else {
            logSyncVersionFallback(bundled: bundledWebVersion)
            return
        }

        apply(configuration)
        // hash_map 变了必须重建 plugin，否则后续请求还在用旧 hash
        try? await configureSession()
    }

    public func refreshBullet() async throws {
        if !hasLoadedWebVersion {
            hasLoadedWebVersion = true
            if let configuration = await loadRemoteConfiguration() {
                apply(configuration)
            } else {
                // 拿不到远端版本：明确留痕。这种时候 X-Web-View-Ver 是打包时的旧 build，
                // 服务端很可能直接 400（而旧代码只会在日志里留下一个 catch）
                logSyncVersionFallback(bundled: bundledWebVersion)
            }
        }
        try await configureSession()

        if try await authorizationStorage.getBulletTokens() == nil {
            try await makeBullet()
        }
    }

    /// 服务端用 400/403 拒绝时，唯一能现场取证的动作：把 `X-Web-View-Ver` 换成
    /// 另一个候选 build 再试一次（远端 ↔ 打包），并把结果记进诊断。
    /// 只做一次，不会无限重试。
    private func tryAlternateWebVersion() async -> String? {
        guard !hasTriedAlternateWebVersion else { return nil }
        hasTriedAlternateWebVersion = true

        if remoteWebVersion == nil, let configuration = await loadRemoteConfiguration() {
            apply(configuration)
            try? await configureSession()
            return "remote-\(webVersion)"
        }

        let alternate: String
        let alternateSource: String
        if webVersion == bundledWebVersion, let remote = remoteWebVersion {
            alternate = remote
            alternateSource = "remote"
        } else {
            alternate = bundledWebVersion
            alternateSource = "bundled"
        }

        guard alternate != webVersion else { return nil }

        webVersion = alternate
        webVersionSource = alternateSource
        try? await configureSession()
        return "\(alternateSource)-\(alternate)"
    }

    public func graphQL<T: SN3PersistedQuery>(_ query: T)  async throws -> Data {
        do {
            return try await requestGraphQL(query)
        } catch Error.invalidBulletToken {
            try await makeBullet()
            return try await graphQL(query)
        } catch let Error.responseError(code, url, body) where code == 400 || code == 403 {
            // 400/403 但 body 为空时，最可能的原因就是 `X-Web-View-Ver` 指的 build 已过期。
            // 换另一个候选 build 再试一次，结果写进 lastSyncDebug。
            guard let used = await tryAlternateWebVersion() else {
                throw Error.responseError(code: code, url: url, body: body)
            }
            do {
                let data = try await requestGraphQL(query)
                SyncDiagnostics.noteRecovered(
                    query: T.name,
                    status: code,
                    responseBody: body,
                    retriedWith: used
                )
                return data
            } catch {
                SyncDiagnostics.noteVersionProbeFailed(
                    query: T.name,
                    status: code,
                    responseBody: body,
                    retriedWith: used,
                    retryError: "\(error)"
                )
                throw error
            }
        }
    }
}


extension SN3Client {
    private func makeBullet() async throws {
        guard let gameServiceToken = gameServiceToken else {
            // 以前这里静默 return，调用方完全看不出「根本没发请求」
            SyncDiagnostics.noteFailure(
                api: "bullet_tokens",
                query: nil,
                webVersion: webVersion,
                webVersionSource: webVersionSource,
                status: nil,
                responseBody: nil,
                error: "gameServiceToken 为空，未发起 bullet_tokens 请求"
            )
            throw Error.noGameServiceToken
        }
        let (data, res) = try await session.request(
            api: SN3API.bulletTokens(
                gameServiceToken: gameServiceToken,
                country: country,
                accountLanguage: accountLanguage,
                interfaceLanguage: interfaceLanguage
            )
        )
        switch res.statusCode {
        case 200, 201:
            break // OK
        case 401:
            throw Error.invalidGameServiceToken
        case let code:
            SyncDiagnostics.noteFailure(
                api: "bullet_tokens",
                query: nil,
                webVersion: webVersion,
                webVersionSource: webVersionSource,
                status: code,
                responseBody: String(data: data, encoding: .utf8),
                error: "bullet_tokens 返回 \(code)"
            )
            throw Error.responseError(code: code, url: res.url, body: String(data: data, encoding: .utf8))
        }

        let bulletTokens = try JSONDecoder().decode(BulletTokens.self, from: data)

        try await internalAuthorizationStorage.setBulletTokens(bulletTokens)
        try await configureSession()
    }
}

extension SN3Client {
    
    private func requestGraphQL<T: SN3PersistedQuery>(_ query: T) async throws -> Data {
        let (data, res) = try await session.request(api: query)
        let statusCode = res.statusCode
        if statusCode == 401 {
            throw Error.invalidBulletToken
        }

        if statusCode != 200 {
            SyncDiagnostics.noteFailure(
                api: "graphql",
                query: T.name,
                webVersion: webVersion,
                webVersionSource: webVersionSource,
                status: statusCode,
                responseBody: String(data: data, encoding: .utf8),
                error: "graphql[\(T.name)] 返回 \(statusCode)"
            )
            throw Error.responseError(code: res.statusCode, url: res.url, body: String(data: data, encoding: .utf8))
        }


        return data

    }
}

extension SN3Client {
    private func configureSession() async throws {
        var plugins = [PluginType]()

        plugins.append(WebVersionPlugin(webVersion: webVersion))
        plugins.append(GraphQLPlugin(graphQLHashMap: graphQLHashMap))

        if let bulletTokens = try await internalAuthorizationStorage.getBulletTokens() {
            plugins.append(BulletTokenPlugin(bulletToken: bulletTokens.bulletToken))
        }

        session.plugins = plugins
    }
}

public extension SN3Client {
    enum Error: Swift.Error {
        case noGameServiceToken
        case missingGameServiceToken
        case invalidGameServiceToken
        case tooManyRequests
        case invalidBulletToken
        case responseError(code: Int, url: URL? = nil, body: String? = nil)
        /// detail 一条都没拉下来（网络/令牌/限流之外的失败）
        case noDetailFetched(message: String)
    }
}

extension SN3Client.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noGameServiceToken:
            return "缺少游戏服务令牌（没有发起请求），请重新登录"
        case .missingGameServiceToken:
            return "游戏服务令牌缺失或已过期，请重新登录后再试"
        case .invalidGameServiceToken:
            return "游戏服务令牌无效或已过期，请重新登录"
        case .tooManyRequests:
            return "请求过于频繁，请稍后再试"
        case .invalidBulletToken:
            return "Bullet token 无效，请重新登录"
        case let .responseError(code, _, body):
            if let body, !body.isEmpty {
                return "服务返回错误（HTTP \(code)）：\(body.prefix(120))"
            }
            return "服务返回错误（HTTP \(code)），请稍后重试"
        case let .noDetailFetched(message):
            return "详情拉取失败：\(message)"
        }
    }
}

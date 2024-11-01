import Foundation

public class SN3Client {
    public static let shared = try! SN3Client()
    private var session: IMSessionType = IMSession.shared
    private let internalAuthorizationStorage: SN3AuthorizationStorage

    public var webVersion: String
    private let graphQLHashMap: [String: String]
    private var gameServiceToken: String? = nil

    public var authorizationStorage: SN3AuthorizationStorage {
        internalAuthorizationStorage
    }

    public init() throws {
        let webViewDataUrl = Bundle.main.url(forResource: "splatnet3_webview_data", withExtension: "json")
        let webViewData = try JSONDecoder().decode(SN3WebViewData.self, from: try Data(contentsOf: webViewDataUrl!))
        self.webVersion = webViewData.version
        self.graphQLHashMap = webViewData.graphql.hash_map
        self.internalAuthorizationStorage = AuthorizationMemoryStorage()

//        try await refreshBullet()
    }
    
    public func setToken(_ token: String) async throws{
        self.gameServiceToken = token
        try await refreshBullet()
    }

    public func refreshBullet() async throws {
        try await configureSession()

        if try await authorizationStorage.getBulletTokens() == nil {
            try await makeBullet()
        }
    }

    public func graphQL<T: SN3PersistedQuery>(_ query: T)  async throws -> Data {
        do {
            return try await requestGraphQL(query)
        } catch Error.invalidBulletToken {
            try await makeBullet()
            return try await graphQL(query)
        }
    }
}


extension SN3Client {
    private func makeBullet() async throws {
        guard let gameServiceToken = gameServiceToken else {return}
        let (data, res) = try await session.request(api: SN3API.bulletTokens(gameServiceToken: gameServiceToken))
        switch res.statusCode {
        case 200, 201:
            break // OK
        case 401:
            throw Error.invalidGameServiceToken
        case let code:
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
        case invalidGameServiceToken
        case invalidBulletToken
        case responseError(code: Int, url: URL? = nil, body: String? = nil)
    }
}

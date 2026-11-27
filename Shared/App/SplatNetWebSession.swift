import Foundation
import SwiftUI

struct SplatNetWebSession: Hashable, Sendable {
    let gameWebToken: String
    let country: String
    let accountLanguage: String
}

enum SplatNetWebSessionError: LocalizedError {
    case missingGameWebToken
    case missingSessionToken
    case missingAccountLocale
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case .missingGameWebToken:
            return "无法获取鱿鱼圈 3 游戏服务令牌"
        case .missingSessionToken:
            return "Nintendo 账户登录已失效，请重新登录"
        case .missingAccountLocale:
            return "无法获取 Nintendo 账户的地区和语言"
        case .invalidRequest:
            return "无法创建鱿鱼圈 3 请求"
        }
    }
}

enum SplatNetWebSessionProvider {
    @MainActor
    private static var inFlightLoad: Task<SplatNetWebSession, Error>?

    @MainActor
    static func load() async throws -> SplatNetWebSession {
        if let inFlightLoad {
            return try await inFlightLoad.value
        }

        let task = Task {
            try await loadUncoalesced()
        }
        inFlightLoad = task

        defer {
            inFlightLoad = nil
        }
        return try await task.value
    }

    @MainActor
    static func loadGameWebToken() async throws -> String {
        try await effectiveGameWebToken()
    }

    @MainActor
    private static func loadUncoalesced() async throws -> SplatNetWebSession {
        let gameWebToken = try await loadGameWebToken()
        let accountLocale = try await accountLocale()

        return SplatNetWebSession(
            gameWebToken: gameWebToken,
            country: accountLocale.country,
            accountLanguage: accountLocale.language
        )
    }

    @MainActor
    private static func effectiveGameWebToken() async throws -> String {
        let defaults = AppUserDefaults.shared

        if defaults.useManualGameServiceToken {
            guard let token = normalized(defaults.manualGameServiceToken) else {
                throw SplatNetWebSessionError.missingGameWebToken
            }
            return token
        }

        let now = Int(Date().timeIntervalSince1970)
        let storedToken = normalized(defaults.gameServiceToken)
        let needsRefresh = storedToken == nil
            || defaults.gameServiceTokenRefreshTime + 3600 < now

        if needsRefresh {
            guard normalized(defaults.sessionToken) != nil else {
                throw SplatNetWebSessionError.missingSessionToken
            }
            try await NSOAccountManager.shared.refreshGameServiceTokenManual()
        }

        guard let token = normalized(defaults.gameServiceToken) else {
            throw SplatNetWebSessionError.missingGameWebToken
        }
        return token
    }

    @MainActor
    private static func accountLocale() async throws -> (country: String, language: String) {
        let defaults = AppUserDefaults.shared

        if let country = normalized(defaults.nintendoAccountCountry),
           let language = normalized(defaults.nintendoAccountLanguage) {
            return (country, language)
        }

        guard let sessionToken = normalized(defaults.sessionToken) else {
            throw SplatNetWebSessionError.missingSessionToken
        }

        let loginToken = try await NSOAuthorization.shared.requestLoginToken(
            sessionToken: sessionToken
        )
        let user = try await NSOAuthorization.shared.requestUserInfo(
            accessToken: loginToken.accessToken
        )

        guard let country = normalized(user.country),
              let language = normalized(user.language) else {
            throw SplatNetWebSessionError.missingAccountLocale
        }

        defaults.nintendoAccountCountry = country
        defaults.nintendoAccountLanguage = language
        return (country, language)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

enum SplatNetWebRequestBuilder {
    static let allowedHost = "api.lp1.av5ja.srv.nintendo.net"

    static let androidWebViewUserAgent = "Mozilla/5.0 (Linux; Android 11; sdk_gphone_arm64 Build/RSR1.210722.013.A6; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/91.0.4472.114 Mobile Safari/537.36"

    static func request(
        for session: SplatNetWebSession,
        interfaceLanguage: String,
        colorScheme: ColorScheme
    ) throws -> URLRequest {
        let token = session.gameWebToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = session.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountLanguage = session.accountLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        let interfaceLanguage = interfaceLanguage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !token.isEmpty, !country.isEmpty, !accountLanguage.isEmpty,
              !interfaceLanguage.isEmpty,
              var components = URLComponents(
                string: "https://\(allowedHost)/"
              ) else {
            throw SplatNetWebSessionError.invalidRequest
        }

        components.queryItems = [
            URLQueryItem(name: "lang", value: interfaceLanguage),
            URLQueryItem(name: "na_country", value: country),
            URLQueryItem(name: "na_lang", value: accountLanguage),
        ]

        guard let url = components.url,
              url.scheme == "https",
              url.host == allowedHost else {
            throw SplatNetWebSessionError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("\(interfaceLanguage);q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(androidWebViewUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            colorScheme == .dark ? "DARK" : "LIGHT",
            forHTTPHeaderField: "X-AppColorScheme"
        )
        request.setValue(token, forHTTPHeaderField: "X-GameWebToken")
        request.setValue("com.nintendo.znca", forHTTPHeaderField: "X-Requested-With")
        return request
    }
}

enum SplatNetWebLanguage {
    static func identifier(for localization: String?) -> String {
        guard let localization else {
            return "en-US"
        }

        let components = localization
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
            .split(separator: "-")
            .map(String.init)

        guard let language = components.first else {
            return "en-US"
        }

        switch language {
        case "zh":
            let usesTraditionalChinese = components.contains("hant")
                || components.contains("tw")
                || components.contains("hk")
                || components.contains("mo")
            return usesTraditionalChinese ? "zh-TW" : "zh-CN"
        case "ja":
            return "ja-JP"
        case "ko", "kr":
            return "ko-KR"
        case "de":
            return "de-DE"
        case "es":
            return components.contains("mx") ? "es-MX" : "es-ES"
        case "fr":
            return components.contains("ca") ? "fr-CA" : "fr-FR"
        case "it":
            return "it-IT"
        case "nl":
            return "nl-NL"
        case "ru":
            return "ru-RU"
        case "en":
            let usesBritishEnglish = components.contains("gb")
                || components.contains("au")
                || components.contains("nz")
                || components.contains("ie")
            return usesBritishEnglish ? "en-GB" : "en-US"
        default:
            return "en-US"
        }
    }
}

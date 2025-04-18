//
//  NSOAPI.swift
//  imink
//
//  Created by Jone Wang on 2021/3/12.
//

import Foundation
import CryptoKit

enum NSOAPI {
    case authorize(codeVerifier: String)
    case sessionToken(codeVerifier: String, sessionTokenCode: String)
    case token(sessionToken: String)
    case me(accessToken: String)
    case login(requestId: String,
               naIdToken: String,
               naBirthday: String,
               naCountry: String,
               language: String,
               timestamp: Int64,
               f: String)
    case getWebServiceToken(
            webApiServerToken: String,
            f: NSOAuthorization.F)
}

extension NSOAPI: TargetType {
    private static let clientId = "71b963c1b7b6d119"
    public static let clientUrlScheme = "npf\(NSOAPI.clientId)"
    private static var clientVersion: String {
        AppUserDefaults.shared.NSOVersion
    }
    private static let gameServiceId = 4834290508791808
    private static let flapgAPIVersion = "3"
    
    var baseURL: URL {
        switch self {
        case .authorize,
             .sessionToken,
             .token:
            return URL(string: "https://accounts.nintendo.com/connect/1.0.0")!
        case .me:
            return URL(string: "https://api.accounts.nintendo.com/2.0.0")!
        case .login, .getWebServiceToken:
            return URL(string: "https://api-lp1.znc.srv.nintendo.net")!
        }
    }
    
    var path: String {
        switch self {
        case .authorize:
            return "/authorize"
        case .sessionToken:
            return "/api/session_token"
        case .token:
            return "/api/token"
        case .me:
            return "/users/me"
        case .login:
            return "/v3/Account/Login"
        case .getWebServiceToken:
            return "/v2/Game/GetWebServiceToken"
        }
    }
    
    var method: RequestMethod {
        switch self {
        case .authorize,
             .me:
            return .get
        case .sessionToken,
             .token,
             .login,
             .getWebServiceToken:
            return .post
        }
    }
    
    var headers: [String : String]? {
        switch self {
        case .authorize:
            return [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.1 Mobile/15E148 Safari/604.1",
                "Host" : "accounts.nintendo.com"
            ]
        case .sessionToken,
             .token:
            return [
                "Accept": "application/json",
                "User-Agent" : "Dalvik/2.1.0 (Linux; U; Android 11; sdk_gphone_arm64 Build/RSR1.210722.013.A6)"
            ]
        case .me(let accessToken):
            return [
                "Accept": "application/json",
                "User-Agent": "NASDKAPI; Android",
                "Authorization": "Bearer \(accessToken)",
                "Accept-Encoding": "gzip, deflate, br"
            ]
        case .login:
            return [
                "Accept": "application/json",
                "User-Agent": "com.nintendo.znca/\(NSOAPI.clientVersion)(Android/11)",
                "X-Platform": "Android",
                "X-ProductVersion": NSOAPI.clientVersion,
                "Accept-Encoding": "gzip"
            ]
        case .getWebServiceToken(let webApiServerToken, _):
            return [
                "User-Agent": "com.nintendo.znca/\(NSOAPI.clientVersion)(Android/11)",
                "Authorization": "Bearer \(webApiServerToken)",
                "x-platform": "Android",
                "X-ProductVersion": NSOAPI.clientVersion,
                "Accept-Encoding": "gzip"
            ]
        }
    }
    
    var querys: [(String, String?)]? {
        switch self {
        case .authorize(let codeVerifier):
            let state = NSOHash.urandom(length: 36).base64EncodedString

            let codeDigest = SHA256.hash(
                data: codeVerifier
                    .replacingOccurrences(of: "=", with: "")
                    .data(using: .utf8)!
            )
            let codeChallenge = Data(codeDigest)
                .base64EncodedString
                .replacingOccurrences(of: "=", with: "")
            
            return [
                ("state", state),
                ("redirect_uri", "\(NSOAPI.clientUrlScheme)://auth"),
                ("client_id", NSOAPI.clientId),
                ("scope", "openid user user.birthday user.mii user.screenName"),
                ("response_type", "session_token_code"),
                ("session_token_code_challenge", codeChallenge),
                ("session_token_code_challenge_method", "S256"),
                ("theme", "login_form")
            ]
        default:
            return nil
        }
    }
    
    var data: MediaType? {
        switch self {
        case .sessionToken(let codeVerifier, let sessionTokenCode):
            let codeVerifier = codeVerifier.replacingOccurrences(of: "=", with: "")
            return .form([
                ("client_id", NSOAPI.clientId),
                ("session_token_code", sessionTokenCode),
                ("session_token_code_verifier", codeVerifier)
            ])
        case .token(let sessionToken):
            return .jsonData([
                "client_id": NSOAPI.clientId,
                "session_token": sessionToken,
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer-session-token"
            ])
        case .login(let requestId,
                    let naIdToken,
                    let naBirthday,
                    let naCountry,
                    let language,
                    let timestamp,
                    let f):
            return .jsonData(
                AccountLoginBody(
                    parameter: AccountLoginParamemter(
                        requestId: requestId,
                        naIdToken: naIdToken,
                        naBirthday: naBirthday,
                        naCountry: naCountry,
                        timestamp: timestamp,
                        language: language,
                        f: f
                    )
                )
            )
        case .getWebServiceToken(_, let f):
            return .jsonData(
                WebServiceTokenBody(
                    parameter: WebServiceTokenParamemter(
                        id: NSOAPI.gameServiceId,
                        requestId: f.requestId,
                        registrationToken: "",
                        timestamp: f.timestamp,
                        f: f.f)
                )
            )
        default:
            return nil
        }
    }

    var sampleData: Data {
        Data()
    }
}

fileprivate struct AccountLoginBody: Codable {
    var parameter: AccountLoginParamemter
}

fileprivate struct AccountLoginParamemter: Codable {
    var requestId: String
    var naIdToken: String
    var naBirthday: String
    var naCountry: String
    var timestamp: Int64
    var language: String
    var f: String
}

fileprivate struct WebServiceTokenBody: Codable {
    var parameter: WebServiceTokenParamemter
}

fileprivate struct WebServiceTokenParamemter: Codable {
    var id: Int
    var requestId: String
    var registrationToken: String
    var timestamp: Int64
    var f: String
}


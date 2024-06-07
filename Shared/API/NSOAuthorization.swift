import Foundation
import AuthenticationServices
import SwiftyJSON


class NSOAuthorization:NSObject,ASWebAuthenticationPresentationContextProviding {
    static let shared = NSOAuthorization()

    let decoder = snakeCaseDecoder()

    static private func snakeCaseDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    func login() async throws -> String{
        let codeVerifier = NSOHash.urandom(length: 32).base64EncodedString
        let authorizeAPI = NSOAPI.authorize(codeVerifier: codeVerifier)
        guard let sessionTokenCode = try await presentLoginSession(url: authorizeAPI.url)?.sessionTokenCode else {throw NSOAuthError.invalidCallbackURL}
        let sessionTokenAPI = NSOAPI.sessionToken(codeVerifier: codeVerifier, sessionTokenCode:sessionTokenCode)
        let (data, response) = try await URLSession.shared.data(for: sessionTokenAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }
        let json = JSON(data)
        return json["session_token"].stringValue
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if Thread.isMainThread {
            return ASPresentationAnchor()
        } else {
            var anchor: ASPresentationAnchor?
            DispatchQueue.main.sync {
                anchor = ASPresentationAnchor()
            }
            return anchor!
        }
    }

    func presentLoginSession(url: URL) async throws -> URL? {
        return try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "npf71b963c1b7b6d119") { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: callbackURL)
                }
            }
            authSession.presentationContextProvider = self
            authSession.start()
        }
    }
    
    func requestF(naId:String, accessToken:String, hashMethod:AppAPI.HashMethod) async throws -> F {
        do {
            let fAPI = AppAPI.nxapiZnca_f(naId: naId, naIdToken: accessToken, hashMethod: hashMethod)
            return try await requestF(fAPI: fAPI)
        } catch {
            let fAPI = AppAPI.imink_f(naId: naId, naIdToken: accessToken, hashMethod: hashMethod)
            return try await requestF(fAPI: fAPI)
        }
    }

    func requestF(fAPI:AppAPI) async throws -> F {
        let (data, response) = try await URLSession.shared.data(for: fAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }
        return try decoder.decode(F.self, from: data)
    }

    func requestUserInfo(accessToken:String) async throws -> NAUser {
        let meAPI = NSOAPI.me(accessToken: accessToken)
        let (data, response) = try await URLSession.shared.data(for: meAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }
        return try decoder.decode(NAUser.self, from: data)
    }

    func requestLoginToken(sessionToken:String) async throws -> LoginToken{
        let tokenAPI = NSOAPI.token(sessionToken: sessionToken)
        let (data, response) = try await URLSession.shared.data(for: tokenAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }

        return try decoder.decode(LoginToken.self, from: data)
    }
    
    func requestWebServiceToken(webApiServerToken: String,
                                accessToken: String,
                                naUser: NAUser) async throws -> WebServiceToken {
        let f = try await requestF(naId:naUser.id, accessToken: webApiServerToken, hashMethod: .hash2)
        let webServiceTokenAPI = NSOAPI.getWebServiceToken(webApiServerToken: webApiServerToken, f: f)
        let (data, response) = try await URLSession.shared.data(for: webServiceTokenAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }
        return try decoder.decode(WebServiceToken.self, from: data)
    }

    func requestLogin(accessToken:String, naUser:NAUser) async throws -> LoginResult {
        let f = try await requestF(naId:naUser.id, accessToken: accessToken, hashMethod: .hash1)
        let loginAPI = NSOAPI.login(requestId: f.requestId, naIdToken: accessToken, naBirthday: naUser.birthday, naCountry: naUser.country, language: naUser.language, timestamp: f.timestamp, f: f.f)
        let (data, response) = try await URLSession.shared.data(for: loginAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }
        return LoginResult(json: try JSON(data: data))
    }

    func requestWebServiceToken(sessionToken:String) async throws -> WebServiceToken {
        let apiToken = try await requestLoginToken(sessionToken: sessionToken)
        let naUser = try await requestUserInfo(accessToken: apiToken.accessToken)
        let loginResult = try await requestLogin(accessToken: apiToken.accessToken, naUser: naUser)
        let webServiceToken = try await requestWebServiceToken(webApiServerToken: loginResult.result.webApiServerCredential.accessToken, accessToken: apiToken.accessToken, naUser: naUser)
        return webServiceToken
    }

}

extension NSOAuthorization {
    enum NSOAuthError:Error{
        case invalidCallbackURL
        case invalidSessionToken
        case invalidLoginToken
        case responseError(code: Int, url: URL? = nil, body: String? = nil)
    }
}

extension NSOAuthorization{
    struct F: Decodable {
        let f: String
        let timestamp: Int64
        let requestId: String
        init(json:JSON) {
            f = json["f"].stringValue
            timestamp = json["timestamp"].int64Value
            requestId = json["request_id"].stringValue
        }
    }
}

extension NSOAuthorization {
    struct LoginToken:Decodable {
        var accessToken: String
        var idToken: String
        var expiresIn: Int

        init(json:JSON) {
            accessToken = json["access_token"].stringValue
            idToken = json["id_token"].stringValue
            expiresIn = json["expires_in"].intValue
        }
    }
}

extension NSOAuthorization {
    struct NAUser:Decodable {
        var birthday: String
        var country: String
        var language: String
        var id: String
    }
}

extension NSOAuthorization {
    struct WebServiceToken: Decodable {
        let result: `Result`

        struct `Result`: Decodable {
            let accessToken: String
            let expiresIn: Int
            init(json:JSON) {
                accessToken = json["accessToken"].stringValue
                expiresIn = json["expiresIn"].intValue
            }
        }
        init(json:JSON) {
            result = Result(json: json["result"])
        }
    }
}

extension NSOAuthorization {
    struct LoginResult: Decodable {
        let result: `Result`

        struct `Result`: Decodable {
            let webApiServerCredential: WebApiServerCredential
            let user:User
            init(json:JSON) {
                webApiServerCredential = WebApiServerCredential(json: json["webApiServerCredential"])
                user = User(json: json["user"])
            }

            struct WebApiServerCredential: Decodable {
                let accessToken: String
                init(json:JSON){
                    accessToken = json["accessToken"].stringValue
                }
            }

            struct User: Decodable {
                let imageUri: String
                let id:Int64
                let friendCode:String
                let name:String
                init(json:JSON) {
                    imageUri = json["imageUri"].stringValue
                    id = json["id"].int64Value
                    friendCode = json["links"]["friendCode"]["id"].stringValue
                    name = json["name"].stringValue
                }
            }
        }
        init(json:JSON) {
            result = Result(json: json["result"])
        }

    }
}

extension URL {
    var sessionTokenCode: String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        var combinedQuery = components.query ?? ""
        if let fragment = components.fragment {
            combinedQuery += "&" + fragment
        }

        guard let queryItems = URLComponents(string: "?" + combinedQuery)?.queryItems else { return nil }
        return queryItems.first(where: { $0.name == "session_token_code" })?.value
    }
}

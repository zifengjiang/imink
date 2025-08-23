import Foundation
import AuthenticationServices
import SwiftyJSON



class NSOAuthorization:NSObject,ASWebAuthenticationPresentationContextProviding {
    static let shared = NSOAuthorization()

    let decoder = snakeCaseDecoder()

    // 新增成员变量，用于在多个流程中传递
    var nxapiZncaApiAccessToken: String = ""
    var nsoVersion: String = AppUserDefaults.shared.NSOVersion
    var coralUserId: String = ""

    static private func snakeCaseDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: - 重构后的登录流程
    
    /// 完整的登录流程，参考api.ts的getWebServiceToken实现
    func loginFlow() async throws -> LoginFlowResult {
        // 1. 获取sessionToken
        let sessionToken = try await login()
        
        // 2. 获取登录token
        let loginToken = try await requestLoginToken(sessionToken: sessionToken)
        
        // 3. 获取用户信息
        let naUser = try await requestUserInfo(accessToken: loginToken.accessToken)
        
        // 4. 获取nxapi-znca认证token
        nxapiZncaApiAccessToken = try await nxapiZncaAuthToken()
        
        // 5. 获取NSO版本（如果还没有的话）
        if nsoVersion.isEmpty {
            let config = try await nxapiZncaConfig()
            if let version = config["nso_version"] as? String {
                nsoVersion = version
                updateNSOVersion(version)
            }
        }
        
        // 6. 生成登录f值
        let (_, encryptedTokenRequest) = try await nxapiZncaFAdvanced(
            accessToken: nxapiZncaApiAccessToken,
            step: 1,
            idToken: loginToken.idToken,
            encryptTokenRequest: EncryptTokenRequest(url: "https://api-lp1.znc.srv.nintendo.net/v3/Account/Login", parameter: [
                "f":"",
                "language": naUser.language,
                "naBirthday": naUser.birthday,
                "naCountry": naUser.country,
                "naIdToken": loginToken.idToken,
                "requestId": "",
                "timestamp": 0,
            ]),
            naId: naUser.id,
            coralUserId: nil
        )
        
        // 7. 获取登录结果
        let loginResult = try await requestLogin(encryptedTokenRequest: encryptedTokenRequest)
        
        // 8. 生成web service f值
        let (_, encryptedTokenRequest2) = try await nxapiZncaFAdvanced(
            accessToken: nxapiZncaApiAccessToken,
            step: 2,
            idToken: loginResult.result.webApiServerCredential.accessToken,
            encryptTokenRequest: EncryptTokenRequest(url: "https://api-lp1.znc.srv.nintendo.net/v4/Game/GetWebServiceToken", parameter: [
                "f":"",
                "registrationToken": "",
                "id": 4834290508791808,
                "requestId": "",
                "timestamp": 0,
            ]),
            naId: naUser.id,
            coralUserId: coralUserId
        )
        
        // 9. 获取web service token
        let webServiceToken = try await requestWebServiceToken(encryptedTokenRequest: encryptedTokenRequest2, accessToken: loginResult.result.webApiServerCredential.accessToken)
        
        return LoginFlowResult(
            sessionToken: sessionToken,
            loginToken: loginToken,
            naUser: naUser,
            loginResult: loginResult,
            webServiceToken: webServiceToken
        )
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
    
    // MARK: - 重构后的方法
    
    /// 请求登录（使用加密的token request）
    func requestLogin(encryptedTokenRequest: Data) async throws -> LoginResult {
        let loginAPI = NSOAPI.login(encryptedTokenRequest: encryptedTokenRequest)
        let (data, response) = try await URLSession.shared.data(for: loginAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }
        
        // 解密响应
        let decryptedData = try await nxapiZncaDecrypt(accessToken: nxapiZncaApiAccessToken, data: data)
        let json = JSON(decryptedData)
        
        // 提取coralUserId
        if let userId = json["result"]["user"]["id"].int64 {
            coralUserId = String(userId)
        }
        
        return LoginResult(json: json)
    }
    
    /// 请求web service token（使用加密的token request）
    func requestWebServiceToken(encryptedTokenRequest: Data, accessToken: String) async throws -> WebServiceToken {
        let webServiceTokenAPI = NSOAPI.getWebServiceTokenEncrypted(encryptedTokenRequest: encryptedTokenRequest, accessToken: accessToken)
        let (data, response) = try await URLSession.shared.data(for: webServiceTokenAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }
        
        // 解密响应
        let decryptedData = try await nxapiZncaDecrypt(accessToken: nxapiZncaApiAccessToken, data: data)
        let json = JSON(decryptedData)
        
        return WebServiceToken(json: json)
    }


    // 保留原有方法以兼容性
    func requestLogin(accessToken:String, naUser:NAUser, idToken: String) async throws -> LoginResult {
        self.nxapiZncaApiAccessToken = try await nxapiZncaAuthToken()
        let (_, encryptedTokenRequest) = try await nxapiZncaFAdvanced(
            accessToken: nxapiZncaApiAccessToken,
            step: 1,
            idToken: idToken,
            encryptTokenRequest: EncryptTokenRequest(url: "https://api-lp1.znc.srv.nintendo.net/v3/Account/Login", parameter: [
                "f":"",
                "language": naUser.language,
                "naBirthday": naUser.birthday,
                "naCountry": naUser.country,
                "naIdToken": idToken,
                "requestId": "",
                "timestamp": 0,
            ]),
            naId: naUser.id,
            coralUserId: nil
        )
        let loginAPI = NSOAPI.login(encryptedTokenRequest: encryptedTokenRequest)
        let (data, response) = try await URLSession.shared.data(for: loginAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }
        return LoginResult(json: try JSON(data: data))
    }

    // 保留原有方法以兼容性
    func requestWebServiceToken(sessionToken:String, indicatorID: String? = nil) async throws -> WebServiceToken {
        // 1. 获取登录token
        Indicators.shared.updateProgress(for: indicatorID, progress: 0.166)
        let loginToken = try await requestLoginToken(sessionToken: sessionToken)
        
        // 2. 获取用户信息（从存储中获取或重新请求）
        let naUser: NAUser
        Indicators.shared.updateProgress(for: indicatorID, progress: 0.332)
        naUser = try await requestUserInfo(accessToken: loginToken.accessToken)

        // 3. 获取nxapi-znca认证token（从存储中获取或重新请求）
        nxapiZncaApiAccessToken = try await nxapiZncaAuthToken()

        // 4. 获取NSO版本（如果还没有的话）
        if nsoVersion.isEmpty {
            Indicators.shared.updateProgress(for: indicatorID, progress: 0.4)
            let config = try await nxapiZncaConfig()
            if let version = config["nso_version"] as? String {
                nsoVersion = version
                updateNSOVersion(version)
            }
        }
        
        // 5. 生成登录f值
        Indicators.shared.updateProgress(for: indicatorID, progress: 0.5)
        let (version, encryptedTokenRequest) = try await nxapiZncaFAdvanced(
            accessToken: nxapiZncaApiAccessToken,
            step: 1,
            idToken: loginToken.idToken,
            encryptTokenRequest: EncryptTokenRequest(url: "https://api-lp1.znc.srv.nintendo.net/v3/Account/Login", parameter: [
                "f":"",
                "language": naUser.language,
                "naBirthday": naUser.birthday,
                "naCountry": naUser.country,
                "naIdToken": loginToken.idToken,
                "requestId": "",
                "timestamp": 0,
            ]),
            naId: naUser.id,
            coralUserId: nil
        )

        AppUserDefaults.shared.NSOVersion = version

        // 6. 获取登录结果
        Indicators.shared.updateProgress(for: indicatorID, progress: 0.666)
        let loginResult = try await requestLogin(encryptedTokenRequest: encryptedTokenRequest)



        // 7. 生成web service f值
        Indicators.shared.updateProgress(for: indicatorID, progress: 0.833)
        let (_, encryptedTokenRequest2) = try await nxapiZncaFAdvanced(
            accessToken: nxapiZncaApiAccessToken,
            step: 2,
            idToken: loginResult.result.webApiServerCredential.accessToken,
            encryptTokenRequest: EncryptTokenRequest(url: "https://api-lp1.znc.srv.nintendo.net/v4/Game/GetWebServiceToken", parameter: [
                "f":"",
                "registrationToken": "",
                "id": 4834290508791808,
                "requestId": "",
                "timestamp": 0,
            ]),
            naId: naUser.id,
            coralUserId: String(loginResult.result.user.id)
        )
        
        // 8. 获取web service token
        Indicators.shared.updateProgress(for: indicatorID, progress: 1.0)
        let webServiceToken = try await requestWebServiceToken(encryptedTokenRequest: encryptedTokenRequest2, accessToken: loginResult.result.webApiServerCredential.accessToken)

        
        return webServiceToken
    }

    // 新增 nxapi-znca 相关方法
    func nxapiZncaAuthToken() async throws -> String {
        let maxRetries = 1
        var retryCount = 0
        
        while retryCount < maxRetries {
            do {
                let authAPI = AppAPI.nxapiZnca_auth_token
                let (data, response) = try await URLSession.shared.data(for: authAPI.request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NSOAuthError.invalidSessionToken
                }
                
                let json = JSON(data)
                
                // 检查API警告信息
                if let warnings = json["warnings"].array {
                    for warning in warnings {
                        if let warningString = warning.string {
                            print("API Warning: \(warningString)")
                        }
                    }
                }
                
                let accessToken = json["access_token"].stringValue
                guard !accessToken.isEmpty else {
                    throw NSOAuthError.invalidSessionToken
                }
                return accessToken
            } catch {
                retryCount += 1
                if retryCount >= maxRetries {
                    throw NSOAuthError.nxapiError(message: "Failed to get auth token after \(maxRetries) attempts: \(error.localizedDescription)")
                }
                try? await Task.sleep(nanoseconds: UInt64(1 * Double(NSEC_PER_SEC)))
            }
        }
        throw NSOAuthError.nxapiError(message: "Unexpected error in auth token request")
    }
    
    func nxapiZncaDecrypt(accessToken: String, data: Data) async throws -> Data {
        let maxRetries = 1
        var retryCount = 0
        
        while retryCount < maxRetries {
            do {
                let decryptAPI = AppAPI.nxapiZnca_decrypt(accessToken: accessToken, data: data)
                let (responseData, response) = try await URLSession.shared.data(for: decryptAPI.request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NSOAuthError.invalidSessionToken
                }
                return responseData
            } catch {
                retryCount += 1
                if retryCount >= maxRetries {
                    throw NSOAuthError.nxapiError(message: "Failed to decrypt response after \(maxRetries) attempts: \(error.localizedDescription)")
                }
                try? await Task.sleep(nanoseconds: UInt64(1 * Double(NSEC_PER_SEC)))
            }
        }
        throw NSOAuthError.nxapiError(message: "Unexpected error in decrypt request")
    }
    
    func nxapiZncaConfig() async throws -> [String: Any] {
        let configAPI = AppAPI.nxapiZnca_config
        let (data, response) = try await URLSession.shared.data(for: configAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }
        
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        
        // 检查API警告信息
        if let jsonDict = json, let warnings = jsonDict["warnings"] as? [String] {
            for warning in warnings {
                print("API Warning: \(warning)")
            }
        }
        
        return json ?? [:]
    }
    
    func nxapiZncaFAdvanced(accessToken: String, step: Int, idToken: String, encryptTokenRequest: EncryptTokenRequest, naId: String, coralUserId: String?) async throws -> (version: String, encryptedTokenRequest: Data) {
        let maxRetries = 1
        var retryCount = 0
        
        while retryCount < maxRetries {
            do {
                // 首先获取NSO版本（如果还没有的话）
                if nsoVersion.isEmpty {
                    let config = try await nxapiZncaConfig()
                    if let version = config["nso_version"] as? String {
                        nsoVersion = version
                        updateNSOVersion(version)
                    }
                }
                
                let fAPI = AppAPI.nxapiZnca_f_advanced(
                    accessToken: accessToken,
                    step: step == 1 ? .hash1 : .hash2,
                    idToken: idToken,
                    encryptTokenRequest: encryptTokenRequest,
                    naId: naId,
                    coralUserId: coralUserId
                )
                let (data, response) = try await URLSession.shared.data(for: fAPI.request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NSOAuthError.invalidSessionToken
                }
                
                let json = JSON(data)
                
                // 检查API警告信息
                if let warnings = json["warnings"].array {
                    for warning in warnings {
                        if let warningString = warning.string {
                            print("API Warning: \(warningString)")
                        }
                    }
                }
                
                let encryptedTokenRequestString = json["encrypted_token_request"].stringValue
                guard !encryptedTokenRequestString.isEmpty,
                      let encryptedTokenRequestData = Data(base64Encoded: encryptedTokenRequestString) else {
                    throw NSOAuthError.nxapiError(message: "Failed to get encrypted_token_request from response")
                }
                
                return (version: nsoVersion, encryptedTokenRequest: encryptedTokenRequestData)
            } catch {
                retryCount += 1
                if retryCount >= maxRetries {
                    throw NSOAuthError.nxapiError(message: "Failed to get f value after \(maxRetries) attempts: \(error.localizedDescription)")
                }
                try? await Task.sleep(nanoseconds: UInt64(1 * Double(NSEC_PER_SEC)))
            }
        }
        throw NSOAuthError.nxapiError(message: "Unexpected error in f request")
    }
    
    private func updateNSOVersion(_ version: String) {
        // 更新AppUserDefaults中的NSO版本
        AppUserDefaults.shared.NSOVersion = version
        print("NSO Version updated to: \(version)")
    }

}

// MARK: - 新增数据结构

extension NSOAuthorization {
    struct LoginFlowResult {
        let sessionToken: String
        let loginToken: LoginToken
        let naUser: NAUser
        let loginResult: LoginResult
        let webServiceToken: WebServiceToken
    }
}

extension NSOAuthorization {
    enum NSOAuthError:Error{
        case invalidCallbackURL
        case invalidSessionToken
        case invalidLoginToken
        case responseError(code: Int, url: URL? = nil, body: String? = nil)
        case nxapiError(message: String)
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
    struct NAUser:Codable {
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

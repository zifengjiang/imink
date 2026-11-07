import Foundation
import SwiftyJSON
import SplatDatabase

extension NSOAuthorization {
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


    func requestLogin(accessToken:String, naUser:NAUser, idToken: String) async throws -> LoginResult {
        self.nxapiZncaApiAccessToken = try await nxapiZncaAuthToken()
        let (_, encryptedTokenRequest) = try await nxapiZncaFAdvanced(
            accessToken: nxapiZncaApiAccessToken,
            step: 1,
            idToken: idToken,
            encryptTokenRequest: EncryptTokenRequest(url: "https://api-lp1.znc.srv.nintendo.net/v4/Account/Login", parameter: [
                "f":"",
                "language": naUser.language,
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

    func requestWebServiceToken(sessionToken:String, indicatorID: String? = nil) async throws -> WebServiceToken {
        try checkFAPIRequestInterval()
            // 1. 获取登录token
        Indicators.shared.updateTitle(for: indicatorID, title: "获取登录token")
        let loginToken = try await requestLoginToken(sessionToken: sessionToken)

            // 2. 获取用户信息（从存储中获取或重新请求）
        let naUser: NAUser
        Indicators.shared.updateTitle(for: indicatorID, title: "获取用户信息")
        naUser = try await requestUserInfo(accessToken: loginToken.accessToken)

            // 3. 获取nxapi-znca认证token（从存储中获取或重新请求）
        nxapiZncaApiAccessToken = try await nxapiZncaAuthToken()

            // 4. 获取NSO版本（如果还没有的话）
        if nsoVersion.isEmpty {
            Indicators.shared.updateTitle(for: indicatorID, title: "获取NSO版本")
            let config = try await nxapiZncaConfig()
            if let version = config["nso_version"] as? String {
                nsoVersion = version
                updateNSOVersion(version)
            }
        }

            // 5. 生成登录f值
        Indicators.shared.updateTitle(for: indicatorID, title: "生成登录f值")
        let (version, encryptedTokenRequest) = try await nxapiZncaFAdvanced(
            accessToken: nxapiZncaApiAccessToken,
            step: 1,
            idToken: loginToken.idToken,
            encryptTokenRequest: EncryptTokenRequest(url: "https://api-lp1.znc.srv.nintendo.net/v4/Account/Login", parameter: [
                "f":"",
                "language": naUser.language,
                "naIdToken": loginToken.idToken,
                "requestId": "",
                "timestamp": 0,
            ]),
            naId: naUser.id,
            coralUserId: nil
        )

        AppUserDefaults.shared.NSOVersion = version

            // 6. 获取登录结果
        Indicators.shared.updateTitle(for: indicatorID, title: "获取登录结果")
        let loginResult = try await requestLogin(encryptedTokenRequest: encryptedTokenRequest)



            // 7. 生成web service f值
        Indicators.shared.updateTitle(for: indicatorID, title: "生成web service f值")
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
        Indicators.shared.updateTitle(for: indicatorID, title: "获取WebServiceToken")
        let webServiceToken = try await requestWebServiceToken(encryptedTokenRequest: encryptedTokenRequest2, accessToken: loginResult.result.webApiServerCredential.accessToken)


        return webServiceToken
    }
}

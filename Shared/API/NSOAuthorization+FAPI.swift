import Foundation
import SwiftyJSON
import SplatDatabase

extension NSOAuthorization {
    func checkFAPIRequestInterval() throws {
        let currentTime = Int(Date().timeIntervalSince1970 * 1000) // 转换为毫秒
        let lastRequestTime = AppUserDefaults.shared.fapiLastRequestTime
        let requestInterval = AppUserDefaults.shared.fapiRequestInterval
        
        // 如果间隔设置为0或负数，则禁用间隔限制
        if requestInterval <= 0 {
            return
        }
        
        if currentTime - lastRequestTime < requestInterval {
            throw NSOAuthError.tooManyRequests
        }
    }

        /// 更新FAPI最后请求时间
    func updateFAPILastRequestTime() {
        AppUserDefaults.shared.fapiLastRequestTime = Int(Date().timeIntervalSince1970 * 1000)
    }

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
            // 检查请求间隔
        try checkFAPIRequestInterval()

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
        guard let httpResponse = response as? HTTPURLResponse else{
            throw NSOAuthError.invalidSessionToken
        }

        switch httpResponse.statusCode {
        case 200, 201:
            updateFAPILastRequestTime()
            break // OK
        case 401:
            throw SN3Client.Error.invalidGameServiceToken
        case 429:
            updateFAPILastRequestTime()
            throw SN3Client.Error.tooManyRequests
        case let code:
            throw SN3Client.Error.responseError(code: code, url: httpResponse.url, body: String(data: data, encoding: .utf8))
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

            // 请求成功，更新最后请求时间
        updateFAPILastRequestTime()

        return (version: nsoVersion, encryptedTokenRequest: encryptedTokenRequestData)

    }

    func updateNSOVersion(_ version: String) {
            // 更新AppUserDefaults中的NSO版本
        AppUserDefaults.shared.NSOVersion = version
        print("NSO Version updated to: \(version)")
    }
}

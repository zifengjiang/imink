import Foundation
import SwiftyJSON
import SplatDatabase

extension NSOAuthorization {
    func checkFAPIRequestInterval() throws {
        // 服务端限流窗口（429 时按 Retry-After 写入）优先于本地间隔：
        // 冷却期间不再发起 f 请求，避免用户连点把账号越锁越死。
        if FAPICooldown.isActive {
            throw NSOAuthError.rateLimited(
                until: FAPICooldown.untilMs,
                provider: FAPICooldown.provider.isEmpty ? "f" : FAPICooldown.provider,
                detail: "本地冷却中（原因：\(AppUserDefaults.shared.fapiCooldownReason)）"
            )
        }

        let currentTime = Int(Date().timeIntervalSince1970 * 1000) // 转换为毫秒
        let lastRequestTime = AppUserDefaults.shared.fapiLastRequestTime
        let requestInterval = AppUserDefaults.shared.fapiRequestInterval
        
        // 如果间隔设置为0或负数，则禁用间隔限制
        if requestInterval <= 0 {
            return
        }
        
        if currentTime - lastRequestTime < requestInterval {
            let remaining = Int((Double(requestInterval - (currentTime - lastRequestTime)) / 1000).rounded(.up))
            throw NSOAuthError.rateLimited(
                until: lastRequestTime + requestInterval,
                provider: "local",
                detail: "本地请求间隔 \(requestInterval / 60000) 分钟，还剩 \(FAPICooldown.durationText(remaining))"
            )
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
                    // 以前这里不管 429/500 都抛 invalidSessionToken，把「nxapi 限流」误报成「会话失效」，
                    // 用户于是去重登 —— 结果是继续打 Nintendo，越锁越死。
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let body = String(data: data, encoding: .utf8)
                    SyncDiagnostics.noteFailure(
                        api: "nxapi-auth",
                        query: nil,
                        webVersion: "-",
                        webVersionSource: "nxapi",
                        status: status,
                        responseBody: body,
                        error: "nxapi 鉴权失败",
                        note: "Grant=client_credentials"
                    )
                    if status == 429 || status == 503 {
                        let until = FAPICooldown.record(
                            from: response as? HTTPURLResponse,
                            status: status,
                            provider: "nxapi-auth"
                        )
                        throw NSOAuthError.rateLimited(until: until, provider: "nxapi-auth", detail: "客户端凭据被限流")
                    }
                    throw NSOAuthError.nxapiError(message: "nxapi 鉴权 HTTP \(status)：\(body?.prefix(160) ?? "")")
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
                    // 冷却/限流是「等一等」，不是「重试一次」：直接上抛，别被 here 的包装吃掉。
                if let authError = error as? NSOAuthError, case .rateLimited = authError { throw authError }
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

    func nxapiZncaFAdvanced(accessToken: String, step: Int, idToken: String, encryptTokenRequest: EncryptTokenRequest, naId: String, coralUserId: String?, naUser: NAUser? = nil) async throws -> (version: String, encryptedTokenRequest: Data) {
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
            AppUserDefaults.shared.fapiLastProvider = "nxapi"
            FAPICooldown.clear()
            break // OK
        case 401:
            SyncDiagnostics.noteFailure(
                api: "nxapi-f",
                query: nil,
                webVersion: "-",
                webVersionSource: "nxapi",
                status: 401,
                responseBody: String(data: data, encoding: .utf8),
                error: "nxapi f step\(step) 返回 401"
            )
            throw SN3Client.Error.invalidGameServiceToken
        case 429, 500, 502, 503, 504:
            let body = String(data: data, encoding: .utf8)
            // 429（以及 503）带上限流窗口：解析 Retry-After / X-RateLimit-Reset，
            // 没带就保守地等 10 分钟。窗口写进 prefs，UI 和本地守卫都按它来。
            let cooldownMs = (httpResponse.statusCode == 429 || httpResponse.statusCode == 503)
                ? FAPICooldown.record(from: httpResponse, status: httpResponse.statusCode, provider: "nxapi")
                : nil
            updateFAPILastRequestTime()

            // 备用提供方：nxapi 不行就试 imink 官方 f API，并把两边结果都记下来
            let chain = await fapiFallbackChainNote(
                idToken: idToken,
                naId: naId,
                coralUserId: coralUserId,
                naUser: naUser,
                nxapiStatus: httpResponse.statusCode,
                nxapiBody: body
            )
            SyncDiagnostics.noteFailure(
                api: "nxapi-f",
                query: nil,
                webVersion: "-",
                webVersionSource: "nxapi",
                status: httpResponse.statusCode,
                responseBody: body,
                error: "nxapi f step\(step) 被限流或服务异常",
                note: chain
            )
            if let cooldownMs {
                throw NSOAuthError.rateLimited(until: cooldownMs, provider: "nxapi", detail: chain)
            }
            throw SN3Client.Error.responseError(code: httpResponse.statusCode, url: httpResponse.url, body: body)
        case let code:
            SyncDiagnostics.noteFailure(
                api: "nxapi-f",
                query: nil,
                webVersion: "-",
                webVersionSource: "nxapi",
                status: code,
                responseBody: String(data: data, encoding: .utf8),
                error: "nxapi f step\(step) 返回 \(code)"
            )
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

    // MARK: - 备用 f 提供方（imink 官方 f API）

    /// nxapi 返回 429/5xx 后的备用链：先用 imink 官方 f API（`https://api.imink.app/f`）拿 f 值，
    /// 再用这个 f 值探一次「明文 znc 请求」是否还被接受。
    ///
    /// 为什么要探：实测 Nintendo 现在只接受加密请求体，明文 `/v4/Account/Login`
    /// 无论 f 值真假都回 `status 9427 Upgrade required`，所以「f 值」本身已经不足以替代
    /// nxapi 的 `encrypted_token_request`。把真实结果写进 `lastSyncDebug.note`，
    /// 以后就不用再靠猜「imink 能不能当兵」。
    ///
    /// - Returns: 供诊断用的链式摘要，例如
    ///   `provider=nxapi(status=429); cooldown=10 分钟(→14:52:00); imink=失败(HTTP 500); …`
    func fapiFallbackChainNote(
        idToken: String,
        naId: String,
        coralUserId: String?,
        naUser: NAUser?,
        nxapiStatus: Int,
        nxapiBody: String?
    ) async -> String {
        var parts: [String] = ["provider=nxapi(status=\(nxapiStatus))"]
        if FAPICooldown.isActive {
            parts.append("cooldown=\(FAPICooldown.durationText(FAPICooldown.remainingSeconds()))→\(FAPICooldown.clockText(FAPICooldown.untilMs))")
        }
        if let nxapiBody, !nxapiBody.isEmpty {
            parts.append("nxapiBody=\(nxapiBody.prefix(120))")
        }
        guard AppUserDefaults.shared.fapiTryIminkFallback else {
            parts.append("imink=已禁用")
            return parts.joined(separator: "; ")
        }

        do {
            let f = try await iminkF(
                idToken: idToken,
                naId: naId,
                hashMethod: .hash1,
                coralUserId: coralUserId,
                naUser: naUser
            )
            AppUserDefaults.shared.fapiLastProvider = "imink"
            parts.append("imink=成功(f=\(f.f.prefix(8))…, requestId=\(f.requestId.prefix(8))…)")
            let probe = await probePlainAccountLogin(idToken: idToken, f: f, naUser: naUser)
            parts.append("明文请求=HTTP \(probe.status) \(probe.body.prefix(160))")
            if probe.status == 200 && probe.body.contains("\"result\"") {
                parts.append("结论=明文通道居然可用（需要实现明文 GetWebServiceToken 才能完整回退）")
            } else {
                parts.append("结论=imink 的 f 值无法替代 nxapi 的加密请求体，只能等冷却")
            }
            return parts.joined(separator: "; ")
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            parts.append("imink=失败(\(reason))")
            parts.append("结论=两个 f 提供方都不可用，只能等冷却")
            return parts.joined(separator: "; ")
        }
    }

    /// 从 imink 官方 f API 拿 f 值。
    /// 文档：https://github.com/imink-app/f-API
    func iminkF(
        idToken: String,
        naId: String,
        hashMethod: AppAPI.HashMethod,
        coralUserId: String?,
        naUser: NAUser?
    ) async throws -> NSOAuthorization.F {
        let api = AppAPI.imink_f_v2(
            token: idToken,
            naId: naId,
            hashMethod: hashMethod,
            coralUserId: coralUserId,
            country: naUser?.country,
            language: naUser?.language,
            naBirthday: naUser?.birthday
        )
        let (data, response) = try await URLSession.shared.data(for: api.request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSOAuthError.nxapiError(message: "imink f API 没有返回 HTTP 响应")
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 || httpResponse.statusCode == 503 {
                FAPICooldown.record(from: httpResponse, status: httpResponse.statusCode, provider: "imink")
            }
            throw NSOAuthError.nxapiError(message: "imink f API HTTP \(httpResponse.statusCode)：\(body.prefix(160))")
        }

        let f = NSOAuthorization.F(json: JSON(data))
        guard !f.f.isEmpty else {
            throw NSOAuthError.nxapiError(message: "imink f API 返回里没有 f：\(body.prefix(160))")
        }
        return f
    }

    struct PlainLoginProbe {
        let status: Int
        let body: String
    }

    /// 只取证用：把 imink 给的 f 值填进**明文** `/v4/Account/Login` 试一次。
    /// 不进入任何后续流程（Nintendo 已要求加密请求体）。
    func probePlainAccountLogin(idToken: String, f: NSOAuthorization.F, naUser: NAUser?) async -> PlainLoginProbe {
        var parameter: [String: Any] = [
            "f": f.f,
            "naIdToken": idToken,
            "requestId": f.requestId,
            "timestamp": f.timestamp
        ]
        if let country = naUser?.country, !country.isEmpty { parameter["naCountry"] = country }
        if let language = naUser?.language, !language.isEmpty { parameter["language"] = language }
        if let birthday = naUser?.birthday, !birthday.isEmpty { parameter["naBirthday"] = birthday }

        let version = AppUserDefaults.shared.NSOVersion
        var request = URLRequest(url: URL(string: "https://api-lp1.znc.srv.nintendo.net/v4/Account/Login")!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("com.nintendo.znca/\(version)(Android/11)", forHTTPHeaderField: "User-Agent")
        request.setValue("Android", forHTTPHeaderField: "X-Platform")
        request.setValue(version, forHTTPHeaderField: "X-ProductVersion")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["parameter": parameter])
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            return PlainLoginProbe(status: status, body: String(data: data, encoding: .utf8) ?? "")
        } catch {
            return PlainLoginProbe(status: -1, body: error.localizedDescription)
        }
    }
}

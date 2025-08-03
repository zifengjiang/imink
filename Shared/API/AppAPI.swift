import Foundation

enum AppAPI {
    case config

    case imink_f(naId:String, naIdToken: String, hashMethod: HashMethod)

    case nxapiZnca_f(naId:String, naIdToken: String, hashMethod: HashMethod)
    
    // 新增 nxapi-znca 相关 API
    case nxapiZnca_auth_token
    case nxapiZnca_decrypt(accessToken: String, data: Data)
    case nxapiZnca_config
    case nxapiZnca_f_advanced(accessToken: String, step: Int, idToken: String, encryptTokenRequest: EncryptTokenRequest, naId: String, coralUserId: String?)
    
    internal enum HashMethod: String {
        case hash1 = "1", hash2 = "2"
    }
}

    // If you want to use this api, please check the documentation
    // Docs: https://github.com/JoneWang/imink/wiki/imink-API-Documentation
extension AppAPI: TargetType {
    var baseURL: URL { 
        switch self{
        case .config,.imink_f:
            return URL(string: "https://api.imink.jone.wang")!
        case .nxapiZnca_f:
            return URL(string:"https://nxapi-znca-api.fancy.org.uk/api/znca")!
        case .nxapiZnca_auth_token:
            return URL(string: "https://nxapi-auth.fancy.org.uk/api/oauth")!
        case .nxapiZnca_decrypt, .nxapiZnca_config:
            return URL(string: "https://nxapi-znca-api.fancy.org.uk/api/znca")!
        case .nxapiZnca_f_advanced:
            return URL(string: "https://nxapi-znca-api.fancy.org.uk/api/znca")!
        }
    }

    var path: String {
        switch self {
        case .config:
            return "/config"
        case .imink_f,.nxapiZnca_f:
            return "/f"
        case .nxapiZnca_auth_token:
            return "/token"
        case .nxapiZnca_decrypt:
            return "/decrypt-response"
        case .nxapiZnca_config:
            return "/config"
        case .nxapiZnca_f_advanced:
            return "/f"
        }
    }

    var method: RequestMethod {
        switch self {
        case .config:
            return .get
        case .imink_f,.nxapiZnca_f:
            return .post
        case .nxapiZnca_auth_token, .nxapiZnca_decrypt:
            return .post
        case .nxapiZnca_config:
            return .get
        case .nxapiZnca_f_advanced:
            return .post
        }
    }

    var headers: [String : String]? {
        switch self{
        case .nxapiZnca_f:
            return [
                "User-Agent": "Imink/1.0.0 (iOS)",
                "x-znca-client-version": AppUserDefaults.shared.NSOVersion,
                "X-znca-platform": "Android",
                "x-znca-version": AppUserDefaults.shared.NSOVersion,
            ]
        case .nxapiZnca_auth_token:
            return [
                "User-Agent": "Imink/1.0.0 (iOS)",
                "Content-Type": "application/x-www-form-urlencoded"
            ]
        case .nxapiZnca_decrypt(let accessToken, _):
            return [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json; charset=utf-8",
                "User-Agent": "Imink/1.0.0 (iOS)",
                "X-znca-Client-Version": AppUserDefaults.shared.NSOVersion,
                "X-znca-Platform": "Android",
                "X-znca-Version": AppUserDefaults.shared.NSOVersion,
            ]
        case .nxapiZnca_config:
            return [
                "User-Agent": "Imink/1.0.0 (iOS)"
            ]
        case .nxapiZnca_f_advanced(let accessToken, _, _, _, _, _):
            return [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json; charset=utf-8",
                "User-Agent": "Imink/1.0.0 (iOS)",
                "X-znca-Client-Version": AppUserDefaults.shared.NSOVersion,
                "X-znca-Platform": "Android",
                "X-znca-Version": AppUserDefaults.shared.NSOVersion,
            ]
        default:
            return nil
        }
    }

    var querys: [(String, String?)]? {
        switch self {
        default:
            return nil
        }
    }

    var data: MediaType? {
        switch self {
        case .imink_f(let naId, let naIdToken, let hashMethod),
                .nxapiZnca_f(let naId, let naIdToken, let hashMethod):
            return .jsonData([
                "hash_method": hashMethod.rawValue,
                "token": naIdToken,
                "na_id": naId
            ])
        case .nxapiZnca_auth_token:
            let params = [
                ("client_id", "dzZNtWfQxWR_xNFcVijXPQ"),
                ("grant_type", "client_credentials"),
                ("scope", "ca:gf ca:er ca:dr")
            ]
            return .form(params)
        case .nxapiZnca_decrypt(_, let data):
            let decryptBody = NxapiZncaDecryptBody(data: data.base64EncodedString())
            return .jsonData(decryptBody)
        case .nxapiZnca_f_advanced(_, let step, let idToken, let encryptTokenRequest, let naId, let coralUserId):
            let body = NxapiZncaFAdvancedBody(
                hashMethod: step,
                token: idToken,
                encryptTokenRequest: encryptTokenRequest,
                naId: naId,
                coralUserId: coralUserId
            )
            return .jsonData(body)
        default:
            return nil
        }
    }

    var sampleData: Data {
        Data()
    }
}


func getNsoVersion(completion: @escaping (String?) -> Void) {
    let urlString = "https://raw.githubusercontent.com/nintendoapis/nintendo-app-versions/main/data/coral-google-play.json".trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: urlString) else {
        completion(nil)
        return
    }

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
            completion(nil)
            return
        }

        guard let data = data else {
            completion(nil)
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let version = json["version"] as? String {
                completion(version)
            } else {
                completion(nil)
            }
        } catch {
            print("JSON parsing error: \(error.localizedDescription)")
            completion(nil)
        }
    }

    task.resume()
}

// MARK: - Nxapi Znca Data Structures

struct NxapiZncaDecryptBody: Codable {
    let data: String
}


struct NxapiZncaFAdvancedBody: Codable {
    let hashMethod: Int
    let token: String
    let encryptTokenRequest: EncryptTokenRequest
    let naId: String
    let coralUserId: String?
    
    enum CodingKeys: String, CodingKey {
        case hashMethod = "hash_method"
        case token
        case encryptTokenRequest = "encrypt_token_request"
        case naId = "na_id"
        case coralUserId = "coral_user_id"
    }
}

import InkMoya
import Foundation

enum AppAPI {
    case config

    case imink_f(naId:String, naIdToken: String, hashMethod: HashMethod)

    case nxapiZnca_f(naId:String, naIdToken: String, hashMethod: HashMethod)
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
        }
    }

    var path: String {
        switch self {
        case .config:
            return "/config"
        case .imink_f,.nxapiZnca_f:
            return "/f"
        }
    }

    var method: RequestMethod {
        switch self {
        case .config:
            return .get
        case .imink_f,.nxapiZnca_f:
            return .post
        }
    }

    var headers: [String : String]? {
        return nil
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
        default:
            return nil
        }
    }

    var sampleData: Data {
        Data()
    }
}

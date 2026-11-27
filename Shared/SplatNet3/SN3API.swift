import Foundation

public enum SN3API {
    case web(path: String = "/")
    case bulletTokens(
        gameServiceToken: String,
        country: String,
        accountLanguage: String,
        interfaceLanguage: String
    )
}

extension SN3API: TargetType {
    
    public var baseURL: URL { URL(string: "https://api.lp1.av5ja.srv.nintendo.net")! }
    
    public var path: String {
        switch self {
        case .web(let path):
            return path
        case .bulletTokens:
            return "/api/bullet_tokens"
        }
    }
    
    public var method: RequestMethod {
        switch self {
        case .web:
            return .get
        default:
            return .post
        }
    }
    
    public var headers: [String : String]? {
        switch self {
        case .web:
            return nil
        case .bulletTokens(
            let gameServiceToken,
            let country,
            let accountLanguage,
            let interfaceLanguage
        ):
            return [
                "Accept": "*/*",
                "Accept-Language": interfaceLanguage,
                "Content-Type": "application/json",
                "Cookie": "_gtoken=\(gameServiceToken); _dnt=1",
                "Origin": "https://api.lp1.av5ja.srv.nintendo.net",
                "Referer": "https://api.lp1.av5ja.srv.nintendo.net/?lang=\(interfaceLanguage)&na_country=\(country)&na_lang=\(accountLanguage)",
                "Sec-Fetch-Dest": "empty",
                "Sec-Fetch-Mode": "cors",
                "Sec-Fetch-Site": "same-origin",
                "User-Agent": "Mozilla/5.0 (Linux; Android 11; sdk_gphone_arm64 Build/RSR1.210722.013.A6; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/91.0.4472.114 Mobile Safari/537.36",
                "X-NACOUNTRY": country,
                "X-Requested-With": "com.nintendo.znca",
            ]
        }
    }
    
    public var querys: [(String, String?)]? { nil }
    
    public var data: MediaType? { nil }
    
    public var sampleData: Data {
//        let path = "/SampleData/\(sampleDataFileName)"
//        let url = Bundle.module.url(forResource: path, withExtension: nil)!
        return Data()
    }
}

extension SN3API {
    var sampleDataFileName: String {
        switch self {
        case .web(let path):
            if path.hasPrefix("/static/js/main.") {
                return "main.js"
            } else {
                return "api.lp1.av5ja.srv.nintendo.net.html"
            }
        case .bulletTokens:
            return "bulletTokens.json"
        }
    }
}

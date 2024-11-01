import Foundation

public enum Splatoon3InkAPI {
    case historySchedule(Date)
    case schedule
    case gear
    case coop
    case festivals
}

extension Splatoon3InkAPI: TargetType {
    public var baseURL: URL {
        switch self {
        case .historySchedule:
            URL(string:"https://splatoon3ink-archive.nyc3.digitaloceanspaces.com")!
        default:
            URL(string:"https://splatoon3.ink/data")!
        }

    }
    
    public var path: String {
        switch self {
        case .historySchedule(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd/yyyy-MM-dd.HH"
            let dateString = formatter.string(from: date)
            return "/\(dateString)-00-00.schedules.json"
        case .schedule:
            return "/schedules.json"
        case .gear:
            return "/gear.json"
        case .coop:
            return "/coop.json"
        case .festivals:
            return "/festivals.json"
        }
    }
    
    public var method: RequestMethod {
        .get
    }
    
    public var headers: [String : String]? {
        return ["User-Agent" : "imink3"]
    }
    
    public var querys: [(String, String?)]? {
        nil
    }
    
    public var data: MediaType? {
        nil
    }
    
    public var sampleData: Data {
        Data()
    }
    

}


//public func fetchJSON(from target: TargetType) async throws -> Data {
//    let request = target.request
//    print(target.path)
//    let (data, response) = try await URLSession.shared.data(for: request)
//
//    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
//        throw NetworkError.requestFailed
//    }
//    
//    return data
//}

public enum NetworkError: Error {
    case invalidURL
    case requestFailed
    case decodingFailed
}

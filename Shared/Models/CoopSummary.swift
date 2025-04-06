import Foundation
import SwiftyJSON

struct CoopSummary:Codable, SwiftyJSONDecodable{
    init(json: SwiftyJSON.JSON) {
        self.pointCard = PointCard(goldenDeliverCount: json["pointCard"]["goldenDeliverCount"].intValue, limitedPoint: json["pointCard"]["limitedPoint"].int, deliverCount: json["pointCard"]["deliverCount"].intValue, playCount: json["pointCard"]["playCount"].intValue, rescueCount: json["pointCard"]["rescueCount"].intValue, regularPoint: json["pointCard"]["regularPoint"].intValue, totalPoint: json["pointCard"]["totalPoint"].intValue, defeatBossCount: json["pointCard"]["defeatBossCount"].intValue)
        self.scale = Scale(gold: json["scale"]["gold"].intValue, bronze: json["scale"]["bronze"].intValue, silver: json["scale"]["silver"].intValue)
        self.monthlyGear = json["monthlyGear"]["image"]["url"].stringValue.imageHash
        self.regularAverageClearWave = json["regularAverageClearWave"].doubleValue
        self.regularGradePoint = json["regularGradePoint"].intValue
        self.regularGrade = json["regularGrade"]["id"].stringValue
        self.updateTime = Date()
    }
    

    let pointCard: PointCard
    let scale: Scale
    let monthlyGear: String?
    let regularAverageClearWave: Double
    let regularGradePoint: Int
    let regularGrade: String
    let updateTime:Date



    struct PointCard:Codable{
        let goldenDeliverCount:Int
        let limitedPoint:Int?
        let deliverCount:Int
        let playCount:Int
        let rescueCount:Int
        let regularPoint:Int
        let totalPoint:Int
        let defeatBossCount:Int
    }

    struct Scale:Codable{
        let gold: Int
        let bronze: Int
        let silver: Int
    }

    static var value:CoopSummary?{
        if let data = AppUserDefaults.shared.coopSummary?.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(CoopSummary.self, from: data){
            return decoded
        }
        return nil
    }

    static func save(_ summary:CoopSummary){
        if let data = try? JSONEncoder().encode(summary),
           let jsonString = String(data: data, encoding: .utf8) {
            AppUserDefaults.shared.coopSummary = jsonString
        }
    }
}

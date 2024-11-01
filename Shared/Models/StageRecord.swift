import Foundation
import SwiftyJSON
import SplatDatabase

struct StageRecord:Codable{
    let name:String
    let nameId:String
    let stats:Stats?

    init(json:JSON){
        self.name = {
            (try? SplatDatabase.shared.dbQueue.read{ db in
                try ImageMap.fetchOne(db, sql: "SELECT * FROM imageMap WHERE nameId = '\(json["id"].stringValue)'")
            })?.name ?? ""
        }()
        self.nameId = json["id"].stringValue
        self.stats = Stats(json: json["stats"])
    }

    init(name:String, nameId:String, stats:Stats?){
        self.name = name
        self.nameId = nameId
        self.stats = stats
    }

    struct Stats:Codable{
        let winRateCl:Double?
        let winRateLf:Double?
        let winRateTw:Double?
        let winRateGl:Double?
        let winRateAr:Double?
        let lastPlayedTime:Date

        init?(json:JSON?){
            if let json = json{
                self.winRateCl = json["winRateCl"].double
                self.winRateLf = json["winRateLf"].double
                self.winRateTw = json["winRateTw"].double
                self.winRateGl = json["winRateGl"].double
                self.winRateAr = json["winRateAr"].double
                self.lastPlayedTime = utcToDate(date: json["lastPlayedTime"].stringValue) ?? Date()
            }else{
                return nil
            }
        }

        init(winRateCl:Double?,winRateLf:Double?,winRateTw:Double?,winRateGl:Double?,winRateAr:Double?){
            self.winRateAr = winRateAr
            self.winRateTw = winRateTw
            self.winRateGl = winRateGl
            self.winRateLf = winRateGl
            self.winRateCl = winRateCl
            self.lastPlayedTime = Date()
        }
    }
}

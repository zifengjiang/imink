import Foundation
import SwiftyJSON
import SplatDatabase

struct CoopRecord:Codable,SwiftyJSONDecodable{
    let teamContestRecord:TeamContestRecord
    let defeatBossRecords:[DefeatEnemyRecord]
    let defeatEnemyRecords:[DefeatEnemyRecord]
    let stageHighestRecords:[StageHighestRecord]

    init(json:JSON){
        self.teamContestRecord = TeamContestRecord(json: json["data"]["coopRecord"]["teamContestRecord"])
        self.defeatBossRecords = json["data"]["coopRecord"]["defeatBossRecords"].arrayValue.map{
            DefeatEnemyRecord(json: $0)
        }
        self.defeatEnemyRecords = json["data"]["coopRecord"]["defeatEnemyRecords"].arrayValue.map{
            DefeatEnemyRecord(json: $0)
        }
        self.stageHighestRecords = json["data"]["coopRecord"]["stageHighestRecords"].arrayValue.map{
            StageHighestRecord(json: $0)
        }
    }
}


struct DefeatEnemyRecord:Codable{
    let enemy:String
    let defeatCount:Int

    let enemyImage:String?

    init(json:JSON){
        self.enemy = json["enemy"]["id"].stringValue
        self.defeatCount = json["defeatCount"].intValue

        let image = try? SplatDatabase.shared.dbQueue.read { db in
            try? ImageMap.fetchOne(db, sql: "SELECT * FROM imageMap WHERE nameId = '\(json["enemy"]["id"].stringValue)'")
        }?.name

        self.enemyImage = image
    }


}

struct StageHighestRecord:Codable{
    let coopStage:String
    let grade:String
    let gradePoint:Int
    let coopStageImage:String?

    init(json:JSON){
        self.coopStage = json["coopStage"]["id"].stringValue
        self.grade = json["grade"]["id"].stringValue
        self.gradePoint = json["gradePoint"].intValue

        let image = try? SplatDatabase.shared.dbQueue.read { db in
            try? ImageMap.fetchOne(db, sql: "SELECT * FROM imageMap WHERE nameId = '\(json["coopStage"]["id"].stringValue)'")
        }?.name
        
        self.coopStageImage = image
    }
}

struct TeamContestRecord:Codable{
    let gold : Int
    let bronze : Int
    let silver : Int
    let attend : Int

    init(json:JSON){
        self.gold = json["gold"].intValue
        self.bronze = json["bronze"].intValue
        self.silver = json["silver"].intValue
        self.attend = json["attend"].intValue
    }
}

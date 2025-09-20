import Foundation
import SwiftUI
import SplatDatabase
import SwiftyJSON

struct HistoryRecord:Codable, SwiftyJSONDecodable{

    let account: Account
    let nameplate:Nameplate
    let leagueMatchPlayHistory:PlayHistoryTrophyRecord
    let bankaraMatchOpenPlayHistory:PlayHistoryTrophyRecord
    let teamContestPlayHistory:PlayHistoryTrophyRecord
    let udemae:String?
    let udemaeMax:String?
    let rank:Int

    enum CodingKeys:String,CodingKey{
        case account,nameplate, leagueMatchPlayHistory, bankaraMatchOpenPlayHistory, teamContestPlayHistory, udemae, udemaeMax, rank
    }

    private var storedRawValue:String?
    init(json:JSON){
        self.account = AppUserDefaults.shared.sessionToken == nil ? Account() : {
            (try? SplatDatabase.shared.dbQueue.read{ db in
                try Account.fetchOne(db, sql: "SELECT * FROM account WHERE id = \(AppUserDefaults.shared.accountId)")
            }) ?? Account()
        }()
        self.nameplate = Nameplate(json: json["data"]["currentPlayer"])
        self.leagueMatchPlayHistory = PlayHistoryTrophyRecord(json: json["data"]["playHistory"]["leagueMatchPlayHistory"])
        self.bankaraMatchOpenPlayHistory = PlayHistoryTrophyRecord(json: json["data"]["playHistory"]["bankaraMatchOpenPlayHistory"])
        self.teamContestPlayHistory = PlayHistoryTrophyRecord(json: json["data"]["playHistory"]["teamContestPlayHistory"])
        self.udemae = json["data"]["playHistory"]["udemae"].string
        self.udemaeMax = json["data"]["playHistory"]["udemaeMax"].string
        self.rank = json["data"]["playHistory"]["rank"].intValue
    }


    struct Nameplate:Codable{
        let name: String
        let byname: String
        let nameId: String
        let background: String
        let badges: [String]
        let textColor:PackableNumbers

        init(json:JSON){
            self.name = json["name"].stringValue
            self.byname = json["byname"].stringValue
            self.nameId = json["nameId"].stringValue
            self.background = {
                (try? SplatDatabase.shared.dbQueue.read{ db in
                    try ImageMap.fetchOne(db, sql: "SELECT * FROM imageMap WHERE nameId = '\(json["nameplate"]["background"]["id"].stringValue)'")
                }?.name) ?? "default"
            }()
            self.badges = json["nameplate"]["badges"].arrayValue.map{badgeJSON in
                (try? SplatDatabase.shared.dbQueue.read{ db in
                    try ImageMap.fetchOne(db, sql: "SELECT * FROM imageMap WHERE nameId = '\(badgeJSON["id"].stringValue)'")
                }?.name) ?? ""
            }
            self.textColor = json["nameplate"]["background"]["textColor"].dictionaryValue.toRGBPackableNumbers()
        }
    }
}

extension NameplateView {
    init(nameplate: HistoryRecord.Nameplate) {
        name = nameplate.name
        background = nameplate.background
        byname = nameplate.byname
        textColor = nameplate.textColor.toColor()
        badges = nameplate.badges
        nameId = nameplate.nameId
    }
}

struct PlayHistoryTrophyRecord:Codable {
    var attend: Int = 0
    var bronze: Int = 0
    var gold: Int = 0
    var silver: Int = 0

    init(json:JSON){
        self.attend = json["attend"].intValue
        self.bronze = json["bronze"].intValue
        self.gold = json["gold"].intValue
        self.silver = json["silver"].intValue
    }

    static let defaultRecord = PlayHistoryTrophyRecord(json: JSON())

}

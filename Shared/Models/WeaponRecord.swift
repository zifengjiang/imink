import Foundation
import SwiftyJSON
import SplatDatabase

struct WeaponRecords: Codable,SwiftyJSONDecodable {
    init(json: JSON) {
        self.records = json["data"]["weaponRecords"]["nodes"].arrayValue.map { WeaponRecord(json: $0) }
    }

    let records: [WeaponRecord]
}

struct WeaponRecord: Codable,SwiftyJSONDecodable {
    init(json: JSON) {
        self.category = json["weaponCategory"]["weaponCategoryId"].intValue
        self.stats = Stats(json: json["stats"])
        let subWeaponId = json["subWeapon"]["id"].stringValue
        let specialWeaponId = json["specialWeapon"]["id"].stringValue
        let nameId = json["id"].stringValue
        self.subWeapon = ImageMap(nameId: subWeaponId)
        self.specialWeapon = ImageMap(nameId: specialWeaponId)
        self.name = ImageMap(nameId: nameId)
    }
    
    let category: Int
    let subWeapon: ImageMap
    let specialWeapon:ImageMap
    let name:ImageMap
    let stats:Stats

    struct Stats:Codable,SwiftyJSONDecodable{
        let expToLevelUp:Int
        let vibes:Int
        let level:Int
        let win:Int
        let paint:Int
        let lastUsedTime:Date?

        init(json: JSON) {
            self.expToLevelUp = json["expToLevelUp"].intValue
            self.vibes = json["vibes"].intValue
            self.level = json["level"].intValue
            self.win = json["win"].intValue
            self.paint = json["paint"].intValue
            self.lastUsedTime = utcToDate(date: json["lastUsedTime"].stringValue)
        }
    }
}

extension ImageMap {
    public init(nameId: String) {

        if let imageMap = try? SplatDatabase.shared.dbQueue.read({ db in
            try ImageMap.fetchOne(db, sql: "SELECT * FROM imageMap WHERE nameId = '\(nameId)'")
        }) {
            self = imageMap
        } else {
           self = ImageMap(id: nil, nameId: nameId, name: "", hash: "")
        }
    }
}

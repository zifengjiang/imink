import Foundation
import SwiftyJSON

extension TargetType{
    func GetJSON() async throws -> JSON {
        let (data, _) = try await URLSession.shared.data(for: self.request)
        return try JSON(data:data)
    }
}



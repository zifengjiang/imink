import Foundation
public enum MediaType {
    case jsonData(_ data: Encodable)
    case form(_ form: [(String, String)])
    case data(_ data: Data)
}

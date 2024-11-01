public enum MediaType {
    case jsonData(_ data: Encodable)
    case form(_ form: [(String, String)])
}

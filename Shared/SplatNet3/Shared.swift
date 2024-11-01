import Foundation

// MARK: - Container

public struct SN3DataItem<Content: Decodable>: Decodable {
    public let data: Content
}

public struct SN3NodesList<Node: Decodable>: Decodable {
    public let nodes: [Node]
}

extension SN3NodesList: RandomAccessCollection {
    public var startIndex: Int { nodes.startIndex }
    public var endIndex: Int { nodes.endIndex }
    public subscript(position: Int) -> Node { nodes[position] }
}

// MARK: - Basic

public struct SN3ID: RawRepresentable, Codable {
    
    public let rawValue: String
    public let id: String
    
    public init?(rawValue: String) {
        self.rawValue = rawValue
        guard let data = Data(base64Encoded: rawValue),
                let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        self.id = decoded
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        guard let v = SN3ID(rawValue: str) else {
            throw DecodingError
                .dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "invalid SN3ID"))
        }
        self = v
    }
}

public struct SN3Date: RawRepresentable, Codable {

    public let rawValue: String
    public let date: Date

    public init?(rawValue: String) {
        self.rawValue = rawValue
        guard let date = ISO8601DateFormatter().date(from: rawValue) else {
            return nil
        }
        self.date = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        guard let v = SN3Date(rawValue: str) else {
            throw DecodingError
                .dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "invalid SN3Date"))
        }
        self = v
    }
}

public struct SN3Image: Decodable {
    public let url: URL
}

public struct SN3JustID: Decodable {
    public let id: SN3ID
}

public struct SN3IDName: Decodable {
    public let id: SN3ID
    public let name: String
}

public struct SN3IDImage: Decodable {
    public let id: SN3ID
    public let image: SN3Image
}

public struct SN3NameImage: Decodable {
    public let name: String
    public let image: SN3Image
}

public struct SN3IDNameImage: Decodable {
    public let id: SN3ID
    public let name: String
    public let image: SN3Image
}

public struct SN3MaskingImage: Decodable {
    public let width: Int
    public let height: Int
    public let maskImageUrl: String
    public let overlayImageUrl: String
}

public struct SN3Color: Decodable {
    public let r: Double
    public let g: Double
    public let b: Double
    public let a: Double
    public init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}



public struct SquidSpecies: RawRepresentable, Decodable {
    
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static let inkling = Self(rawValue: "INKLING")
    public static let octoling = Self(rawValue: "OCTOLING")
}

public struct VSJudgement: RawRepresentable, Decodable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    
    public static let win = Self(rawValue: "WIN")
    public static let lose = Self(rawValue: "LOSE")
    public static let draw = Self(rawValue: "DRAW")
    public static let exemptedLose = Self(rawValue: "EXEMPTED_LOSE")
    public static let deemedLose = Self(rawValue: "DEEMED_LOSE")
}

public struct VSKnockout: RawRepresentable, Decodable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    
    public static let win = Self(rawValue: "WIN")
    public static let lose = Self(rawValue: "LOSE")
    public static let neither = Self(rawValue: "NEITHER")
}

public struct VSMode: Decodable {
    
    public let id: SN3ID
    public let mode: Mode
    
    public struct Mode: RawRepresentable, Decodable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        
        public static let bankara = Self(rawValue: "BANKARA")
        public static let fest = Self(rawValue: "FEST")
        public static let `private` = Self(rawValue: "PRIVATE")
    }
}

public struct VSRule: Decodable {
    public let id: SN3ID
    public let name: String
    public let rule: Rule
    
    public struct Rule: RawRepresentable, Decodable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        
        public static let turfWar = Self(rawValue: "TURF_WAR")
        public static let splatZones = Self(rawValue: "AREA")
        public static let towerControl = Self(rawValue: "LOFT")
        public static let rainMaker = Self(rawValue: "GOAL")
        public static let clamBlitz = Self(rawValue: "CLAM")
    }
}

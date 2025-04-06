//
//  NSOHash.swift
//  imink
//
//  Created by Jone Wang on 2021/3/12.
//

import Foundation

struct NSOHash {
    
    static func urandom(length: Int) -> [UInt8] {
        var randomUInts = [UInt8]()
        for _ in 0..<length {
            randomUInts.append(UInt8.random(in: 0..<UInt8.max))
        }
        return randomUInts
    }
}

extension Sequence where Iterator.Element == UInt8 {
    
    var base64EncodedString: String {
        Data(self)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }
}


extension String {
        // 返回 URL 的 imageHash 属性
    var imageHash: String? {
            // 去除 URL 中的查询参数部分
        guard let urlWithoutQuery = self.split(separator: "?").first else {
            return nil
        }
            // 将路径拆分为组件
        let pathComponents = urlWithoutQuery.split(separator: "/")
        guard let lastComponent = pathComponents.last else {
            return nil
        }
            // 提取最后一个部分并取下划线前的内容
        let hash = lastComponent.split(separator: "_").first
        return hash.map { String($0) }
    }
}

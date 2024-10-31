//
//  Dictionary+Ext.swift
//  imink
//
//  Created by 姜锋 on 10/28/24.
//

import Foundation
import SwiftyJSON
import SplatDatabase

extension Dictionary where Key == String, Value == JSON {


    func toRGBPackableNumbers() -> PackableNumbers{
        let r = self["r"]?.double ?? 0
        let g = self["g"]?.double ?? 0
        let b = self["b"]?.double ?? 0
        let a = self["a"]?.double ?? 0
        return PackableNumbers([0,UInt16(a*255),UInt16(b*255),UInt16(g*255),UInt16(r*255)])
    }
}

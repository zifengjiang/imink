    //
    //  Species.swift
    //  imink
    //
    //  Created by 姜锋 on 10/6/24.
    //

import Foundation
import SwiftUI

enum Species:String,Codable {
    case INKLING = "INKLING"
    case OCTOLING = "OCTOLING"

    var icon: iIcon {
        return iIcon(species: self)
    }

    struct iIcon {
        let species: Species

        var kill: Image {
            switch species {
            case .INKLING:
                return Image(.ikaK)
            case .OCTOLING:
                return Image(.takoK)
            }
        }

        var dead: Image {
            switch species {
            case .INKLING:
                return Image(.ikaD)
            case .OCTOLING:
                return Image(.takoD)
            }
        }

        var kd: Image {
            switch species {
            case .INKLING:
                return Image(.ikaKd)
            case .OCTOLING:
                return Image(.takoKd)
            }
        }
    }
}

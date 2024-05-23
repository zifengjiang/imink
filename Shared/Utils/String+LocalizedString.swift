import Foundation


extension String {

    func localized(bundle: Bundle = .main, tableName: String = "Localizable") -> String {
        return NSLocalizedString(self, tableName: tableName, bundle: bundle, value: "", comment: "")
    }

    var localized: String {
        return localized()
    }

    var localizedFromSplatNet: String {
        return localized(bundle: .main, tableName: "SplatNet")
    }
}

extension String {
    var base64EncodedString: String {
        return Data(self.utf8).base64EncodedString()
    }
}

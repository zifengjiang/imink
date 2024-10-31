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

extension Array where Element == String {
        /// 返回一个去除重复元素的新数组，保持原有顺序
    func removingDuplicates() -> [String] {
        var seen = Set<String>()
        return self.filter { element in
            guard !seen.contains(element) else { return false }
            seen.insert(element)
            return true
        }
    }
}

func utcToDate(date: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return formatter.date(from: date)
}

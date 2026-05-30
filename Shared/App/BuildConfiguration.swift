enum BuildConfiguration {
    static var showsDeveloperOptions: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

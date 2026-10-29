import Foundation

enum WMProtectedApplications {
    static var bundleIdentifiers: Set<String> {
        var identifiers: Set = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.systemuiserver",
            "com.apple.loginwindow",
            "com.apple.WindowManager",
        ]

        identifiers.formUnion([
            "app.opendawn.dawnApp",
            "app.opendawn.dawnAgent",
        ])

        if let own = Bundle.main.bundleIdentifier {
            identifiers.insert(own)
        }

        #if DEBUG
            identifiers.insert("com.apple.dt.Xcode")
        #endif

        return identifiers
    }
}

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

        if let own = Bundle.main.bundleIdentifier {
            identifiers.insert(own)
        }

        return identifiers
    }
}

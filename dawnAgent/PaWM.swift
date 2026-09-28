import AppKit

@main
enum dawnAgent {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = dawnAgentAppDelegate()
        app.delegate = delegate
        app.run()
    }
}

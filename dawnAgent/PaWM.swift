import AppKit

@main
enum PaWM {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = PaWMAppDelegate()
        app.delegate = delegate
        app.run()
    }
}

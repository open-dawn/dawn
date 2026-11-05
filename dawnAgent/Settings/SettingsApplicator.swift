import libdawn

@MainActor
protocol SettingsApplying: AnyObject {
    func applySettings(_ settings: Settings) async
}

@MainActor
final class SettingsApplicator: SettingsApplying {
    private let menuBarController: any MenuBarControlling

    init(menuBarController: any MenuBarControlling) {
        self.menuBarController = menuBarController
    }

    func applySettings(_ settings: Settings) async {
        menuBarController.setVisible(settings.showInMenuBar)
        await AppliedSettings.shared.update(settings)
    }
}

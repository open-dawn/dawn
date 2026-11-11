import Foundation
import Observation

@Observable
@MainActor
final class CommandLineToolInstallModel {
    private(set) var showsBanner = false
    private(set) var errorMessage: String?
    private(set) var isInstalling = false

    private let installer: any CommandLineToolInstalling
    private let bundleCommandURL: URL

    init(
        installer: any CommandLineToolInstalling = ShellCommandLineToolInstaller(),
        bundleCommandURL: URL = CommandLineToolPaths.bundleCommandURL()
    ) {
        self.installer = installer
        self.bundleCommandURL = bundleCommandURL
    }

    func refresh() async {
        guard !isInstalling else {
            return
        }

        await reload()
    }

    func install() async {
        guard showsBanner, !isInstalling else {
            return
        }

        isInstalling = true
        defer { isInstalling = false }
        errorMessage = nil

        do {
            try await installer.installLink(
                from: bundleCommandURL,
                to: CommandLineToolPaths.linkURL
            )
        } catch let error {
            if case .failed(let message) = error {
                errorMessage = message
            }
            return
        }

        await reload()
    }

    private func reload() async {
        do {
            let lookup = try await installer.lookup()
            errorMessage = nil
            showsBanner = lookup.needsInstall
        } catch {
            showsBanner = true
            errorMessage = "Could not check whether dawncli is available."
        }
    }
}

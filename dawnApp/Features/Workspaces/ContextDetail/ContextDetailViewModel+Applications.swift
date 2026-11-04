import Foundation
import libdawn

extension ContextDetailViewModel {
    func dismissApplicationImportError() {
        applicationImportError = nil
    }

    @discardableResult
    func addApplications(at urls: [URL]) -> Bool {
        applicationImportError = nil

        guard let current = draft else {
            return false
        }

        var imported: [WorkspaceApplication] = []
        var sawValidApplication = false
        var firstError: ApplicationSelectionError?

        for url in urls {
            do {
                let application = try WorkspaceApplication.imported(from: url)
                sawValidApplication = true
                let alreadyListed = current.applications.contains {
                    $0.bundleIdentifier == application.bundleIdentifier
                } || imported.contains {
                    $0.bundleIdentifier == application.bundleIdentifier
                }
                if !alreadyListed {
                    imported.append(application)
                }
            } catch let error as ApplicationSelectionError {
                if firstError == nil {
                    firstError = error
                }
            } catch {
                if firstError == nil {
                    firstError = .unknown
                }
            }
        }

        applicationImportError = firstError

        if !imported.isEmpty {
            setApplications(current.applications + imported)
        }

        return sawValidApplication
    }
}

//
//  ApplicationsDirectoryProvider.swift
//  dawn
//
//  Created by Rafael Venetikides on 28/10/26.
//

import Foundation

public struct ApplicationsDirectoryProvider: InstalledApplicationProviding, Sendable {
    public let directories: [URL]

    public init(directories: [URL]) {
        self.directories = directories.map {
            $0.standardizedFileURL
        }
    }

    public init() {
        self.init(
            directories: [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Applications", isDirectory: true),
            ]
        )
    }

    public func applications() async throws -> [WorkspaceApplication] {
        let directories = directories

        return await Task.detached(priority: .utility) {
            Self.scan(directories: directories)
        }.value
    }
}

extension ApplicationsDirectoryProvider {
    private static func scan(directories: [URL]) -> [WorkspaceApplication] {
        let fileManager = FileManager.default
        var applications: [WorkspaceApplication] = []
        var bundleIdentifiers = Set<String>()

        for directory in directories {
            guard
                let enumerator = fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [
                        .isDirectoryKey,
                        .isPackageKey,
                    ],
                    options: [
                        .skipsHiddenFiles,
                        .skipsPackageDescendants,
                    ]
                )
            else {
                continue
            }

            for case let applicationURL as URL in enumerator {
                guard let application = makeApplication(at: applicationURL) else {
                    continue
                }

                guard bundleIdentifiers.insert(application.bundleIdentifier).inserted else {
                    continue
                }

                applications.append(application)
            }
        }

        return applications.sorted {
            $0.displayName.localizedCaseInsensitiveCompare(
                $1.displayName
            ) == .orderedAscending
        }
    }

    private static func makeApplication(at applicationURL: URL) -> WorkspaceApplication? {
        guard applicationURL.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame,
            let bundle = Bundle(url: applicationURL),
            let bundleIdentifier = bundle.bundleIdentifier,
            isUserFacingApplication(bundle)
        else {
            return nil
        }

        let displayName =
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? applicationURL.deletingPathExtension().lastPathComponent

        return WorkspaceApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationURL: applicationURL
        )
    }

    private static func isUserFacingApplication(_ bundle: Bundle) -> Bool {
        let packageType = bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String

        let isAgent = bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true

        let isBackgroundOnly = bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool == true

        return packageType == "APPL" && !isAgent && !isBackgroundOnly
    }
}

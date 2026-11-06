//
//  SystemProfilerApplicationProvider.swift
//  dawn
//
//  Created by Rafael Venetikides on 28/10/26.
//

import Foundation
import dawnLogging

private struct SystemProfilerReport: Decodable {
    let applications: [SystemProfilerApplicationEntry]

    private enum CodingKeys: String, CodingKey {
        case applications = "SPApplicationsDataType"
    }
}

private struct SystemProfilerApplicationEntry: Decodable {
    let path: String
}

public struct SystemProfilerApplicationProvider: InstalledApplicationProviding, Sendable {

    private enum ProviderError: LocalizedError {
        case providerFailed(String)

        var errorDescription: String? {
            switch self {
            case .providerFailed(let string):
                "Unable to load installed applications: \(string)"
            }
        }
    }

    public init() {}

    public func applications() async throws -> [WorkspaceApplication] {
        try await Task.detached(priority: .utility) {
            try scanApplications()
        }.value
    }

    private func scanApplications() throws -> [WorkspaceApplication] {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = [
            "SPApplicationsDataType",
            "-json"
        ]

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()

        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorOutput, encoding: .utf8) ?? "Unkown system_profiler error"

            #log("Error runing system_profiler: \(message)", level: .error, category: .appLifecycle)

            throw ProviderError.providerFailed(message)
        }

        let report = try JSONDecoder().decode(
            SystemProfilerReport.self,
            from: output
        )

        return makeApplications(from: report.applications)
    }

    private func makeApplications(from entries: [SystemProfilerApplicationEntry]) -> [WorkspaceApplication] {
        var bundleIdentifiers = Set<String>()

        return entries.sorted {
            $0.path.count < $1.path.count
        } .compactMap { entry in
            makeApplication(at: entry.path)
        } .filter { application in
            bundleIdentifiers.insert(application.bundleIdentifier).inserted
        } .sorted {
            $0.displayName.localizedCaseInsensitiveCompare(
                $1.displayName
            ) == .orderedAscending
        }
    }

    private func makeApplication(at path: String) -> WorkspaceApplication? {
        let applicationURL = URL(fileURLWithPath: path)

        guard applicationURL.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame,
              !isNestedApplication(applicationURL),
              let bundle = Bundle(url: applicationURL),
              let bundleIdentifier = bundle.bundleIdentifier,
              !isBackgroundApplication(bundle)
        else {
            return nil
        }

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? applicationURL.deletingPathExtension().lastPathComponent

        return WorkspaceApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationURL: applicationURL
        )
    }

    private func isNestedApplication(_ url: URL) -> Bool {
        url.pathComponents.filter {
            $0.hasSuffix(".app")
        }.count > 1
    }

    private func isBackgroundApplication(_ bundle: Bundle) -> Bool {
        let isAgent = bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true

        let isBackgroundOnly = bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool == true

        return isAgent || isBackgroundOnly
    }
}

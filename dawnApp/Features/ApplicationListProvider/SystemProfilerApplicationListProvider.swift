//
//  SystemProfilerApplicationListProvider.swift
//  pineapplewm
//
//  Created by Longhi on 28/09/26.
//

import Foundation
import dawnLogging

final class SystemProfilerApplicationListProvider: ApplicationListProvider {
    func getList() async -> [ListedApp] {
        let data: Data
        do {
            data = try await Self.systemProfilerOutput()
        } catch {
            #log(
                "Failed to load applications: \(error.localizedDescription)",
                level: .error,
                category: .userInterface
            )
            return []
        }

        do {
            return try Self.decode(data)
        } catch {
            #log(
                "Failed to parse applications: \(error.localizedDescription)",
                level: .error,
                category: .userInterface
            )
            return []
        }
    }

    private static func systemProfilerOutput() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try Self.launchSystemProfiler())
                } catch let error as ProfilerFailure {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: ProfilerFailure.launchFailed(error.localizedDescription))
                }
            }
        }
    }

    /// Blocking. Stdout is drained while `system_profiler` runs so the pipe cannot fill and stall it.
    private static func launchSystemProfiler() throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPApplicationsDataType", "-json"]
        process.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ProfilerFailure.nonzeroExit(process.terminationStatus)
        }

        return data
    }

    private static func decode(_ data: Data) throws -> [ListedApp] {
        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        let response = try decoder.decode(SystemProfilerResponse.self, from: data)
        return response.SPApplicationsDataType
    }

    private struct SystemProfilerResponse: Decodable {
        let SPApplicationsDataType: [ListedApp]
    }

    private enum ProfilerFailure: LocalizedError {
        case launchFailed(String)
        case nonzeroExit(Int32)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let message):
                message
            case .nonzeroExit(let status):
                "system_profiler exited with status \(status)"
            }
        }
    }
}

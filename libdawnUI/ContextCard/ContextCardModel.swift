import Foundation
import AppKit

public struct ContextCardModel: Identifiable {
    public struct Application: Identifiable {
        public let id: UUID
        public let name: String
        public let icon: NSImage

        public init(id: UUID = UUID(), name: String, icon: NSImage) {
            self.id = id
            self.name = name
            self.icon = icon
        }
    }

    public enum Status: Equatable {
        case active(activityText: String)
        case inactive(lastUsedText: String?)
    }

    public let id: UUID
    public let name: String
    public let symbolName: String
    public let status: Status
    public let applications: [Application]

    public init(id: UUID = UUID(), name: String, symbolName: String, status: Status, applications: [Application] = []) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.status = status
        self.applications = applications
    }
}

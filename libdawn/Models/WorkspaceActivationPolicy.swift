//
//  WorkspaceActivationPolicy.swift
//  dawn
//
//  Created by Longhi on 06/11/26.
//

public enum WorkspaceActivationPolicy: String, Codable, Sendable, Equatable, CaseIterable {
    case hide
    case merge
    case close

    public var displaySymbol: String {
        switch self {
        case .hide: "eye.slash"
        case .merge: "interface.window.on.rectangle"
        case .close: "xmark.seal"
        }
    }

    public var displayName: String {
        switch self {
        case .hide: "Hide others"
        case .merge: "Merge with others"
        case .close: "Close others"
        }
    }

    public var displayDescription: String {
        switch self {
        case .hide: "hide other apps windows and remove them from the dock"
        case .merge: "open this workspaces apps while keeping the others open"
        case .close: "close all other apps open on your mac"
        }
    }
}

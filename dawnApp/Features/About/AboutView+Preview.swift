//
//  AboutView+Preview.swift
//  dawn
//
//  Created by Longhi on 21/10/26.
//

#if DEBUG

import Foundation
import Observation
import SwiftUI

@MainActor
private struct AboutPreview: View {
    @State private var updater: PreviewAppUpdater

    init(state: AppUpdateState) {
        _updater = State(
            initialValue: PreviewAppUpdater(state: state)
        )
    }

    var body: some View {
        AboutView(
            content: AboutContent.loadRequired(),
            updater: updater
        )
        .frame(width: 640, height: 520)
    }
}

@Observable
@MainActor
private final class PreviewAppUpdater: AppUpdating {
    var state: AppUpdateState

    var canCheckForUpdates: Bool {
        switch state {
        case .idle, .updateUnavailable, .failed:
            true

        case .checking,
             .updateAvailable,
             .downloading,
             .extracting,
             .readyToInstall,
             .installing:
            false
        }
    }

    init(state: AppUpdateState) {
        self.state = state
    }

    func checkForUpdates() {
        state = .checking
    }

    func installAvailableUpdate() {
        guard case let .updateAvailable(update) = state else {
            return
        }

        state = .downloading(
            update,
            progress: .indeterminate
        )
    }

    func installAndRelaunch() async {
        guard case let .readyToInstall(update) = state else {
            return
        }

        state = .installing(update)
    }

    func cancelUpdate() {
        state = .idle
    }
}

private let previewUpdate = AvailableAppUpdate(
    displayVersion: "1.1.0",
    buildVersion: "110",
    releaseNotesURL: URL(
        string: "https://update.opendawn.app"
    ),
    informationURL: nil
)

#Preview("About / Idle") {
    AboutPreview(state: .idle)
}

#Preview("About / Checking") {
    AboutPreview(state: .checking)
}

#Preview("About / Up to Date") {
    AboutPreview(
        state: .updateUnavailable(
            reason: .currentVersionIsLatest
        )
    )
}

#Preview("About / Update Available") {
    AboutPreview(
        state: .updateAvailable(previewUpdate)
    )
}

#Preview("About / Downloading") {
    AboutPreview(
        state: .downloading(
            previewUpdate,
            progress: .fraction(0.42)
        )
    )
}

#Preview("About / Preparing") {
    AboutPreview(
        state: .extracting(
            previewUpdate,
            progress: .indeterminate
        )
    )
}

#Preview("About / Ready to Install") {
    AboutPreview(
        state: .readyToInstall(previewUpdate)
    )
}

#Preview("About / Installing") {
    AboutPreview(
        state: .installing(previewUpdate)
    )
}

#Preview("About / Failure") {
    AboutPreview(
        state: .failed(reason: .networkUnavailable)
    )
}

#endif

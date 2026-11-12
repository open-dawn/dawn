# Managed updater components

DAWN uses Sparkle to replace the complete `DAWN.app` bundle. Files and executables contained inside the bundle are replaced automatically, but independently running services and externally installed artifacts may require additional lifecycle management.

The updater represents these dependencies as types conforming to `UpdateComponent`.

## When a component should be managed

Add a managed update component when a target requires work before or after Sparkle replaces the application bundle.

Examples include:

- Login items that may continue running after DAWN terminates.
- Launch agents, launch daemons, or helper applications.
- Command-line tools installed or linked outside `DAWN.app`.
- Components that must verify their running build after an update.
- Required components that must be registered when introduced by a new release.

A passive executable that only exists inside `DAWN.app` does not need additional update behavior. Sparkle replaces it with the rest of the bundle.

## Lifecycle contract

Managed components conform to:

```swift
@MainActor
protocol UpdateComponent {
    var identifier: String { get }

    func prepareForUpdate(
        targetBuild: String
    ) async throws

    func recoverAfterUpdateFailure() async throws

    func reconcileAfterUpdate(
        expectedBuild: String
    ) async throws
}
```

The methods have the following responsibilities:

| Method | When it runs | Responsibility |
| --- | --- | --- |
| `prepareForUpdate` | Before Sparkle installs an update | Flush state, stop work, terminate processes, and unregister services as needed |
| `recoverAfterUpdateFailure` | If preparation fails, or installation fails or is cancelled | Restore anything changed during preparation |
| `reconcileAfterUpdate` | When DAWN launches | Register required components, repair installations, and verify the installed or running build |

The component identifier must be stable and unique. Prefer the component's bundle identifier when one exists.

## Ordering and failure behavior

`UpdateComponentCoordinator` processes components in registration order.

Preparation:

1. The coordinator records the component as prepared.
2. It calls `prepareForUpdate`.
3. If the method throws, installation is cancelled.
4. Prepared components are recovered in reverse order.

Because a component is recorded before its preparation method is called, `recoverAfterUpdateFailure` may run after a partially completed preparation. Recovery must therefore be safe and idempotent.

Reconciliation runs in registration order. If a component throws, the coordinator stops and propagates the error.

## Implementing a component

Create the component under:

```text
dawnApp/Core/Updates/Components/
```

A basic component looks like:

```swift
@MainActor
final class ExampleUpdateComponent: UpdateComponent {
    let identifier = "app.opendawn.example"

    private let installer: any ExampleInstalling

    init(installer: any ExampleInstalling) {
        self.installer = installer
    }

    func prepareForUpdate(
        targetBuild: String
    ) async throws {
        try await installer.prepareForUpdate(
            targetBuild: targetBuild
        )
    }

    func recoverAfterUpdateFailure() async throws {
        try await installer.restoreAfterFailedUpdate()
    }

    func reconcileAfterUpdate(
        expectedBuild: String
    ) async throws {
        try await installer.reconcileInstallation(
            expectedBuild: expectedBuild
        )
    }
}
```

Keep platform or installation APIs behind a protocol so the component can be tested without changing real registrations or files.

## Running services

A running component should generally:

1. Receive a graceful preparation request.
2. Stop accepting mutations.
3. Flush required state.
4. Stop active operations.
5. Acknowledge that it is safe to terminate.
6. Be unregistered or terminated using its supported system API.
7. Be registered again if installation fails.
8. On relaunch, report its identifier and build.
9. Be restarted if it reports a stale build.
10. Be verified again after reconnection.

`DawnAgentUpdateComponent` is the reference implementation.

Do not use shell-based process killing or reset the Background Task Management database.

## Passive and command-line components

A component that does not run continuously may not need preparation or recovery behavior:

```swift
@MainActor
final class ExampleCLIUpdateComponent: UpdateComponent {
    let identifier = "example-cli"

    private let installer: any CLIInstalling

    init(installer: any CLIInstalling) {
        self.installer = installer
    }

    func prepareForUpdate(
        targetBuild _: String
    ) async throws {
        // The CLI has no running process to stop.
    }

    func recoverAfterUpdateFailure() async throws {
        // Preparation did not change external state.
    }

    func reconcileAfterUpdate(
        expectedBuild: String
    ) async throws {
        try installer.installOrRepair(
            expectedBuild: expectedBuild
        )
    }
}
```

For a bundled CLI, reconciliation can verify the executable inside the updated application and create or repair its external symlink.

## Registering the component

Components are assembled in `SettingsAppDelegate`.

Add the component to the Release registry:

```swift
#if DEBUG
updateComponents = []
#else
updateComponents = [
    DawnAgentUpdateComponent(
        eventRequester: eventBusService.bus,
        connectionWaiter: eventBusService,
        service: DawnAgentServiceController()
    ),
    ExampleUpdateComponent(
        installer: ExampleInstaller()
    ),
]
#endif
```

Debug builds currently use a manually launched `dawnAgent` and do not manage installed application components.

The same coordinator instance must be passed to `AppUpdaterService` and retained for startup reconciliation.

## Required tests

Each new component should test:

- Successful preparation.
- Preparation failure.
- Partial preparation followed by recovery.
- Recovery failure.
- Repeated recovery safety.
- Successful reconciliation.
- Missing or invalid installation.
- Stale build detection.
- Required registration or installation repair.
- Cancellation behavior where applicable.

Running services should additionally test:

- Graceful preparation acknowledgement.
- Preparation timeout or refusal.
- Deactivation after acknowledgement.
- Registration-state handling.
- Restart and reconnection.
- Identity and build validation.

After registering a component, run:

```bash
xcodebuild \
  -project dawn.xcodeproj \
  -scheme dawn \
  -destination "platform=macOS" \
  test
```

The registry is conditional on `DEBUG`, so also compile the Release path:

```bash
xcodebuild \
  -project dawn.xcodeproj \
  -scheme dawnApp \
  -configuration Release \
  -destination "platform=macOS" \
  build
```

A signed end-to-end Sparkle update should verify the component’s behavior across two application builds.

## Current limitations

The current coordinator tracks prepared components in memory.

PIN-199 still requires a persistent recovery journal containing the source build, target build, preparation phase, and previous component registration state.

Until that journal is implemented:

- Do not use this system for an optional component whose previous enabled state must be preserved.
- Do not clear or overwrite user-selected registration state.
- Required components may be registered during reconciliation.
- Components must recover failures occurring in the current application process.

Newly added, removed, and optional component descriptors will require additional reconciliation behavior as PIN-199 progresses.

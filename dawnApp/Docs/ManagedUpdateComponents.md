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
    var registrationState: UpdateComponentRegistrationState { get }
    var requirement: UpdateComponentRequirement { get }

    func prepareForUpdate(
        targetBuild: String
    ) async throws

    func recoverAfterUpdateFailure(
        previousRegistrationState:
            UpdateComponentRegistrationState
    ) async throws

    func reconcileAfterUpdate(
        expectedBuild: String
    ) async throws
}
```

The properties are as following:

- identifier: stable and unique, preferably a bundle identifier.
- registrationState: current installed or registered state.
- requirement: .required components are installed/reconciled after a successful update; .optional components preserve the user’s previous state.
- .unknown prevents update preparation because DAWN cannot safely restore it.

The methods have the following responsibilities:

| Method | When it runs | Responsibility |
| --- | --- | --- |
| `prepareForUpdate` | Before Sparkle installs an update | Flush state, stop work, terminate processes, and unregister services as needed |
| `recoverAfterUpdateFailure` | If preparation fails, or installation fails or is cancelled | Restore anything changed during preparation |
| `reconcileAfterUpdate` | When DAWN launches | Register required components, repair installations, and verify the installed or running build |

The component identifier must be stable and unique. Prefer the component's bundle identifier when one exists.

## Ordering, presistence and failure behavior

`UpdateComponentCoordinator` processes components in registration order.

Before changing a component, the coordinator creates an atomic recovery journal containing the source build, target build, and previous registration state of every component.

For each component:

1. Its phase is persisted as `preparing`.
2. `prepareForUpdate` is called.
3. Its phase is persisted as `prepared`.

If preparation or installation fails, affected components are restored in reverse order. Each successful restoration is persisted as `notStarted`, allowing recovery to resume safely after another interruption.

Recovery methods must be safe and idempotent because a process may terminate after changing a component but before persisting the completed phase.

On launch:

- If the running build matches the journal’s source build, DAWN restores the previous registration states and validates previously active components.
- If it matches the target build, DAWN reconciles required components and previously active optional components.
- If it matches neither build, reconciliation fails and the journal is retained.
- The journal is cleared only after restoration or reconciliation completes successfully.

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
    let requirement = UpdateComponentRequirement.required

    var registrationState: UpdateComponentRegistrationState {
        installer.registrationState
    }

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

    func recoverAfterUpdateFailure(
      previousRegistrationState: UpdateComponentRegistrationState
    ) async throws {
        try await installer.restoreAfterFailedUpdate(
            previousRegistrationState: previousRegistrationState
      )
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

## Passive bundled components

A target does not need an `UpdateComponent` merely because it is embedded in `DAWN.app`.

Passive components are updated automatically when Sparkle replaces the application bundle. They do not require lifecycle management when they:

- Do not continue running independently after DAWN terminates.
- Do not maintain external mutable state that must be restored.
- Are not copied to a separate installation location.
- Do not require registration with a system service.

`dawncli` is a passive bundled component. Its executable is installed at:

```text
DAWN.app/Contents/MacOS/dawncli
```

Sparkle replaces the bundled executable and the external symlink continues pointing into the updated bundle.

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

let componentCoordinator = UpdateComponentCoordinator(
    components: updateComponents,
    journalStore: FileUpdateRecoveryJournalStore(),
    sourceBuildProvider: {
        try ApplicationBuild.load()
    }
)
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

## Recovery journal

The recovery journal is stored atomically in the DAWN Application Support directory. It contains:

- The source application build.
- The target application build.
- Each component’s previous registration state.
- Each component’s preparation phase.

The journal survives application termination, crashes, and interrupted Sparkle installation. It must not be manually cleared while recovery or reconciliation is pending.

Required, optional, newly introduced, and removed components are handled through the component registry and their stable identifiers.

A signed end-to-end Sparkle update remains necessary to verify process termination, relaunch, PID replacement, and build identity across real application builds.

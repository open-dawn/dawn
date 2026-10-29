# Actions

Workspace actions in dawnAgent. They perform concrete side effects (open, hide, close apps; reset windows; run a shell command; enter a workspace) for workspace switching and related flows.

Shared models such as `WorkspaceApplication`, `WorkspaceContext`, `WorkspaceTransition`, and `WorkspaceActivationPolicy` live in **libdawn**. Actions themselves live only in dawnAgent under `Workspaces/Actions/`.

Import `@testable import dawnAgent` in tests; production code uses the action types through `WMActionIdentifier`.

## Core Protocols

```swift
protocol WMAction {
    func execute() async throws(WMActionError)
}

protocol WMAppAction: WMAction {
    var app: WorkspaceApplication { get }
    func execute() async throws(WMActionError)
}
```

- `WMAction` — any workspace side effect.
- `WMAppAction` — action scoped to one `WorkspaceApplication`

`execute` may be sync or async in practice; the protocol is `async throws(WMActionError)`. Failures are typed as `WMActionError`.

## Identifier

Closed enum used as the public catalog and factory. Callers pick a case; `.action` builds the concrete type.

```swift
public enum WMActionIdentifier {
    case hideApp(WorkspaceApplication)
    case openApp(WorkspaceApplication)
    case closeApp(WorkspaceApplication)
    case resetWindows(WorkspaceActivationPolicy, keep: [WorkspaceApplication])
    case terminalCommand(String)
    case workspaceTransition(WorkspaceContext)

    var action: WMAction { get }
}
```

| Case | Concrete type | Notes |
|------|---------------|--------|
| `hideApp(app)` | `WMHideAppAction` | Hide all windows of the target app |
| `openApp(app)` | `WMOpenAppAction` | Open or show the target app |
| `closeApp(app)` | `WMCloseAppAction` | Close the target app |
| `resetWindows(policy, keep:)` | `WMResetWindowsAction` | Apply `WorkspaceActivationPolicy` to non-member apps (`hide` / `merge` / `close`) |
| `terminalCommand(command)` | `WMTerminalCommandAction` | Start a shell command in the background |
| `workspaceTransition(context)` | `WMWorkspaceTransitionAction` | Full enter-workspace flow from `WorkspaceContext.transition` |

```swift
let id = WMActionIdentifier.openApp(safari)
try await id.action.execute()
```

Do not construct action structs from feature code unless you need custom dependency injection (tests). Prefer `WMActionIdentifier`.

## App Actions

Under `Workspaces/Actions/App/`. All conform to `WMAppAction`.

| Type | Behavior | Typical errors |
|------|----------|----------------|
| `WMOpenAppAction` | Opens the app via `NSWorkspace` (`activates`, respects `createNewInstance`) | `invalidURL`, `notFound`, `permissionDenied`, `corruptedFile`, `unknown` |
| `WMHideAppAction` | Finds a running instance by bundle id, activates, then hides | `notRunning`, `noGUItoShow` |
| `WMCloseAppAction` | Finds a running instance, activates, then terminates | `notRunning`, `permissionDenied` |

## Window Actions

Under `Workspaces/Actions/Window/`.

| Type | Behavior | Typical errors |
|------|----------|----------------|
| `WMResetWindowsAction` | `hide`: hide regular non-members; `close`: terminate them; `merge`: no-op. Accessory and prohibited processes, and apps with no bundle id, are skipped. Protected apps are always spared | `noGUItoShow` when any hide returns false; `permissionDenied` when any terminate returns false |
| `WMTerminalCommandAction` | Starts `/bin/zsh -lc` in the background through `TerminalCommandRunning` and returns after launch. Stdin, stdout, and stderr are `/dev/null`. Exit status is not waited on | `unknown` (launch failure) |

## Workspace Transition

`WorkspaceTransition` (libdawn) on each `WorkspaceContext` drives enter-workspace side effects. Missing `transition` values decode as `.default`.

```swift
public struct WorkspaceTransition: Codable, Sendable, Equatable {
    public var activationPolicy: WorkspaceActivationPolicy
    public var terminalCommand: String?

    public static let `default` = WorkspaceTransition()
}
```

| Field | Behavior |
|-------|----------|
| `activationPolicy` | `hide` (default): hide non-members, then open every member; `merge`: leave others alone and only open members that are not already running; `close`: terminate non-members, then open every member |
| `terminalCommand` | Optional shell command after opens. Empty or `nil` is skipped. The command is started in the background; a launch failure is logged and the transition continues |

`WMWorkspaceTransitionAction` (under `Workspaces/Actions/Transition/`) takes a `WorkspaceContext` and runs reset → open → terminal. Members are opened one at a time. Each step is best-effort: errors are logged and later steps still run.

Reset only considers apps with the regular activation policy. It never hides or closes Finder, Dock, SystemUIServer, loginwindow, WindowManager, `app.opendawn.dawnApp` (DAWN), `app.opendawn.dawnAgent`, or the agent's own bundle id. Debug builds also spare Xcode (`com.apple.dt.Xcode`). Merge uses `ApplicationProvider` to skip apps that already have a running instance.

`DefaultContextSwitching` runs this action for a context switch and waits for any in-flight switch to finish before starting the next one.

To add a case and map it in `.action` see [How to Add an Action](#how-to-add-an-action).

## Errors

```swift
enum WMActionError: LocalizedError, Equatable {
    case notFound(filePath: String)
    case permissionDenied
    case corruptedFile
    case invalidURL
    case notRunning
    case noGUItoShow
    case unknown(reason: String?)
}
```

| Case | Meaning |
|------|---------|
| `notFound` | App path missing on disk |
| `permissionDenied` | Cannot read/open/terminate |
| `corruptedFile` | Bundle unreadable or unsigned |
| `invalidURL` | `WorkspaceApplication.applicationURL` is `nil` |
| `notRunning` | No process for that bundle id |
| `noGUItoShow` | Hide attempted on a non-GUI app |
| `unknown` | Unmapped underlying error |

## How to Add an Action

Mirror the libdawn event workflow: one concrete type, register it in the catalog, keep payloads/models in the right module.

1. **Pick a folder** under `dawnAgent/Workspaces/Actions/`:
   - App-scoped → `App/` and conform to `WMAppAction`
   - Window or terminal → `Window/` and conform to `WMAction`
   - Enter-workspace orchestration → `Transition/` and conform to `WMAction`
   - Anything else → a new domain folder and conform to `WMAction`
2. **Implement** `execute() async throws(WMActionError)`. Inject protocols (`ApplicationProvider`, `WorkspaceOpener`, `TerminalCommandRunning`, `WorkspaceTransitionPerforming`, or a new seam) instead of calling AppKit globals when the action needs to be unit-tested.
3. **Add a case** to `WMActionIdentifier` and map it in `var action`.
4. **Reuse** `WorkspaceApplication`, `WorkspaceContext`, and `WorkspaceTransition` from libdawn. Do not redefine shared workspace models in dawnAgent.
5. **Add tests** under `dawnAgentTests/Workspaces/Actions/<Domain>/` (see below).

Example skeleton:

```swift
struct WMMyAppAction: WMAppAction {
    private(set) var app: WorkspaceApplication
    private let provider: ApplicationProvider

    func execute() async throws(WMActionError) {
        // ...
    }

    init(app: WorkspaceApplication, provider: ApplicationProvider = SystemApplicationProvider()) {
        self.app = app
        self.provider = provider
    }
}
```

Then in `WMActionIdentifier`:

```swift
case myApp(WorkspaceApplication)

var action: WMAction {
    switch self {
    case let .myApp(app): WMMyAppAction(app: app)
    // ...
    }
}
```

## Testing Actions

Tests live in `dawnAgentTests/Workspaces/Actions/`. Use Swift Testing (`@Suite`, `@Test`, `#expect`). Import `@testable import dawnAgent` and `libdawn` for `WorkspaceApplication`.

### Principles

- **Do not** launch real apps or rely on the live desktop in unit tests.
- Inject fakes at the seam (`WorkspaceOpener`, `ApplicationProvider`, `TerminalCommandRunning`, `WorkspaceTransitionPerforming`).
- Assert **typed** `WMActionError` cases with `#expect(throws:)`.
- Cover both failure paths and at least one success path per action.

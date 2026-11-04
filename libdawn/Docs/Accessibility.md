# Accessibility (AX) helpers

Window helpers in `libdawn/Features/Accessibility/` wrap macOS Accessibility (`AXUIElement`) behind protocols so dawnAgent actions can list, raise, and minimize windows without calling ApplicationServices directly.

Import `libdawn`. Call sites must run as a **trusted Accessibility client** (`AXIsProcessTrusted()`). In Dawn that is **dawnAgent**, not dawnApp.

## Surface

| Type | Role |
|------|------|
| `AccessibilityElementServing` | Low-level get/set/perform on one element |
| `AccessibilityRuntimeServing` | Creates application elements for a PID; wraps raw window elements |
| `AccessibilityWindowServing` | List / raise / minimize / fullscreen for a process |
| `SystemAccessibilityElement` | `AXUIElement` backend |
| `SystemAccessibilityRuntime` | Default runtime |
| `SystemAccessibilityWindowService` | Default window service |
| `AccessibilityError` | Typed failures (`notTrusted`, unsupported attribute, …) |

Attribute/action names live in `AccessibilityAttribute` / `AccessibilityAction` (`String` raw-value enums; Swift 6–safe vs `kAX*` globals). Low-level element APIs take those enums and pass `.rawValue` into AX.

## Usage

```swift
let service: any AccessibilityWindowServing = SystemAccessibilityWindowService()
let windows = try service.windows(forProcessID: pid)

for window in windows {
    try service.raise(window)
    try service.setMinimized(window, minimized: false)
}
```

Inject fakes conforming to `AccessibilityWindowServing` or `AccessibilityElementServing` in tests. Real TCC is not required for protocol-backed unit tests.

## Limitations: fullscreen and Spaces

- **`AXFullScreen` is best-effort.** Many apps expose it; some return unsupported. `isFullscreen` returns `nil` when the attribute is unavailable.
- **Spaces / Stage Manager.** Native fullscreen windows often live on their own Space. Setting `AXFullScreen` may succeed while Mission Control / Space focus still looks wrong. Raising a fullscreen window does not reliably switch Spaces.
- **Split View.** Fullscreen Split View pairs are poorly represented in AX; treat layout as undefined.
- **Minimize then raise.** `AXRaise` is a no-op on minimized windows. `SystemAccessibilityWindowService.raise` clears `AXMinimized` before raising.
- **Frontmost.** Raising a window alone does not activate a background app. The system service also sets `AXFrontmost` on the application element after raise.
- **Trust.** Without Accessibility permission, calls typically surface as `AccessibilityError.notTrusted` (or related AX failures). Prompt/trust UX lives in dawnAgent + dawnApp; these helpers do not prompt.
- **No maximize.** macOS Accessibility has no reliable maximize attribute; zoom/green-button behavior is app-specific.

Prefer these helpers for **normal / minimized** presentation. Treat **fullscreen** as optional and verify per target app when building layout actions.

Dawn wiring: `WMWorkspaceTransitionAction` applies `WMWindowLayoutAction` after opens when Accessibility is trusted. `WMWindowLayoutAction` reads `WorkspaceApplication.windowLayout` and calls this service.

# Menu Bar Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the menu bar app easier to discover and explicitly warn when launched outside the supported `.app` wrapper flow.

**Architecture:** Add a small app-side launch support helper that classifies the runtime as bundled app vs direct executable, then let `AppDelegate` show a startup warning when the unsupported mode is detected. Keep the menu bar UI change isolated to `MacIrlandApp.swift` so the visibility improvement stays low-risk.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, Swift Package Manager

---

### Task 1: Add failing tests for launch-mode detection

**Files:**
- Modify: `Package.swift`
- Create: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MacIrlandApp

final class AppLaunchSupportTests: XCTestCase {
    func testDetectLaunchModeTreatsAppBundleAsBundledApp() {
        let bundleURL = URL(fileURLWithPath: "/tmp/MacIrland.app")

        XCTAssertEqual(AppLaunchSupport.detectLaunchMode(bundleURL: bundleURL), .bundledApp)
    }

    func testDetectLaunchModeTreatsNonAppPathAsDirectExecutable() {
        let executableURL = URL(fileURLWithPath: "/tmp/.build/debug/MacIrland")

        XCTAssertEqual(AppLaunchSupport.detectLaunchMode(bundleURL: executableURL), .directExecutable)
    }

    func testUnsupportedLaunchMessagePointsToDevAppScript() {
        XCTAssertTrue(AppLaunchSupport.unsupportedLaunchMessage.contains("./Scripts/run-dev-app.sh"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppLaunchSupportTests`
Expected: FAIL because `AppLaunchSupport` does not exist yet

- [ ] **Step 3: Write minimal implementation**

```swift
enum LaunchMode: Equatable {
    case bundledApp
    case directExecutable
}

enum AppLaunchSupport {
    static func detectLaunchMode(bundleURL: URL = Bundle.main.bundleURL) -> LaunchMode {
        bundleURL.pathExtension == "app" ? .bundledApp : .directExecutable
    }

    static let unsupportedLaunchMessage = """
    MacIrland is expected to be launched as a bundled app during local development.

    Please start it with:
    ./Scripts/run-dev-app.sh
    """
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AppLaunchSupportTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Package.swift MacIrlandTests/AppLaunchSupportTests.swift MacIrlandApp/App/LaunchSupport.swift
git commit -m "test: cover menu bar launch mode detection"
```

### Task 2: Warn and stop on unsupported direct-executable launches

**Files:**
- Modify: `MacIrlandApp/App/AppDelegate.swift`
- Modify: `MacIrlandApp/App/LaunchSupport.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testShouldWarnForDirectExecutableLaunches() {
    XCTAssertTrue(AppLaunchSupport.shouldWarnForUnsupportedLaunchMode(.directExecutable))
    XCTAssertFalse(AppLaunchSupport.shouldWarnForUnsupportedLaunchMode(.bundledApp))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppLaunchSupportTests/testShouldWarnForDirectExecutableLaunches`
Expected: FAIL because helper does not exist yet

- [ ] **Step 3: Write minimal implementation**

```swift
static func shouldWarnForUnsupportedLaunchMode(_ mode: LaunchMode) -> Bool {
    mode == .directExecutable
}
```

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    let launchMode = AppLaunchSupport.detectLaunchMode()

    if AppLaunchSupport.shouldWarnForUnsupportedLaunchMode(launchMode) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Use the dev app launcher"
        alert.informativeText = AppLaunchSupport.unsupportedLaunchMessage
        alert.runModal()
        NSApp.terminate(nil)
        return
    }

    NSApp.setActivationPolicy(.accessory)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AppLaunchSupportTests/testShouldWarnForDirectExecutableLaunches`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add MacIrlandApp/App/AppDelegate.swift MacIrlandApp/App/LaunchSupport.swift MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "fix: warn on unsupported direct executable launches"
```

### Task 3: Make the menu bar entry more visible and document the result

**Files:**
- Modify: `MacIrlandApp/App/MacIrlandApp.swift`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the menu bar label**

```swift
MenuBarExtra {
    ...
} label: {
    Label("MI", systemImage: "terminal.fill")
}
```

- [ ] **Step 2: Document the change and outcome**

```markdown
- 菜单栏入口已从纯文本 `MI` 调整为图标 + 文本，更容易在右上角识别
- 非 `.app` 启动时会弹出明确提示，要求通过 `./Scripts/run-dev-app.sh` 启动
- 结果：减少“应用已运行但用户在菜单栏找不到”的误判
```

- [ ] **Step 3: Run full verification**

Run: `swift test && swift build`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add MacIrlandApp/App/MacIrlandApp.swift CLAUDE.md
git commit -m "fix: improve menu bar app discoverability"
```

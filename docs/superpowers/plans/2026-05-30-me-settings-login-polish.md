# Me Settings Login Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the existing login, Me, and Settings screens while hiding maintenance controls from Release users.

**Architecture:** Keep the existing SwiftUI navigation and view models. Add one compile-time build visibility helper, then reorganize SwiftUI sections in place with small private section builders so `SettingPage` reads as product sections instead of one long mixed list.

**Tech Stack:** SwiftUI, XCTest, Xcode build-for-testing.

---

### Task 1: Build Visibility Helper

**Files:**
- Create: `Shared/App/BuildConfiguration.swift`
- Modify: `iminkTests/iminkTests.swift`

- [ ] **Step 1: Write the failing test**

Add this test to `iminkTests/iminkTests.swift`:

```swift
func testDebugBuildShowsDeveloperOptions() {
    XCTAssertTrue(BuildConfiguration.showsDeveloperOptions)
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
xcodebuild build-for-testing -quiet -scheme imink -project imink.xcodeproj -destination 'platform=iOS Simulator,id=866B06F5-6597-4800-AD2C-ECD4D8CC695C' -only-testing:iminkTests/iminkTests/testDebugBuildShowsDeveloperOptions -derivedDataPath /tmp/imink-dd-me-settings-red
```

Expected: fail with `cannot find 'BuildConfiguration' in scope`.

- [ ] **Step 3: Implement the helper**

Create `Shared/App/BuildConfiguration.swift`:

```swift
enum BuildConfiguration {
    static var showsDeveloperOptions: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
```

- [ ] **Step 4: Run the test to verify GREEN**

Run the same build-for-testing command with `/tmp/imink-dd-me-settings-green`.

Expected: exit 0.

### Task 2: Polish Login And Me Page

**Files:**
- Modify: `imink/Views/Common/LoginView.swift`
- Modify: `imink/Views/Me/MePage.swift`

- [ ] **Step 1: Update login copy and layout**

Change `LoginView` so the title is benefit-first, the Nintendo button is a real `Button`, and the third-party authentication note is smaller supporting copy.

- [ ] **Step 2: Regroup Me page**

Keep the current `List`, but use sections named account, my records, personalization, and data management. Wrap the orientation test section in `#if DEBUG`.

- [ ] **Step 3: Build**

Run generic Debug build:

```bash
xcodebuild build -quiet -scheme imink -project imink.xcodeproj -destination generic/platform=iOS -configuration Debug -derivedDataPath /tmp/imink-dd-me-page-build
```

Expected: exit 0.

### Task 3: Reorganize Settings Page

**Files:**
- Modify: `imink/Views/Me/SettingPage.swift`

- [ ] **Step 1: Split list content into private section builders**

Create private `@ViewBuilder` section properties for account, user data, notifications, reminders, preferences, about, and Debug-only advanced controls.

- [ ] **Step 2: Move Release-visible controls into normal sections**

Release users see account controls, import/export/counts, notification permission/reminders, haptics, player-title update, refresh timestamps, and NSO version.

- [ ] **Step 3: Move maintenance controls behind `#if DEBUG`**

FAPI interval controls, manual game service token controls, background-task diagnostics, test notification buttons, historical schedule fetch, and delete-all-battle-data move into Debug-only sections.

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild build -quiet -scheme imink -project imink.xcodeproj -destination generic/platform=iOS -configuration Debug -derivedDataPath /tmp/imink-dd-settings-build
```

Expected: exit 0.

### Task 4: Final Verification And Commit

**Files:**
- All changed files.

- [ ] **Step 1: Check generated files stay ignored**

Run:

```bash
git status --short --branch
```

Expected: `.superpowers/` is not listed.

- [ ] **Step 2: Run final verification**

Run:

```bash
git diff --check
xcodebuild build-for-testing -quiet -scheme imink -project imink.xcodeproj -destination 'platform=iOS Simulator,id=866B06F5-6597-4800-AD2C-ECD4D8CC695C' -derivedDataPath /tmp/imink-dd-me-settings-final
xcodebuild build -quiet -scheme imink -project imink.xcodeproj -destination generic/platform=iOS -configuration Debug -derivedDataPath /tmp/imink-dd-me-settings-final-build
```

Expected: all commands exit 0.

- [ ] **Step 3: Commit**

```bash
git add Shared/App/BuildConfiguration.swift iminkTests/iminkTests.swift imink/Views/Common/LoginView.swift imink/Views/Me/MePage.swift imink/Views/Me/SettingPage.swift docs/superpowers/plans/2026-05-30-me-settings-login-polish.md
git commit -m "Polish Me settings and login screens"
```

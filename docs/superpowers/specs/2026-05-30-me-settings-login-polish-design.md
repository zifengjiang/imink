# Me, Settings, And Login Polish Design

## Goal

Polish the existing login flow, Me page, and Settings page without changing the app's main navigation or feature model. The work should make normal user paths feel deliberate, while keeping maintenance, diagnostic, and risky controls available only in Debug builds.

## Scope

- Refresh `LoginView` copy and layout so it reads like a product login screen, not an implementation note.
- Reorganize `MePage` sections around user intent: account, records, personalization, and data management.
- Hide developer/testing entry points from Release builds with `#if DEBUG`.
- Reorganize `SettingPage` into normal user sections plus a Debug-only advanced area.
- Keep existing actions and storage behavior intact unless the current UI exposes them in the wrong place.

## UX Rules

- Release users should not see FAPI tuning, manual game service token controls, background task test buttons, debug notification buttons, orientation test links, or destructive developer operations.
- Settings should separate passive status rows from active command buttons.
- Destructive actions should remain visually marked and confirmed.
- Login should explain the benefit first, then mention authentication/privacy details as supporting text.
- The existing visual style should be respected; this pass is cleanup and hierarchy, not a redesign.

## Proposed Structure

### Login

Show the app icon/context, a concise title, a short benefit-focused subtitle, a Nintendo Account login button, and a smaller privacy/authentication note. Keep `LoginViewModel.loginFlow()` as the single action.

### Me Page

Use the current `List` structure, but regroup entries:

- Account card, plus friends when logged in.
- My Records: Salmon Run, Splatfest, Stages, Weapons.
- Personalization: Nameplate editor.
- Data Management: Trash.
- Debug-only: Orientation test.

### Settings Page

Default Release sections:

- Account: login/session status, copy session token, logout.
- Data: import/export, record counts.
- Notifications and reminders: notification permission, schedule reminders, subscription cleanup.
- Preferences: haptics and player title format update.
- About: refresh times and NSO version display.

Debug-only advanced sections:

- Manual game service token controls.
- Background refresh diagnostics and test actions.
- FAPI request interval controls.
- Historical schedule fetch.
- Destructive data maintenance actions such as deleting all battle data.

## Testing

- Build the app for generic iOS Debug.
- Build for testing on the available iOS simulator.
- Confirm Release-only hiding is implemented through compile-time `#if DEBUG`, not runtime flags.
- Check that `.superpowers/` generated brainstorming artifacts remain untracked.

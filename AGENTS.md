# TopBuddy engineering guide

## Architecture

- SwiftUI owns user-visible state and views.
- `WorkspaceController` is the narrow AppKit boundary for opening safe resources, hiding apps, and requesting graceful termination.
- `TopBuddyNotchPanelController` is the only long-lived notch-window owner.
- `CodexBridge` invokes an installed Codex CLI only after a user message, with `--ephemeral` and `--sandbox read-only`, from a fresh empty temporary working directory.
- `NotionBrowserView` is the narrow `WKWebView` bridge. WebKit data never enters schedule, pet, shelf, or coach storage.
- `MusicAutomationClient` accepts only fixed Apple Music commands. Never execute user-provided AppleScript.
- `ScheduleStore` ships empty and loads a validated owner-only `today.json` or explicit paste import.
- `PetLibraryStore` performs no network request until the user opens the gallery and no download until the user chooses a pet.

## Model routing

- Keep planning, architecture, security judgment, review, and final acceptance in the Sol primary thread at max reasoning.
- Use Luna at max reasoning only for bounded implementation tasks when delegation is explicitly allowed.
- The primary reviews all delegated diffs and runs the relevant tests before acceptance.

## Commands

- Build: `swift build`
- Test: `swift test`
- Privacy audit: `./script/privacy_audit.sh`
- Build and launch: `./script/build_and_run.sh`
- Build, launch, and verify: `./script/build_and_run.sh --verify`
- Universal release package: `./script/package_release.sh <version>`

## Constraints

- Support macOS 14 or newer.
- Never bundle schedules, account identifiers, workspace URLs, user names, credentials, cookies, tokens, or development-machine paths.
- Keep all automatic capabilities off until first-run consent.
- Keep `~/Library/Application Support/TopBuddy/today.json` credential-free and mode `0600`.
- Never call `forceTerminate()`.
- Only open HTTPS URLs, HTTP loopback URLs, or validated app bundle identifiers.
- Never request Calendar or Music permissions before an explicit user action.
- Preserve Reduce Motion and keyboard accessibility.

## Definition of done

- `swift build`, `swift test -Xswiftc -warnings-as-errors`, and `script/privacy_audit.sh` pass.
- The staged `.app` launches through `script/build_and_run.sh --verify`.
- A fresh app shows setup before the notch or any permission dialog.
- The empty initial schedule, control presets, pet import, schedule import, safe resource policy, private persistence, rollover logic, and optional integrations are exercised.
- Release notes state signing and notarization status exactly.

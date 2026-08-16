# TopBuddy demo guide

This walkthrough is designed for a code review or SWE interview. It uses only generic schedule text and public example resources; it does not require an account, a private URL, a real calendar, a pet download, or a network integration. The repository intentionally contains no screenshots or captured user state.

## 1. Build and launch

From the repository root:

```bash
swift test -Xswiftc -warnings-as-errors
swift build
./script/privacy_audit.sh
./script/build_and_run.sh --verify
```

`--verify` stages and code-signs a local `dist/TopBuddy.app`, checks its signature, launches it, and confirms that the process is running. The app is empty on first launch, so setup appears before the notch or any optional permission prompt.

## 2. Use a generic schedule

In setup, choose **Observe** or **Assist** so the demo does not automatically open resources or hide apps. Do not enable Calendar, Music, Notion, Codex, or the pet gallery unless you specifically want to demonstrate that optional permission boundary.

Open the schedule importer and paste this table:

```markdown
| Time | Task | Exact actions | Finish target |
|---|---|---|---|
| 9:00–9:30 AM | Plan and research | Read one public reference and write the next small action. | One written next action. |
| 9:30–10:30 AM | Programming study | Implement one bounded parser change and run its tests. | One tested change and a saved resume point. |
| 10:30–10:45 AM | Break | Step away from the desk and return on time. | Break complete. |
| 11:00 PM–7:00 AM | Sleep | Keep notifications off. | Rest protected. |
```

Choose **Validate schedule**, inspect the four-row preview, then choose **Apply today**. The title-based demo inference shows a Notion focus-kit label for “Plan and research” and a Terminal application label for “Programming study”; no resource opens while Observe or Assist is selected.

## 3. Walk the visible MVP

Use the dashboard to show the imported agenda, current/next-block state, completion toggle, and explicit rollover affordance. Expand the notch from the menu bar, pin it, and move between the Buddy, Agenda, Focus, Music, and Shelf pages. The exact active block depends on the local clock; the imported rows and validation preview are deterministic.

For the Lock In path, select the programming block and review its allowlist before enabling it. Lock In can hide an unlisted regular app and offers a short, reason-gated in-memory exception. **End Lock In** remains available. If you demonstrate an approved website using a temporary handoff, use a generic HTTPS URL such as `https://example.com/docs`; the URL is handed to macOS's current default browser, and TopBuddy does not inspect that browser's tabs, cookies, history, logins, or page content.

## 4. Capture a privacy-safe screenshot set (optional)

If a portfolio or interview walkthrough needs screenshots, capture these states in order with the generic schedule above:

1. First-run setup showing the Observe/Assist/Focus choices and optional integrations off.
2. Schedule importer showing the four-row preview before applying it.
3. Dashboard showing the generic agenda and one selected block.
4. Expanded notch showing the current-block countdown and page tabs.
5. Lock In review showing an allowlist and the always-available **End Lock In** action.
6. Settings showing the permission-gated optional integrations, with no account or private service opened.

Before sharing an image, verify that it contains no personal schedule text, account IDs, private URLs, browser tabs, cookies, machine-specific paths, tokens, or notification content. Do not add captured images to this repository unless they are fully generic and reviewed.

# TopBuddy

TopBuddy is a local-first macOS schedule companion that lives in the MacBook notch. It follows an imported daily plan, opens the tools a block needs, hides distractions when allowed, keeps lightweight focus utilities close, and can use an installed Codex CLI as an opt-in schedule coach.

The public build starts empty: no schedule, account, workspace link, pet download, analytics SDK, or developer data is bundled.

## MVP features

- Notch-native compact and expanded states with hover, click-to-pin, drag-and-drop shelf, current-block countdown, and Reduce Motion support.
- First-run setup with Observe, Assist, and Focus control presets plus individual switches.
- Four-column Markdown/TSV schedule import and private `today.json` handoff.
- Per-block HTTPS, localhost, installed-app, book, file, and physical-material focus kits.
- Optional Lock In mode with a constrained browser, app hiding, and short reason-gated exceptions.
- Local completion state and explicit downstream rollover when a block needs more time.
- Optional Notion WebKit workspace, read-only Apple Calendar agenda, and Apple Music playback controls.
- Optional user-initiated Codex coaching through an installed CLI in an ephemeral read-only sandbox.
- [Codex Pets](https://codex-pets.net/) gallery plus local PNG, JPEG, GIF, WebP, or compatible animated sprite-sheet import.

## Control choices

| Preset | Automatic opening | Automatic hiding | Manual quit review | Notch |
|---|---:|---:|---:|---:|
| Observe | Off | Off | Off | Off |
| Assist | Off | Off | On | On |
| Focus | On | On | On | On |

Apple Music, Calendar, Notion, and Codex are separate opt-ins. Automatic focus can hide apps but never quits them. A quit request always requires a fresh app selection and uses normal macOS termination so apps can show save prompts.

## Lock In mode

Lock In turns the current block's focus kit into an allowlist. Approved apps remain available, approved websites open inside TopBuddy's constrained browser, and unlisted regular apps are hidden when they come to the front. A blocked app or website can receive a 5, 10, 15, or 30 minute exception only after the user writes a task-specific reason.

Lock In is a focus aid, not parental-control or security software. It does not force-quit apps, modify firewall rules, install a system extension, or make the Mac impossible to override. **End Lock In** is always available. Exception reasons and grants stay in memory and are cleared when Lock In ends or the schedule moves to a different block.

## Requirements

- macOS 14 or newer.
- A MacBook notch is recommended; the panel also uses a centered fallback geometry on other Macs.
- Optional: Apple Music, Notion, and the Codex CLI for their respective integrations.

## Install the MVP

The [`v0.2.1` GitHub prerelease](https://github.com/Frostand/TopBuddy/releases/tag/v0.2.1) contains a universal macOS app with Lock In focus kits and a notch-matched, easier-to-click control surface. It is ad-hoc signed because the project does not yet have an Apple Developer ID certificate, so macOS may require the normal first-open confirmation. For the most transparent path, build from source:

```bash
git clone https://github.com/Frostand/TopBuddy.git
cd TopBuddy
swift test
./script/build_and_run.sh --verify
```

The staged app is written to `dist/TopBuddy.app`.

## Import a schedule

Paste Markdown or tab-separated rows with exactly these columns:

```markdown
| Time | Task | Exact actions | Finish target |
|---|---|---|---|
| 6:00–6:30 PM | Dinner | Eat away from the desk and refill water. | Meal complete by 6:30 PM. |
| 6:30–7:30 PM | Programming study | Attempt one bounded problem and test it. | One tested program and a saved resume point. |
| 11:30 PM–7:00 AM | Sleep | Keep notifications off. | Rest protected. |
```

TopBuddy rejects malformed times, duplicate IDs, overlaps, unsafe URL schemes, and non-sleep blocks that cross midnight. The optional JSON handoff can also say which resources open immediately, which are allowed on demand, and which offline materials are needed. It is documented in [docs/daily-handoff.md](docs/daily-handoff.md).

## Privacy

TopBuddy has no account and no telemetry. Local schedules, completion records, file references, pet assets, and settings remain in `~/Library/Application Support/TopBuddy`. Optional integrations are described precisely in [PRIVACY.md](PRIVACY.md).

## Build, test, and package

```bash
swift build
swift test -Xswiftc -warnings-as-errors
./script/privacy_audit.sh
./script/build_and_run.sh --verify
./script/package_release.sh 0.2.1
```

`package_release.sh` creates a universal app zip and SHA-256 checksum. Set `TOPBUDDY_SIGNING_IDENTITY` and optionally `TOPBUDDY_NOTARY_PROFILE` to produce a Developer ID-signed and notarized package; otherwise it creates an honest ad-hoc-signed prerelease artifact.

## Project lineage

TopBuddy's notch behavior was informed by [Sapphire](https://github.com/cshariq/Sapphire) and [boring.notch](https://github.com/TheBoredTeam/boring.notch). TopBuddy uses an independent implementation and does not vendor either codebase. The project is nevertheless released under AGPL-3.0-or-later, matching Sapphire's strong open-source boundary. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

GNU Affero General Public License v3.0 or later. See [LICENSE](LICENSE).

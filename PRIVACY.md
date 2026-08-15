# TopBuddy privacy policy

TopBuddy is local-first software. The app has no TopBuddy account, advertising, analytics SDK, crash-upload service, or telemetry endpoint.

## Data stored locally

TopBuddy may store the following under `~/Library/Application Support/TopBuddy` or the app's preference domain:

- imported daily schedules and rollover titles;
- local completion state;
- selected pet metadata and pet image assets;
- file-shelf paths, never copies of shelf files;
- focus-kit resource labels, HTTPS URLs, localhost URLs, and app bundle identifiers;
- focus-kit book, file, physical-material, and note labels supplied by the schedule;
- user-selected settings;
- Notion WebKit cookies and website data in WebKit's normal local store.

Schedule, pet, shelf, and metadata files are written with owner-only permissions where TopBuddy controls the file.

## Optional external interactions

| Feature | Trigger | Data that leaves TopBuddy | Permission |
|---|---|---|---|
| Codex Pets gallery | User opens or searches the gallery | Search query and ordinary network metadata to `codex-pets.net` | No macOS permission |
| Pet download | User chooses **Use** | Selected public pet ID/request | No macOS permission |
| Codex coach | User enables coaching and sends a message | Current/next block titles, actions, finish targets, resource labels, rollover titles, and recent coach messages are passed to the installed Codex CLI, which may contact OpenAI according to that CLI's configuration | Existing Codex CLI setup |
| Notion workspace | User enables and opens Notion | Normal website traffic and WebKit session data to Notion and its sign-in providers | No macOS prompt |
| Apple Music | User selects Enable or chooses it during setup | Fixed local Apple Events commands to the Music app | macOS Automation |
| Apple Calendar | User selects Enable or chooses it during setup | No network data added by TopBuddy; event title/time/calendar are read into app memory | macOS Calendar read access |
| Resource opening | User presses Start, or enables automatic opening | The Mac opens only validated HTTPS, HTTP-loopback, or installed-app resources | No broad automation permission |
| Lock In browser | User enables Lock In and opens an approved site | Normal website traffic and WebKit session data can reach the selected site and third-party services embedded by that site; TopBuddy constrains top-level navigation, not webpage subresources | No macOS permission |

TopBuddy never reads or copies Codex authentication files. It invokes the installed executable with `--ephemeral` and `--sandbox read-only` from a fresh owner-only empty temporary working directory, then removes that directory after the response.

Calendar and Music each have an app-level enabled state in addition to macOS authorization. Disabling either integration clears its in-memory data and stops TopBuddy from using it; the user can separately revoke the underlying operating-system grant in System Settings.

## App control

- Automatic opening and hiding are off in the Observe and Assist presets.
- Auto-hide only calls the normal macOS hide operation.
- Lock In checks the frontmost regular app and hides it when its bundle identifier is not in the active block's focus kit. It does not inspect app documents or screen contents.
- Lock In exception reasons and grants are kept only in memory and are cleared when Lock In ends or the active block changes.
- Lock In is an assistive focus boundary, not parental-control, firewall, or tamper-resistant software. The user can end it immediately.
- Quitting is never automatic. A user must enable the tool, choose running apps, confirm, and let each app handle its normal save prompts.
- TopBuddy never force-quits another app.

## Removing local data

Quit TopBuddy, then remove `~/Library/Application Support/TopBuddy` and the TopBuddy preference domain using standard macOS tools. Removing the app alone does not delete those local files.

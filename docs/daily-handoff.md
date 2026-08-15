# Daily handoff schema

TopBuddy watches `~/Library/Application Support/TopBuddy/today.json`. The app accepts a replacement only when it decodes, matches the local date, has unique IDs, has no overlaps, contains safe resources, and limits cross-midnight blocks to Sleep.

```json
{
  "schemaVersion": 2,
  "date": "2030-01-02",
  "refreshedAt": "2030-01-02T15:00:00Z",
  "source": "My local planner",
  "rollover": ["Review one missed exercise"],
  "blocks": [
    {
      "id": "2030-01-02-programming-study-1110",
      "title": "Programming study",
      "startMinute": 1110,
      "endMinute": 1170,
      "category": "competition",
      "exactActions": "Attempt one bounded problem, test it, and save the exact resume point.",
      "finishTarget": "One tested program and one written next action.",
      "resources": [
        {
          "kind": "url",
          "label": "Course notes",
          "value": "https://example.com/notes",
          "openAtStart": true
        },
        {
          "kind": "application",
          "label": "Terminal",
          "value": "com.apple.Terminal",
          "openAtStart": true
        }
      ],
      "materials": [
        {
          "kind": "book",
          "label": "Course textbook",
          "detail": "Chapter 4, pages 82–96"
        },
        {
          "kind": "note",
          "label": "Error log",
          "detail": "Record the first wrong decision and exact redo point"
        }
      ],
      "competition": "Programming"
    },
    {
      "id": "2030-01-02-sleep-2330",
      "title": "Sleep",
      "startMinute": 1410,
      "endMinute": 420,
      "category": "sleep",
      "exactActions": "Keep notifications off.",
      "finishTarget": "Rest protected.",
      "resources": [],
      "materials": [],
      "competition": null
    }
  ]
}
```

## Rules

- `category`: `routine`, `commute`, `school`, `extracurricular`, `meal`, `homework`, `competition`, `research`, `scioly`, or `sleep`.
- `resources[].kind`: `url` or `application`.
- `resources[].openAtStart`: whether TopBuddy opens that resource when the block starts. When `false`, the resource is allowed in Lock In but opens only after the user chooses it. Older handoffs that omit this field default to `true`.
- URL resources must use HTTPS. HTTP is allowed only for `localhost`, `127.0.0.1`, or `::1`.
- Application values are macOS bundle identifiers, such as `com.apple.Terminal`.
- `materials[].kind`: `book`, `file`, `physical`, or `note`. `label` names the item and `detail` must say exactly what pages, chapter, file, equipment, or note action the block needs. Materials are instructions; TopBuddy does not open or read them.
- `competition` is an optional free-form label.
- Minutes are counted from local midnight. Only Sleep may cross midnight.
- Stable IDs should derive from local date, exact title, and start time so local completion follows the same deliverable across refreshes.
- The file and its directory should be owner-only (`0600` and `0700`).
- Never include passwords, tokens, cookies, email contents, OAuth data, or session material.

## Lock In focus-kit rules

- Every website the block may need must appear explicitly. Include a separate `openAtStart: false` resource for required login, documentation, or related domains instead of relying on an unbounded browser.
- TopBuddy allows top-level navigation to the listed host and its subdomains inside the Lock In browser. A listed page can still load its own third-party subresources, so prefer the narrowest trustworthy official host that can complete the task.
- Every app the block may need must have its exact installed bundle identifier. Do not guess bundle IDs.
- A schedule generator should put a readable `Use:` clause in `exactActions` and encode the same sites/apps in `resources` and the same books/files/equipment in `materials`.
- Lock In hides unlisted regular apps; it never force-quits them. The user can end Lock In immediately or grant a short in-memory exception with a specific reason.

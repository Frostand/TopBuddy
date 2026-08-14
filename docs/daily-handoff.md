# Daily handoff schema

TopBuddy watches `~/Library/Application Support/TopBuddy/today.json`. The app accepts a replacement only when it decodes, matches the local date, has unique IDs, has no overlaps, contains safe resources, and limits cross-midnight blocks to Sleep.

```json
{
  "schemaVersion": 1,
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
          "value": "https://example.com/notes"
        },
        {
          "kind": "application",
          "label": "Terminal",
          "value": "com.apple.Terminal"
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
      "competition": null
    }
  ]
}
```

## Rules

- `category`: `routine`, `commute`, `school`, `extracurricular`, `meal`, `homework`, `competition`, `research`, `scioly`, or `sleep`.
- `resources[].kind`: `url` or `application`.
- URL resources must use HTTPS. HTTP is allowed only for `localhost`, `127.0.0.1`, or `::1`.
- Application values are macOS bundle identifiers, such as `com.apple.Terminal`.
- `competition` is an optional free-form label.
- Minutes are counted from local midnight. Only Sleep may cross midnight.
- Stable IDs should derive from local date, exact title, and start time so local completion follows the same deliverable across refreshes.
- The file and its directory should be owner-only (`0600` and `0700`).
- Never include passwords, tokens, cookies, email contents, OAuth data, or session material.

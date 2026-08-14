# Contributing

Thanks for helping improve TopBuddy.

1. Open an issue describing the behavior, privacy impact, and proposed scope.
2. Fork the repository and create a focused branch.
3. Keep new capabilities opt-in and local-first.
4. Add or update tests.
5. Run:

```bash
swift test -Xswiftc -warnings-as-errors
./script/privacy_audit.sh
./script/build_and_run.sh --verify
```

Pull requests should explain user impact, permission changes, data flow, tests, and any residual limitation. Never commit real schedules, private URLs, account identifiers, cookies, tokens, or screenshots containing personal data.

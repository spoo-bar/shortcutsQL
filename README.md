# ShortcutsQL

A SwiftUI iOS app.

## Supported databases

| Engine | Default port | Driver |
| --- | --- | --- |
| PostgreSQL | 5432 | [PostgresClientKit](https://github.com/codewinsdotcom/PostgresClientKit) |
| MySQL | 3306 | [MySQLNIO](https://github.com/vapor/mysql-nio) |

Pick the engine when adding a server; the port, the database connected to when a
query doesn't name one, and the wording of validation errors all follow from it.
The PostgreSQL path requires SSL; the MySQL path negotiates TLS when the server
advertises it and connects in plaintext when it doesn't. Neither validates the
server certificate — MySQL and PostgreSQL servers overwhelmingly present the
self-signed certificate generated on first start — so traffic is encrypted but
not protected against an active man-in-the-middle.

## Requirements

- **Xcode 26** or later
- **iOS 26** deployment target

## Getting started

```bash
git clone https://github.com/spoo-bar/shortcutsql.git
cd shortcutsql
open ShortcutsQL.xcodeproj
```

Select an iOS Simulator (or a connected device) and press **⌘R** to build and run.

## Project structure

```
ShortcutsQL/                 # App sources (file-system synchronized group)
  ShortcutsQLApp.swift       # @main entry point
  ContentView.swift          # App shell: tabs, sheets, toasts
  BrandColors.swift          # SQL syntax highlighting palette
  Models/                    # Engines, connection services, query store, SQL validation
  Views/                     # Home, query editor, databases, settings
  Assets.xcassets/           # App icon & accent color
ShortcutsQLTests/            # Unit tests (Swift Testing)
  ShortcutsQLTests.swift
.github/workflows/ci.yml     # CI: builds & tests on every PR to main
```

The Xcode project uses **file-system synchronized groups**, so new files added to the
`ShortcutsQL/` and `ShortcutsQLTests/` folders are picked up automatically — no need to
register them in the project manually.

## Testing

Tests use Apple's [Swift Testing](https://developer.apple.com/documentation/testing)
framework (`@Test` / `#expect`).

Run them in Xcode with **⌘U**, or from the command line:

```bash
xcodebuild test \
  -project ShortcutsQL.xcodeproj \
  -scheme ShortcutsQL \
  -destination 'platform=iOS Simulator,name=iPhone 13,OS=latest'
```

## Continuous integration

The `Basic` GitHub Actions workflow runs on every pull request targeting `main`. It
builds the app and runs the full test suite on an iOS Simulator, so a PR can only be
merged once everything compiles and all tests pass.

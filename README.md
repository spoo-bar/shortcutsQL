# ShortcutsQL

A SwiftUI iOS app.

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
  Models/                    # Mock data, query store, SQL validation/highlighting
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

# Countdown

Countdown is a native macOS app for creating, organizing, and tracking countdowns to future events. It uses SwiftUI for the app UI, SwiftData for persistence, WidgetKit for widgets, and App Intents for Shortcuts and system integrations.

## Features

- Create countdowns with a title, target date, color, symbol, and tags.
- Browse countdowns in a native macOS split-view interface.
- Search, sort, and filter countdowns by status or tag.
- View live-updating remaining time, progress, and schedule details.
- Receive optional notifications when countdowns finish.
- Add configurable Countdown widgets.
- Use App Shortcuts to create, open, and delete countdowns.
- Share data across the app, widgets, and intents through the app group container.

## Requirements

- macOS target: see `Countdown.xcodeproj` for the current deployment target.
- Xcode with SwiftUI, SwiftData, WidgetKit, and App Intents support.
- Swift Package Manager only. The project does not use CocoaPods or Carthage.

## Project Structure

```text
Countdown/
+-- Countdown/                         Main macOS app target
|   +-- CountdownApp.swift             App entry point
|   +-- ContentView.swift              Root navigation shell
|   +-- App/                           Commands, URLs, handoff helpers
|   +-- Features/Countdowns/           Sidebar, detail, editor, and store
|   +-- Features/Settings/             Settings UI
|   +-- Services/                      Notifications and system event handling
|   +-- SharedUI/                      Reusable SwiftUI components
+-- CountdownShared/                   Shared models, persistence, settings, utilities
+-- CountdownIntents/                  App Intents and App Shortcuts
+-- CountdownAppIntentsExtension/      App Intents extension target
+-- CountdownWidgetExtension/          WidgetKit extension
+-- CountdownTests/                    Unit tests
+-- CountdownWidgetTests/              Widget tests
+-- script/build_and_run.sh            Local build/run helper
```

## Architecture

Countdown keeps SwiftData isolated behind shared persistence helpers:

```text
SwiftData CountdownItem
    -> CountdownDataActor
    -> CountdownSnapshot
    -> CountdownStore
    -> SwiftUI views
```

`CountdownSnapshot` is the value type used by the UI, widgets, and intents. Views do not read or mutate SwiftData models directly. `CountdownStore` owns UI state and mutations, while `CountdownDataActor` performs reads and writes against the SwiftData container.

Settings are stored through `CountdownSettingsStore` in the shared app group. Widget timelines are reloaded after store mutations so the widget extension stays aligned with app data.

## Build and Run

Build and launch the app:

```bash
./script/build_and_run.sh
```

Build and verify that the app launches:

```bash
./script/build_and_run.sh --verify
```

The helper script builds the `Countdown` scheme with code signing disabled by default:

```bash
CODE_SIGNING_ALLOWED=NO ./script/build_and_run.sh
```

## Tests

Run the test suite from the repository root:

```bash
xcodebuild \
  -project Countdown.xcodeproj \
  -scheme Countdown \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/CountdownDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Unit tests cover shared logic such as formatting, calculations, persistence, filtering, and App Intents behavior. Widget tests live in `CountdownWidgetTests`.

## Development Notes

- Keep shared logic in `CountdownShared` when it is used by the app, widgets, or intents.
- Keep app-only UI and state in the `Countdown` target.
- Route all SwiftData reads and writes through `CountdownDataActor`.
- Pass `CountdownSnapshot` values through UI and integration surfaces.
- Persist settings through `CountdownSettingsStore`.
- Avoid adding new package dependencies, entitlements, network requests, analytics, or AppKit unless the change explicitly requires it.

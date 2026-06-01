# AGENTS.md — Countdown macOS App

Read this file fully before making any changes to the codebase.

---

## Project Overview

Countdown is a native macOS app that lets users create and track multiple countdowns to future events. It includes a main window, a menu bar extra, a widget extension, and App Intents support.

**Target:** macOS (see Countdown.xcodeproj for deployment target)
**Language:** Swift
**UI Framework:** SwiftUI throughout — do not introduce AppKit unless absolutely necessary
**Persistence:** SwiftData via `CountdownDataActor` and `CountdownContainerFactory`
**Package Manager:** Swift Package Manager only

---

## Targets

| Target | Purpose |
|---|---|
| `Countdown` | Main macOS app |
| `CountdownShared` | Shared models, persistence, settings, utilities — used by all targets |
| `CountdownIntents` | App Intents extension |
| `CountdownAppIntentsExtension` | App Intents package |
| `CountdownWidgetExtension` | WidgetKit widget |
| `CountdownTests` | Unit tests |
| `CountdownWidgetTests` | Widget tests |

When adding new logic, put it in `CountdownShared` if it needs to be accessed by more than one target. Put it in `Countdown` if it is main-app-only.

---

## Architecture

### Data flow

```
SwiftData (CountdownItem) 
    → CountdownDataActor (async actor, thread-safe reads/writes)
        → CountdownSnapshot (value type, Sendable, used in UI)
            → CountdownStore (@Observable, @MainActor, source of truth for the UI)
                → SwiftUI Views (read-only, pass callbacks up)
```

**Never** access `CountdownItem` (the SwiftData model) directly from views or `CountdownStore`. Always go through `CountdownDataActor`.

**Never** mutate state directly in views. Views call closures or `store` methods; `CountdownStore` owns all mutations.

### Key types

- **`CountdownItem`** (`CountdownShared/Models/CountdownItem.swift`) — SwiftData `@Model`, the persisted source of truth. Has a `.snapshot()` method to produce a value-type snapshot.
- **`CountdownSnapshot`** (`CountdownShared/Models/CountdownTypes.swift`) — `Sendable` value type used in all UI and logic. Has a `.recalculated(now:)` method for live ticking without touching the database.
- **`CountdownStatus`** — `.running`, `.paused`, `.expired`
- **`CountdownStore`** (`Countdown/Features/Countdowns/CountdownStore.swift`) — `@Observable`, `@MainActor`. Single store injected via `.environment(store)`. All async mutations go through its private `mutate(_:)` helper, which handles errors, reloads snapshots, and triggers widget reloads.
- **`CountdownDataActor`** (`CountdownShared/Persistence/CountdownDataActor.swift`) — `@ModelActor` actor for all SwiftData reads and writes. Always instantiated fresh per operation inside `CountdownStore`.
- **`CountdownAppSettings`** / **`CountdownSettingsStore`** (`CountdownShared/Settings/`) — settings are a `Codable` struct persisted to the shared App Group `UserDefaults`. Update via `store.updateSettings(_:)`, never directly.

---

## File Structure

```
Countdown/
├── AGENTS.md                          ← you are here
├── Countdown/                         ← main app target
│   ├── CountdownApp.swift             ← @main — DO NOT MODIFY unless asked
│   ├── ContentView.swift              ← root NavigationSplitView
│   ├── App/                           ← app-level helpers (commands, URLs, handoff)
│   ├── Features/
│   │   ├── Countdowns/                ← sidebar, detail, editor, store
│   │   ├── MenuBar/                   ← MenuBarCountdownView
│   │   └── Settings/                  ← SettingsView
│   ├── Services/
│   │   ├── Notifications/             ← CountdownNotificationScheduler
│   │   └── SystemEvents/              ← CountdownSystemEventObserver
│   └── SharedUI/                      ← reusable UI components (rings, formatters)
├── CountdownShared/                   ← shared framework target
│   ├── Models/                        ← CountdownItem, CountdownTypes
│   ├── Persistence/                   ← CountdownDataActor, CountdownContainerFactory
│   ├── Settings/                      ← CountdownAppSettings, CountdownSettingsStore
│   ├── Formatting/                    ← CountdownFormatter
│   └── Utilities/                     ← CountdownConstants, CountdownCalculator
├── CountdownIntents/                  ← App Intents
├── CountdownWidgetExtension/          ← WidgetKit
└── CountdownTests/                    ← unit tests
```

---

## Code Rules

### SwiftUI
- Use `@Environment(CountdownStore.self)` to access the store in views — it is injected at the root
- Use `TimelineView(.periodic(from:by:1))` with `snapshot.recalculated(now:)` for live-ticking UI — see `CountdownDetailView` for the pattern
- Use semantic macOS colors only: `Color(.labelColor)`, `Color(.windowBackgroundColor)`, `.primary`, `.secondary` — never hardcode hex or RGB
- All interactive elements must have `.accessibilityLabel()` — see existing detail view for examples
- Use `#Preview` macros for all new views
- Do not put business logic inside views

### Swift
- Use `async/await` — no new Combine code
- No force unwraps (`!`) — use `guard let` or `if let`
- No `print()` — use `Logger` from the `os` framework
- Mark new shared types `public` and `Sendable` if they cross actor boundaries
- Use `// MARK: -` sections to organise methods in longer files

### Persistence
- All SwiftData reads and writes go through `CountdownDataActor`
- Always call `modelContext.save()` after mutations in `CountdownDataActor`
- Settings are persisted via `CountdownSettingsStore` to the shared App Group — key and suite name are in `CountdownConstants`
- After any data mutation in `CountdownStore`, `WidgetCenter.shared.reloadTimelines(ofKind:)` is called automatically via `mutate(_:)` — do not call it manually elsewhere

### Notifications
- Notification scheduling and cancellation go through `CountdownNotificationScheduler`
- Always respect `settings.notificationsEnabled` before scheduling — see `CountdownStore.scheduleNotification(for:)`

---

## What Codex Should and Should Not Do

### DO
- Follow the existing architecture strictly — new features should fit the established data flow
- Add new views under `Features/` in an appropriately named subfolder
- Add shared logic to `CountdownShared` if it will be used across targets
- Write or update unit tests in `CountdownTests` for any new `CountdownShared` logic
- Keep `CountdownSnapshot` as the currency type passed around in UI — never pass `CountdownItem` to views
- Use `CountdownError` for domain errors and surface them via `store.errorMessage`

### DO NOT
- Modify `CountdownApp.swift` unless explicitly asked
- Access `CountdownItem` from views or directly from `CountdownStore`
- Add new Swift Package dependencies without asking first
- Change entitlements or the App Group identifier
- Add network requests, analytics, or telemetry
- Introduce AppKit types into SwiftUI views
- Create storyboard or XIB files

---

## Running the Project

The Codex environment uses:

```
./script/build_and_run.sh
```

Do not change this script. If a build fails, report the exact compiler error rather than guessing at a fix.

---

## Tests

- Unit tests live in `CountdownTests/`
- Test `CountdownShared` logic (calculators, formatters, data actor) — not SwiftUI views
- Tests must pass before a task is considered done
- Use in-memory SwiftData containers for tests — see `CountdownContainerFactory.makeInMemoryContainer()`

---

## Commit Messages

Suggest a commit message after completing a task using this format:

```
feat: add recurring countdown support
fix: correct progress calculation when paused
refactor: extract notification logic into scheduler
test: add coverage for markExpiredCountdowns
```

---

## README.md

After completing a task which has made a major change to the app’s functionality, update the README to reflect this.

---

## When In Doubt

If a request is ambiguous, would require architectural changes, or touches entitlements/the app entry point — stop and ask. Do not guess.
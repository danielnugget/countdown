# Countdown UI Product Redesign

## Summary
Build a larger product step optimized for many countdowns: keep the native macOS split-view foundation, add tag-based organization and filtering, and replace the sparse detail-only experience with an overview dashboard plus richer countdown detail/editor surfaces. Preserve the existing architecture: SwiftData through `CountdownDataActor`, `CountdownSnapshot` as UI currency, `CountdownStore` as mutation owner, SwiftUI-only UI, no entitlement or app entry-point changes.

## Key Changes
- Add shared tag support:
  - Add `tags: [String]` to `CountdownItem` and `CountdownSnapshot`.
  - Normalize tags through a shared helper: trim whitespace, remove empties, deduplicate case-insensitively, preserve first-entered display casing, sort by localized title.
  - Update create/update APIs in `CountdownDataActor`, `CountdownStore`, and App Intents with default `tags: []` so existing call sites stay source-compatible where possible.
- Add browse/filter state:
  - Add `CountdownFilter` and `CountdownSort` UI state to `CountdownStore`: search text, selected tags, status filter, and sort mode.
  - Extend `CountdownDataActor.snapshots(...)` to filter by search, tags, and status, then sort by target date/title/created date.
  - Keep filters app-session scoped for v1; do not add new persisted settings unless the implementation naturally needs them.
- Redesign the main window:
  - Use a three-part desktop layout inside the existing `NavigationSplitView`: native sidebar filters, countdown list, and detail/dashboard area.
  - Sidebar shows smart entries: All, Upcoming, Finished, plus a Tags section derived from existing countdowns.
  - Countdown list rows stay native and lightweight but become more useful: symbol, title, compact remaining time, target date, progress sliver, and visible tag chips only when space allows.
  - When no countdown is selected, show an overview dashboard with next-up countdown, upcoming timeline groups, tag summary, and counts for upcoming/finished items.
- Redesign countdown detail:
  - Keep `TimelineView(.periodic(from:by:1))` for live ticking.
  - Add a stronger hero: large remaining time, target date, progress ring, icon/color, and finished state treatment.
  - Add detail sections for tags, schedule metadata, progress, created/updated timestamps, and quick actions.
  - Move edit/delete actions into the detail toolbar and context menus, with keyboard/menu command parity.
- Improve the editor:
  - Add tag entry/editing with token-style chips and keyboard entry.
  - Keep title, target date, color, and symbol, but improve layout into clearer sections with a live preview.
  - Validate title, future target date, and normalized tags before save; surface existing `CountdownError` messages through the store.
- Keep widgets and intents compatible:
  - Widget cards can ignore tags initially, except no compile break from the new snapshot field.
  - App Intents continue to create date countdowns without requiring tags; optional tag parameters can be omitted for this pass unless needed by compiler-facing API changes.

## Test Plan
- Add `CountdownShared` unit tests for tag normalization: trimming, empty removal, case-insensitive dedupe, display casing, and stable sorting.
- Add `CountdownDataActor` tests for create/update persisting tags and filtering by one or more selected tags.
- Add tests for status/search/sort interactions where actor behavior changes.
- Update existing snapshot/entity tests for the new `tags` field.
- Run `./script/build_and_run.sh` and report exact compiler errors if it fails.

## Assumptions
- The redesign should prioritize tag filtering over manual categories.
- The dashboard is the default empty/no-selection detail surface.
- This plan does not remove the currently present timer-related model fields; it only avoids reintroducing timer UI.
- No AppKit, new package dependencies, entitlement changes, network features, analytics, or `CountdownApp.swift` edits unless a compiler requirement makes a narrow app-entry adjustment unavoidable.

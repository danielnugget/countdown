# Countdown verification — 16 October 2026

## Result

The final macOS test run passed **33 tests, with 0 failures and 0 skipped tests** on an arm64 Mac running macOS 27.0.1. The signed app also built and launched successfully using `./script/build_and_run.sh --verify`.

The original 16 tests passed before this work. Three added regression tests then failed against the original code, confirming the search/sort, hidden selection, and failed-save navigation defects before their fixes.

## Issues fixed

| Issue | Change | Evidence |
|---|---|---|
| Search and filter changes fetched every countdown from SwiftData; sorting also refetched the store | Query cached snapshots locally, cache the sorted order, and combine predicates in one pass | Store regressions; live tag search, no-results search, and status filtering |
| An expired countdown could remain in Upcoming counts, filters, and Next Up | Recalculate summaries at the next deadline without a database operation | Unit regression; live overview changed from 1 Upcoming / 1 Finished to 0 Upcoming / 2 Finished without interaction |
| Finished countdowns and inactive scenes kept scheduling second updates | Bound the periodic schedule to active, running countdowns | Schedule regression; live finished state and idle sample |
| The open app missed writes from other processes | Observe persistent-store change notifications and refresh through the data actor | Observer regression; separate signed process created and deleted a QA countdown while the open overview updated automatically |
| Opening an item hidden by filters could lose its selection | Clear obstructing filters; load unknown IDs that may have been created elsewhere | Store regression |
| Changing an item's collection could hide the edited item | Clear incompatible filters after a successful update | Store regression and live collection edit |
| A failed save changed navigation and dismissed the editor | Return save success, preserve navigation on failure, retain editor contents, and prevent overlapping saves | Failed-creation regression; successful create/edit smoke checks |
| Editing a timer changed its symbol; an unsubmitted tag draft was lost on Save | Preserve the symbol and include the pending tag draft | Live creation/editing and persisted-field inspection |
| Notification preferences did not update existing requests; clock changes only rescheduled visible items | Reconcile all snapshots on preference/time changes and use the shared scheduler in App Intents | Recording-scheduler regressions for preferences and hidden countdowns; intent targets compile |
| Compact widgets could show stale minute values; future entries mixed their status with the wall clock | Schedule at visible-unit boundaries and expiration; render status from the entry snapshot | Refresh-policy regressions and widget render tests |
| Every widget entry carried the entire unused countdown collection | Keep only the selected countdown in each entry | Provider source and build verification |
| Empty or unchanged metadata rewrote the complete defaults payload | Skip unchanged tag/collection writes and absent removals | Isolated defaults regression |
| Editor symbol matching rebuilt and normalized static data repeatedly | Initialize the symbol catalogue once and tokenize the query once | Live symbol search and suggestion checks |

## Functional coverage

| Area | Verified |
|---|---|
| Creation and editing | Live title, collection, symbol, pending tags, save, edit, selection retention, relaunch persistence |
| Navigation and searching | Live library/detail/overview navigation, tag search, no results, Upcoming filter; automated sorting and hidden selection |
| Editor suggestions | Live collection/tag prefix suggestions and selection; compact “No matching symbols” state |
| Expiration | Live automatic overview/count changes; automated status filtering, fractional-second widget expiry, paused-item preservation, idempotent persistence |
| Persistence | In-memory create/update/delete, invalid input, fresh-actor reads, metadata cleanup and normalization |
| Settings | Native settings controls inspected; notification preference persistence and scheduling/cancellation tested with an isolated settings store and recording scheduler |
| Widgets | Small, medium, large, and extra-large cards rendered at all three precisions; bounded timeline and precision-transition tests |
| App Intents | Entity/intent tests and extension compilation; shared scheduler wired into create/delete |
| External writes | Live separate-process create/delete reflected without relaunch or reactivation |

Both live QA countdowns and their metadata/notifications were removed. The pre-existing countdown's ID and persisted fields were checked before and after and were unchanged. Existing notification, theme, and precision preferences were preserved.

## Performance evidence and limits

- Search/filter changes perform no SwiftData fetch. Search preserves a cached sorted order, so typing does not sort the whole collection again.
- Tag and collection counts are built when snapshots change instead of scanning the full collection once for every displayed group.
- Finished/inactive live schedules emit one date instead of a continuing second sequence. Running displays retain second updates.
- Widget entries no longer repeat the full collection, and minute/hour displays avoid second entries. Timelines remain capped at 300 entries.
- A short Debug idle sample after expiration reported **0.0% CPU across three samples**, approximately **73–74 MB** in `top`'s MEM column, and an unchanged CPU time counter. This is a small idle observation, not a controlled before/after benchmark or a Release memory guarantee.
- No new packages, network activity, analytics, or telemetry were added.

Actual notification banner/sound delivery, interactive Siri/Shortcuts execution, widget placement/configuration on the desktop, sleep/wake and time-zone changes on the real system, and large-library scrolling were not tested end to end. Notification logic, widget rendering/timeline policy, intent construction, and event routing have automated coverage; OS scheduling and permissions can still affect delivery.

## Reproduce

```sh
xcodebuild -project Countdown.xcodeproj -scheme Countdown \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/CountdownAuditTests CODE_SIGNING_ALLOWED=NO test
./script/build_and_run.sh --verify
git diff --check
```

Implementation references: Apple's [TimelineView documentation](https://developer.apple.com/documentation/SwiftUI/TimelineView), [notification cancellation documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/removependingnotificationrequests(withidentifiers:)), and [persistent-store change notification documentation](https://developer.apple.com/documentation/Foundation/NSNotification/Name-swift.struct/NSPersistentStoreRemoteChange).

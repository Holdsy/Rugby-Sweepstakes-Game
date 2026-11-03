# Regression tests

Run the shared **Ruck of the Draw Regression** scheme with **Product → Test (⌘U)** in Xcode, or run:

```sh
./Scripts/test-regressions.sh
```

The script creates or reuses a dedicated **Ruck Regression Tests iOS 27** iPhone simulator. It prefers iOS 27.0 when installed and otherwise uses the newest available runtime. Xcode, an installed iOS simulator runtime and Python 3 are required. Results, logs and an `.xcresult` bundle are saved under `.test-results/` (ignored by Git). To choose a destination:

```sh
TEST_DESTINATION='platform=iOS Simulator,id=YOUR-SIMULATOR-UUID' ./Scripts/test-regressions.sh
```

The suite tests the app's actual compiled production code using `@testable import`. Every test uses its own temporary UserDefaults suite; network tests use `URLProtocol` responses. No private API keys, external requests, WhatsApp messages or personal game data are required. Draw checks assert allocation invariants rather than expecting a particular random outcome. Tests run serially because the network stub is shared.

Coverage includes:

- Saved people and game selection survive relaunch independently, including a seventh participant; draw locks, the 15-person selection limit and save-failure rollback.
- Draw validation, equal allocation and duplicate prevention for 2, 6 and 15 participants.
- All scoring types, older-score corrections, persisted totals, substitution chains, field-slot order and each replacement's allocation-specific leaderboard points.
- Completion locks, immutable historical names, save-failure rollback, reopening and migration/corrupt-data preservation.
- Partial draft persistence, game/team/sample isolation and deletion without changing saved games.
- Backup export/restore, credential exclusion, unsupported/corrupt/oversized files, recovery copies and saved-record validation.
- Scoreboard caching, stale/missing scores, offline/auth/quota/server failures and fixture-switch races.
- Conservative photo matching, transparent-image preference, photo-page parsing and persisted photo settings.
- Half-time image rendering, score freshness checks and continued second-half scoring.
- Team amendments, atomic starter/bench swaps, unchanged allocations and exclusions, audit persistence, historical names, legacy decoding and save-failure rollback.
- Draw/results image rendering, long participant names, tied winners, displayed match dates and app branding.

Still test on a physical iPhone: WhatsApp delivery, Files/iCloud permissions, visual accessibility at large text sizes and the accuracy/timeliness of real provider data. Those external integrations are intentionally not simulated as successful deliveries by the unit tests.

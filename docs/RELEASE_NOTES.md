# Release notes

## 1.1 (4) — 3 November 2026

### Changes

- Consistent deep teal and gold appearance across the app, with adaptive light/dark surfaces.
- Half-time update images and text sharing from the leaderboard or Match Day actions. Images show current standings without finishing the game. A recent provider-confirmed half-time score is included when available.
- Amend Match-Day Team for late starter and bench changes after the draw. Shirt slots keep their allocations, exclusions, points and substitution links. Starter/bench name swaps save together; duplicate and blank names are rejected.
- Timestamped amendment history in current and saved games, with original names retained in older scoring entries.
- Updated illustrated README and user guide.

### Validation

- 48 automated regression tests passed; zero failures or skips.
- Signed Release archive verified for version 1.1, build 4.
- Simulator checks covered light/dark appearance, sharing previews, native image share sheet, amendment editing and cancellation.

### Suggested TestFlight checks

1. Update from build 3 and confirm existing games and people remain available.
2. Open Match Day and share a half-time image to WhatsApp. Close the preview and continue scoring.
3. Before kick-off, amend a starter and bench name, confirm allocations stay unchanged, and share the updated draw.
4. Review the amendment history and confirm that cancelling further edits changes nothing.
5. Finish a sample game and share final results; check both light and dark appearance.
6. Export a backup and verify that a restored sample retains amendment history.

For a substitution during play, use **Make Substitution**. Team amendment corrects shirt-slot names and retains any points already recorded in those slots.

## 1.1 (3) — 3 November 2026

First TestFlight build of Ruck of the Draw, including the new app icon, player-photo sharing, replacement point breakdowns, saved drafts, backup/restore, live match scoreboard and 41 regression tests.

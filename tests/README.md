# Tests

All test assets are excluded from web/mobile exports.

## Headless (Godot)

```bash
godot --headless --path . res://tests/GameplayTest.tscn
godot --headless --path . res://tests/ScoringTest.tscn
godot --headless --path . res://tests/ChallengeTest.tscn
godot --headless --path . res://tests/SpawnerStress.tscn
```

- `GameplayTest` boots the real app and verifies input, combo multipliers,
  one-per-obstacle perfect dodges, collision/reset, game over, restart, pause, revive,
  challenge reward/duplicate guard, save persistence and local analytics.
- `ScoringTest` unit-tests combo tiers, perfect timing configuration, difficulty limits,
  pattern unlocks and the deterministic daily challenge catalog.
- `ChallengeTest` verifies daily progress, date rollover, save persistence and that a
  completed challenge cannot reward twice.
- `SpawnerStress` simulates five minutes at 60 Hz with a seed and asserts pattern
  variety, recovery sections, spacing and a bounded active set.

## Visual QA

```bash
godot --path . --resolution 1080x1920 res://tests/VisualCheck.tscn
```

Writes PNGs to `tests/artifacts/` for every screen. This is a manual review harness,
not a pixel test. It needs a windowed run (no `--headless`).

## Web smoke (external dependency)

```bash
npm install playwright   # once, in this folder or a temp folder
./tools/build_web.sh
python3 -m http.server 8765 --directory exports/web
node tests/web_smoke.mjs
```

Requires Google Chrome installed. Uses the `chrome` channel and writes screenshots
to `tests/artifacts/`. Exits non-zero on page errors, failed requests or console
errors. This is a development tool only; it is not bundled into the game.

See [docs/testing.md](../docs/testing.md) for the verified matrix and known gaps.

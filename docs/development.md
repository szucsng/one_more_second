# Development Guide

## 1. Environment

- **Godot 4.7.2** standard edition.
- Any OS for desktop/web work; macOS for iOS.
- Optional for asset regeneration:
  - Python 3.10+ (`tools/generate_audio.py`, `tools/build_icons.gd`, `tools/build_theme.gd`)
  - `ffmpeg` with a Vorbis encoder for the music loop
- Optional for mobile: JDK 17 + Android SDK; Xcode.

Open `project.godot`. The project intentionally commits the generated `.import`/`.uid`
sidecars needed by Godot 4.7 but ignores `.godot/`.

---

## 2. Everyday loop

```bash
# Run
godot --path .

# Import after adding assets
godot --headless --path . --import

# Headless tests
godot --headless --path . res://tests/GameplayTest.tscn
godot --headless --path . res://tests/SpawnerStress.tscn

# Visual screenshots (desktop window; 1080x1920)
godot --path . --resolution 1080x1920 res://tests/VisualCheck.tscn
```

Screenshot output: `tests/artifacts/` (ignored by git). The visual harness exercises
menu, settings, skins, statistics, gameplay, pause, game over and the test ad.

### Debugging gameplay

- Godot editor → *Debugger → Monitors* for FPS, draw calls, memory.
- The gameplay state enum is `RUNNING=0, PAUSED=1, DYING=2, GAME_OVER=3, AD=4`.
- Add temporary prints or use the remote scene tree; do not commit debug prints.
- Force a specific lane/obstacle in the editor by pausing the scene and editing nodes.

### Save data during development

Godot `user://` locations:

| OS | Path |
| --- | --- |
| macOS | `~/Library/Application Support/Godot/app_userdata/ONE MORE SECOND/` |
| Windows | `%APPDATA%\Godot\app_userdata\ONE MORE SECOND\` |
| Linux | `~/.local/share/godot/app_userdata/ONE MORE SECOND/` |
| Web | browser IndexedDB for the game origin |
| Android | app private data (`user://`) |
| iOS | app sandbox (`user://`) |

Files:

- `save.json`, `save.bak.json`
- `analytics/events-YYYY-MM-DD.jsonl`

Deleting the folder resets the player (including unlocks/settings). The in-game
**Reset Progress** clears scores/statistics but keeps settings and skins.

---

## 3. Source of truth for generated assets

The repository does not rely on opaque binary source files for its design system.
Everything visual/audible can be regenerated:

### UI theme

Edit `tools/build_theme.gd` (colors come from `scripts/core/palette.gd`) and run:

```bash
godot --headless --path . --script tools/build_theme.gd
```

This overwrites `assets/theme/ui_theme.tres`. Do not hand-edit the `.tres`; it will be
rebuilt. Fonts are loaded from `assets/fonts/`.

### Icons and splash

Edit the SVGs in `assets/icons/` and `assets/textures/splash.svg`, then:

```bash
godot --headless --path . --script tools/build_icons.gd
```

This regenerates:

- app icons (web/desktop, Android adaptive/legacy/monochrome, iOS sizes)
- `assets/textures/splash.png`
- favicon-sized PNGs

The Android/iOS export presets point at the generated PNGs.

### Audio

```bash
python3 tools/generate_audio.py
```

- SFX are synthesized to mono 16-bit WAV.
- The music loop is synthesized to 19.2 s stereo, encoded to OGG Vorbis at 144 kbps
  via ffmpeg. If ffmpeg has no Vorbis encoder, the script keeps a WAV fallback.
- All audio is original/generated; do not replace it with copyrighted samples.

### Web export

```bash
./tools/build_web.sh
```

Runs import + release export, writes `exports/web/`, creates the itch.io ZIP and
prints preview instructions.

---

## 4. Adding content

### A new free skin

Add an entry to `SkinManager._skins`:

```gdscript
{
    "id": "ice",
    "name": "ICE SIGNAL",
    "tagline": "A colder frequency.",
    "primary": Color("#8BEFFF"),
    "secondary": Color("#FFFFFF"),
    "accent": Color("#4A7CFF"),
    "trail": Color("#8BEFFF"),
    "free": true,
    "coming_soon": false,
    "store_price": "",
}
```

It appears automatically in the skins grid and menu preview. No other code change is
needed. Premium entries should use `free = false`, `coming_soon = true`, and remain
disabled until a validated store unlock exists.

### A new obstacle pattern

In `ObstacleSpawner._spawn_pattern()` add a `match` branch with lane/delay items, add
it to `Difficulty.allowed_patterns()` at the intended unlock time, and give it a weight
in `_weighted_choice()`. Rules:

- never place two lanes at the same arrival time;
- leave at least **0.24 s** between opposite-lane arrivals (human switch budget);
- alternate lanes;
- test with `SpawnerStress` for five minutes.

### A new analytics event

1. Add the string to `Analytics.ALLOWED_EVENTS`.
2. Call `Analytics.track("event_name", {...})`.
3. Keep the payload free of personal data.
4. Document it in `docs/architecture.md`.
5. If a remote provider is added, update the privacy policy and consent first.

### A new screen

1. Create `scenes/<area>/Screen.tscn` with a root `Control` anchored full-rect.
2. Add `NeonBackdrop` as the first child.
3. Add a content `MarginContainer`; call `Platform.apply_safe_margins(...)`.
4. Use theme type variations, not hard-coded fonts/colors.
5. Add a path constant + helper method in `SceneRouter`.
6. Route back with `SceneRouter.go_menu()` and handle `Esc` / Android back.
7. Add it to `tests/visual_check.gd`.

### A new setting

1. Add it to `SaveManager._defaults().settings` with a default.
2. Add the UI row in `Settings.tscn` + handler in `settings.gd`.
3. Validate/clamp it in `_sanitize()` if numeric.
4. React to `SaveManager.settings_changed` where relevant.
5. Document it in the README feature list.

---

## 5. Code conventions

- Typed GDScript where practical (`var x: float`, `Array[Obstacle]`, signal types).
- File names snake_case; classes PascalCase via `class_name`.
- Autoloads: no `class_name` (avoids global name collisions); refer to the autoload.
- One responsibility per script. Gameplay state lives in `gameplay.gd`; spawn
  configuration in `spawner.gd`; pure curves in `difficulty.gd`.
- Comments only where the reason is non-obvious (fairness rules, web quirks).
- No TODOs for v1 features. Deliberate future integrations are documented in `docs/`.
- Never hard-code paid/service credentials; no keystores in the repo.
- Public APIs return typed values and fail safely.
- UI copy is English; comments/docs are English. Player-facing Hungarian is out of
  scope for v1 (the game is English-only).

---

## 6. Tests

### Gameplay integration (`tests/gameplay_test.gd`)

Runs the real Main scene and asserts:

- menu boots and gameplay loads;
- spawner is active; HUD exists;
- an obstacle can be spawned and scores when it passes;
- collision kills the player and game over appears;
- restart resets the run, records exactly one game, updates best;
- pause freezes the spawner; resume restores play;
- test rewarded ad opens, grants revive, and resumes the run;
- save reload preserves best;
- local analytics file exists.

### Spawner stress (`tests/spawner_stress.gd`)

Runs 18,000 simulated 60 Hz frames (5 minutes) with a mock container, drives a
scripted safe-lane bot, and asserts:

- >250 obstacles spawned;
- active obstacles < 24;
- no unreactable two-lane block (<0.24 s arrival gap or simultaneous band);
- bot survives;
- elapsed time covered.

Both tests exit non-zero on failure, so they can be used in CI.

### Visual harness

`tests/visual_check.gd` is intentionally excluded from export. It writes screenshots
for manual review. Do not treat it as an automated pixel test; layout/design decisions
still need human eyes.

### Web smoke test (manual, external to repo)

A Playwright script can load the export from a local HTTP server and verify:

- loading overlay hides;
- menu appears after Play;
- keyboard input switches lanes;
- pause opens;
- no page errors.

This is how the shipped web export was validated; see [testing.md](testing.md).

---

## 7. Upgrading Godot

1. Install the new editor and matching export templates.
2. Back up `project.godot`, `export_presets.cfg`, and `web/shell.html`.
3. Open the project once in the editor; accept format migrations.
4. Run `--import`, both headless tests and the visual harness.
5. Rebuild web and smoke-test it.
6. Check export preset options (they change between minor versions) in the editor.
7. Update the version and `CHANGELOG.md`.

Do not upgrade mid-release. The documented baseline is 4.7.2.

---

## 8. Git hygiene

Committing:

- `project.godot`, scenes, scripts, systems, assets, fonts with OFL licenses;
- `export_presets.cfg`, `web/shell.html`, workflows, docs, tests, tools;
- `.uid` files created by Godot 4.4+.

Never committing:

- `.godot/`
- `exports/` build output
- `tests/artifacts/`
- keystores, provisioning profiles, `.env`, secrets
- OS metadata.

The included `.gitignore` covers these.

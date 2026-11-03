# Troubleshooting

## General

### The project opens with missing scripts or pink scenes

- Ensure the Godot version is **4.7.2** (or a compatible 4.x).
- Reimport: `godot --headless --path . --import`.
- Delete the cache if an upgrade broke it:
  ```bash
  rm -rf .godot
  godot --headless --path . --import
  ```
- Check the Output panel for the first error; later errors are often cascades.

### A script fails to parse

- Look at the file/line in the error.
- The project is strongly typed in places; do not remove type annotations without
  checking the call sites.
- Autoload identifiers (`SaveManager`, `AudioManager`, etc.) are global: their
  autoload entries must exist and load order matters. See `project.godot`.
- Run:
  ```bash
  godot --headless --path . res://tests/GameplayTest.tscn
  ```
  Parse errors appear before the test output.

### Theme looks default/grey

- `assets/theme/ui_theme.tres` must exist and be set in
  `project.godot → gui/theme/custom`.
- Rebuild it:
  ```bash
  godot --headless --path . --script tools/build_theme.gd
  ```
- Fonts must be imported; run `--import`.

---

## Gameplay

### Tapping a button also switches lanes

- Buttons should consume the event; only `_unhandled_input` switches lanes.
- A custom UI element with `mouse_filter = IGNORE` over the playfield can let taps
  through by design. Keep buttons at `STOP`.
- Verify a new overlay's root has a `ColorRect` with `mouse_filter = STOP`.

### The game is too hard / too easy

Tune `scripts/core/difficulty.gd`:

- `START_SPEED`, `MAX_SPEED`, `RAMP_SECONDS`
- `START_INTERVAL`, `MIN_INTERVAL`
- pattern unlock times
- `ObstacleSpawner` delays and same-lane guard in `spawner.gd`

Re-run `SpawnerStress` after any pattern/spacing change. Do not shrink opposite-lane
arrival gaps below ~0.24 s.

### Score does not increase

- `Obstacle.passed` must be connected with the obstacle argument
  (`spawner.gd`: `.bind(obstacle)`).
- `PASS_Y` must be below the player.
- Only the spawner-created obstacles emit signals; manually added test nodes need the
  connection.

### Combo looks wrong or perfect dodges never trigger

- Combo increments only in `_on_obstacle_passed`, once per obstacle. If a signal is
  connected twice, check the spawner binding.
- Perfect dodges require a switch within `Scoring.PERFECT_MIN_TIME` and
  `Scoring.PERFECT_WINDOW`; the bonus is confirmed only when the obstacle passes.
- A switch into an obstacle in the new lane is intentionally not rewarded.
- Use `tests/GameplayTest` and `tests/ScoringTest` before tuning constants.

### Daily challenges reset unexpectedly

- The set is local-date based; changing the device date or time zone can roll it.
- Clearing app/site data deletes local progress.
- Challenges are stored in the existing `save.json` under `challenges`; there is no
  second save file.

### Player passes through obstacles

- Player: layer 1, mask 2. Obstacle: layer 2, monitorable. Do not set both areas to
  `monitoring = false`.
- Collision shapes must exist; the obstacle creates its shape in `_ready`.
- Extreme speed tunnelling is not an issue at the current 1500 px/s cap and 78 px
  collision height, but re-check if you raise speed dramatically.

### Pause/ads freeze the wrong things

- The game intentionally does **not** call `get_tree().paused`.
- `pause_game()` freezes the spawner and player; the backdrop keeps animating.
- UI layers: HUD layer 10, overlay layer 20, test ad layer 120.
- If a new overlay can't receive input, check its CanvasLayer order and mouse filters.

---

## Save data

### Progress is not saved

Check the `user://` path (see [development.md](development.md)), disk permissions, and
the Godot Output panel for `SaveManager` errors. The save layer writes a verified temp
file and falls back to a direct write if rename fails.

### Save file is corrupted

- The game automatically tries `save.bak.json`.
- Inspect both files as JSON; delete them to reset (this removes progress).
- Do not edit the live file while the game is running.

### “Reset Progress” behaves differently than expected

It clears best score and statistics but keeps settings, skins, unlocked skins and ad
counters. To fully reset, delete the app/site data.

### Web saves disappeared

- IndexedDB is origin-specific. Changing domain, subdomain, port or path origin loses
  the previous save.
- Private browsing / clearing site data deletes it.
- Browser storage quotas or enterprise policies may block persistence.

---

## Audio

### No music on web

Browsers require a user gesture. Click or tap once. `AudioManager` retries on the first
input. Do not set `autoplay` assumptions in HTML.

### No audio at all

- Check the menu sound state and Settings → SFX/Music/volume.
- The Master bus is muted below 0.1% volume.
- Verify the audio files exist in `assets/sounds` and `assets/music`.
- In headless tests audio is not meaningful; test in the editor/device.

### Music stops after a scene

- Music is an autoload and should persist. `_apply_settings` stops it only when the
  Music setting is off.
- If you add a second `AudioStreamPlayer` for music, stop it on scene exit or keep it
  in the autoload.

### Regenerating audio fails

`tools/generate_audio.py` needs Python 3; OGG encoding needs ffmpeg with a Vorbis
encoder. Without it, a WAV fallback is kept. Update `AudioManager` if you switch file
extensions. Do not commit copyrighted replacements.

---

## Web

### Blank page

1. Serve over HTTP(S), never `file://`.
2. Confirm `.wasm` MIME type is `application/wasm`.
3. Check DevTools Console for WebGL2 / WebAssembly errors.
4. Disable browser extensions that block WASM.
5. Try Chrome/Edge first.

### “The following features are required…” or WebGL errors

- The game needs **WebGL2**. Update the browser/driver or enable hardware
  acceleration.
- Compatibility renderer is already set; don't switch to Forward+ for web.

### Loading is very slow

- `index.wasm` is ~38 MB uncompressed. Enable gzip/Brotli (→ ~10 MB).
- Check that the host is not serving it uncompressed.
- Use a CDN; avoid mobile roaming for first load.
- GitHub Pages compression is not guaranteed; use Cloudflare Pages/Netlify/nginx if
  necessary.
- Caching helps repeat visits, but fixed filenames require cache busting/versioning.

### Fullscreen button does nothing

- Fullscreen requires a user gesture.
- iPhone Safari may not allow arbitrary-element fullscreen.
- Desktop Settings toggle uses the Fullscreen API; browser Esc exits fullscreen but
  the saved preference remains until toggled again.

### Touch does nothing but mouse works

- The gameplay handler accepts `InputEventScreenTouch`; verify the shell hasn't
  prevented touch (`touch-action: none` is already set).
- Check for an overlay with a large `mouse_filter = STOP` covering the playfield.
- Browser devtools mobile emulation can behave differently from a real device.

### Web export references a missing file

- Re-export with `./tools/build_web.sh` (it clears stale output).
- Ensure the custom shell is at `web/shell.html` and the preset points to it.
- Multiplication of placeholders (`$GODOT_URL`, `$GODOT_CONFIG`,
  `$GODOT_HEAD_INCLUDE`, `$GODOT_PROJECT_NAME`) must remain intact in the shell.

---

## Android

| Error | Fix |
| --- | --- |
| Invalid Android SDK path | Install SDK platform-tools/build-tools; set Editor Settings |
| Valid Java SDK path required | Install JDK 17 and set the Java SDK path |
| build-tools directory missing | `sdkmanager "build-tools;35.0.0"` |
| apksigner missing | Same; verify SDK path |
| Release export unsigned | Configure the release keystore |
| AAB greyed out | Install Android build template and enable Gradle Build |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Uninstall the old app or use matching keys |
| Black screen after splash | Check logcat: `adb logcat | grep -i godot` |
| Wrong orientation | Project setting + export preset + manifest |
| Icon is old | Clean export, regenerate icons, reinstall |
| Haptics don't work | Device support/permission; check VIBRATION |
| Performance issues | Test release build, reduce effects, arm64-only AAB, profile |

`adb logcat` is the best first stop for native runtime failures.

---

## iOS

| Error | Fix |
| --- | --- |
| Team ID missing | Set `application/app_store_team_id` |
| Signing fails | Open in Xcode, select team/provisioning |
| Bundle id taken | Use a unique id owned by you |
| Blank app | Match export template version with Godot; check Xcode console |
| Orientation wrong | Target settings + project portrait setting |
| Safe area overlap | Test on device; adjust base margins/HUD offsets |
| Archive upload rejected | Check privacy manifest, icons, version/build numbers |

No iOS build is claimed tested; follow [ios-build.md](ios-build.md) with a real team.

---

## Ads and IAP

### The “WATCH AD TO CONTINUE” button is missing

Expected:

- v1 has no real ad SDK;
- the test ad is disabled on **web**;
- it may also be hidden if the ad overlay is already open or after the single revive
  has been used in the current run;
- when a real provider is integrated, only advertise it when loaded.

### Test ad overlay doesn't appear on web

By design: `AdConfig.ALLOW_TEST_ADS_ON_WEB = false`. Web ads are a separate future
decision. To QA the web overlay locally, set the flag to true **for the test build
only** and do not publish it.

### Store button does nothing

Expected: `Monetization.store_available` is false and premium skins are disabled
“COMING SOON”. No fake purchases exist. Implement billing first.

### I enabled real ads and the game shows test ads

Set `AdConfig.TEST_MODE = false` and wire the real provider. Never ship production IDs
that you do not own.

---

## UI / layout

### UI is cropped or off-screen

- The design canvas is 1080×1920 with stretch mode `canvas_items` and aspect `keep`.
- All UI must be anchored; avoid fixed offsets that assume a different aspect.
- On very tall phones, safe-area code adds top/bottom margins.
- Settings/skins/statistics use scroll containers where content can grow.

### Text is clipped in a button

Increase the button's minimum size or reduce the font size; Audiowide is wider than
Rajdhani. Avoid using Audiowide for variable-length numbers.

### Statistics cards overlap

Do not animate `position` of children inside a Container. Animate `modulate` or
`scale` instead. This bug was fixed during QA.

---

## Tests

### Test exits with code 1 but all checks pass

The test uses the number of failed assertions as exit code logic; inspect
`FAIL` lines. Also ensure no duplicate instance of an autoload/test is running.

### Headless test hangs

- A parse error can prevent the test script from loading and the engine remains open.
  Use `--quit-after` to force exit and read the parse error:
  ```bash
  godot --headless --path . --quit-after 300 res://tests/GameplayTest.tscn
  ```
- A missing `quit()` path usually means the script failed to load.

### Visual screenshots are missing

The harness writes to `tests/artifacts/`; ensure the directory is writable and the
game is not running with `--headless` (no rendering). Use the normal windowed binary.

---

## Still stuck?

1. Reproduce in the editor with a minimal run.
2. Read the **first** console error.
3. Run the headless tests.
4. Check the Godot version and export template version.
5. For web, check Network → wasm MIME/compression and Console.
6. For mobile, check logcat/Xcode console and signing.
7. If you changed patterns/save schema/export presets, revert the last change and
   bisect.

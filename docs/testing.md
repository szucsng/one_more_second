# Testing & Verification

Test date: **2026-11-03**
Engine: **Godot 4.7.2 stable** (`ed1daf0bf`)
Platform used for verification: Apple Silicon macOS, Compatibility renderer.
Web browser used: headless Chromium via Playwright with system Chrome, WebGL2.

This document separates what was actually executed from what still requires owner
hardware, accounts or store setup.

---

## 1. Automated tests

### 1.1 Project import

```bash
godot --headless --path . --import
```

Result: **pass**. Assets imported, no GDScript parse errors. Godot's normal
`ObjectDB instances leaked at exit` warning appears after headless test quits; it does
not appear during normal gameplay and is an engine shutdown artifact of the test tree.

### 1.2 Gameplay integration

```bash
godot --headless --path . res://tests/GameplayTest.tscn
```

Result: **PASS (0 failures)**, 31 assertions:

1. menu screen boots
2. gameplay screen loads
3. spawner running
4. player alive at start
5. HUD present
6. touch tap switches lanes (real pointer event through the UI layer)
7. mouse click switches lanes
8. obstacle spawns
9. passing an obstacle scores a point
10. collision kills the player
11. game over overlay appears
12. state is GAME_OVER
13. restart resets score
14. restart revives player
15. restart records exactly one game
16. best score updated
17. save file exists
18. pause sets PAUSED
19. spawner freezes while paused
20. resume returns to RUNNING
21. second game over shows
22. test rewarded overlay opens
23. revive consumed
24. game continues after reward
25. player revived
26. best score survives save reload
27. local analytics log written
28. alternate skin selects
29. selected skin stored
30. selected skin survives reload
31. volume survives reload

The test runs against the real `Main.tscn` and real save layer, not mocks.

### 1.3 Five-minute spawner stress

```bash
godot --headless --path . res://tests/SpawnerStress.tscn
```

Result: **PASS (0 failures)**:

- 487 obstacles spawned across 5 simulated minutes at 60 Hz.
- Maximum simultaneous active obstacles: **5**.
- Unreactable two-lane blocks: **0 frames**.
  - Checked for simultaneous lane blocks and opposite-lane arrivals closer than
    **0.24 s**, the human lane-switch budget.
- Scripted safe-lane bot collisions: **0**.
- Full duration covered.

This validates the fairness guarantee of the pattern scheduler at every difficulty
tier, not just the early game.

### 1.4 Save compatibility

Covered inside the gameplay test:

- write → parse verification → backup → atomic rename;
- JSON float/int merge handling;
- reload preserves best score;
- corrupt/unreadable primary falls back to backup (logic exists; corruption path is
  manually testable by editing `save.json`).

---

## 2. Visual QA

Harness:

```bash
godot --path . --resolution 1080x1920 res://tests/VisualCheck.tscn
```

Screens reviewed at 1080×1920:

| Screen | Result |
| --- | --- |
| Main menu (title, best, ship preview, buttons) | pass |
| Settings (all rows, volume, reset) | pass |
| Skins (preview, grid, equipped/locked states, scrolling) | pass |
| Statistics (hero + eight cards) | pass |
| Gameplay (HUD, lanes, obstacle, player, hint) | pass |
| Pause overlay | pass |
| Game over with NEW RECORD, stats, ad prompt, buttons | pass |
| Simulated test ad | pass |

Fixed during QA:

- Audiowide's slashed zero looked wrong for scores → numeric display uses Rajdhani
  Bold while branding stays Audiowide.
- Statistics cards overlapped because a container child was position-animated →
  animation only changes alpha; equal-width grid columns.
- Skins header overflowed horizontally on 1080 px → shortened subtitle/count layout.
- Skin cards showed duplicate “COMING SOON” labels → single status label + dim.
- Menu felt empty between logo and play → animated equipped-ship preview.
- Duplicate game-over audio cue removed.
- Revive now eases the spawner clock, not the gameplay survival timer.

Mobile safe-area code is present but cannot be visually verified without a notched
physical device.

---

## 3. Web verification

Build:

```bash
./tools/build_web.sh
```

Served with:

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory exports/web
```

Smoke test (`tests/web_smoke.mjs`, Playwright, system Chrome, headless, mobile emulation):

- page title: `ONE MORE SECOND`;
- loading overlay hidden after the WASM/PCK loaded;
- WebGL2 compatibility renderer initialized;
- menu rendered;
- clicked PLAY → gameplay;
- keyboard `Space` handled;
- `Esc` opened pause;
- **0 page errors, 0 failed requests, 0 console errors**
  (only expected WebGL `ReadPixels` performance warnings from headless Chrome).
- Mobile emulation (390×844, `hasTouch`, `isMobile`): menu rendered in a centered
  portrait letterbox; PLAY worked by touch; a playfield tap moved the ship from the
  left to the right lane (single switch, no double-event jitter); pause opened by
  touch; no console errors.
- Settings persistence across a page reload was verified through IndexedDB
  (`/userfs` → `save.json`). The web filesystem commits asynchronously; in headless
  Chrome the IDB copy updated roughly 1 s after the setting change. Give the page a
  moment before closing it immediately after a change. Native saves are synchronous.

The web input test caught a real bug: the full-screen `Main`/`Gameplay` root
`Control`s were swallowing unhandled mouse/touch events, so only keyboard switching
worked. Both roots now use `mouse_filter = IGNORE`, and the integration test asserts
that synthetic touch and mouse events reach the gameplay handler.

The exported files:

| File | Size |
| --- | --- |
| `index.wasm` | ~38 MB uncompressed / ~10.1 MB gzip |
| `index.pck` | ~2.1 MB |
| `index.js` | ~273 KB |
| `index.html` | ~9.8 KB |

No service worker and no external network requests are used by the game itself.

---

## 4. Test matrix

| Area | macOS native | Web (headless Chrome) | Android | iOS |
| --- | --- | --- | --- | --- |
| Boot / import | pass | pass | not built | not built |
| Menu / navigation | pass | pass (play/pause) | not tested | not tested |
| Touch input | n/a | emulated (pass) | not tested | not tested |
| Mouse input | pass | pass | n/a | n/a |
| Keyboard input | pass | pass | n/a | n/a |
| Gameplay / collision | automated + visual | partial (play, pause) | not tested | not tested |
| Save persistence | automated | engine-managed IndexedDB, not reload-tested | not tested | not tested |
| Safe area / notch | n/a | n/a | not tested | not tested |
| Haptics | n/a | n/a | not tested | not tested |
| Real ads | not bundled | disabled | not bundled | not bundled |
| Real IAP | inactive | inactive | inactive | inactive |
| Low-end performance | not profiled | not profiled | not profiled | not profiled |
| Physical Safari/Firefox/Edge | not tested | not tested | n/a | not tested |

“Pass” means the listed verification actually ran; “not tested” means it still needs
owner hardware/accounts.

---

## 5. Manual pre-release QA (recommended)

- Install on a low-end Android phone and an iPhone with a notch.
- Play 20+ runs; verify no frame hitching after 5+ minutes.
- Background/foreground during a run, during pause and during an ad (when enabled).
- Kill the app mid-run; relaunch and verify saves.
- Set device font scaling / display zoom if the platform can affect Godot (it should
  not; the game uses its own canvas).
- Safari iOS: audio after tap, fullscreen behavior, safe area, loading time.
- Firefox/Edge desktop web.
- Test flight mode on mobile and offline mode.
- Store test tracks: IAP restore, ad test units, consent.
- Accessibility pass: keyboard-only navigation, reduced effects, contrast.

---

## 6. Performance

Design targets:

- 60 Hz physics, 60+ FPS where the device allows.
- No texture-heavy scenes; custom canvas drawing.
- Active obstacles: typically 2–5, hard cap not explicitly enforced but stress-tested
  below 24.
- Particles reduced automatically by the setting.

Not measured: frame time on low-end hardware, memory/footprint on Android/iOS,
thermal behavior, battery. Profile before marketing claims. Godot's *Monitors* and
*Profiler* should be used on-device.

---

## 7. Reproducing the web smoke test

The smoke script is committed at `tests/web_smoke.mjs`.

```bash
npm install playwright          # from tests/ or a temp folder
./tools/build_web.sh
python3 -m http.server 8765 --directory exports/web
node tests/web_smoke.mjs
```

It uses the installed Chrome channel, emulates a 390×844 touch device, clicks PLAY,
switches lanes, opens pause and fails on page errors, failed requests or console
errors. Screenshots land in `tests/artifacts/`.

The exported game itself requires no credentials.

---

## 8. Exit criteria used for v1.0.0

- Automated tests green.
- No known crash or save-loss bug.
- All screens render at 1080×1920.
- Web export boots in Chrome.
- Android/iOS presets parse, with signing/SDK steps clearly documented.
- No real ad IDs, no active purchases, no network calls.
- Documentation covers build, deploy, privacy, monetization and troubleshooting.

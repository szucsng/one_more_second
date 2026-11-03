# Testing & Verification — v1.1.0

Test date: **2026-11-03**
Engine: **Godot 4.7.2 stable** (`ed1daf0bf`)
Platform: Apple Silicon macOS, Compatibility renderer.
Web browser: headless Chromium via Playwright (system Chrome), WebGL2, mobile
emulation.

This document separates what was actually executed from what still requires owner
hardware, accounts or store setup.

---

## 1. Automated tests

### 1.1 Project import

```bash
godot --headless --path . --import
```

Result: **pass**, no GDScript parse errors. The usual Godot headless shutdown warning
about lingering ObjectDB/resources appears after tests quit; it does not occur during
normal gameplay.

### 1.2 Gameplay integration — 51 assertions PASS

```bash
godot --headless --path . res://tests/GameplayTest.tscn
```

Result: **PASS (0 failures)**. Covers:

- menu/gameplay boot, real pointer input, HUD presence;
- first dodge = 1 point; combo starts and increments **exactly once** per obstacle;
- ten-dodge sequence produces the expected **17 points**:
  `1+1+1+1+2 + 2+2+2+2+3`;
- combo reaches 10, max combo tracks the peak, HUD combo chip is visible;
- collision resets combo; restart resets score/combo and records one run;
- perfect dodge is marked on a narrow switch, confirmed once on pass, awards exactly
  +2 + the normal obstacle points, never duplicates across repeated switches, and a
  repeated award call is blocked;
- a safe switch without danger does not award a perfect dodge;
- pause/resume preserves combo; death clears it; game over reports max combo;
- rewarded test ad revive works;
- save reload preserves best score, skin and volume;
- a completed challenge adds its reward to the run score exactly once, and a second
  event does not reward again;
- local analytics file exists.

The test isolates daily challenges (marks the current set complete) and restores the
player's original challenge snapshot afterwards.

### 1.3 Scoring / difficulty / catalog — 57 assertions PASS

```bash
godot --headless --path . res://tests/ScoringTest.tscn
```

Result: **PASS (0 failures)**. Covers:

- multiplier tiers 1/2/3/4/5 at the 0/5/10/20/30 boundaries, cap at ×5;
- ten-dodge score total, perfect-window ordering and speed-scaled distance;
- monotonic speed curve, configured speed ceiling and spawn-interval floor;
- gradual pattern unlocks (single → stagger → zigzag → gauntlet);
- recovery timing bounds;
- deterministic daily set generation, three unique types, rewards/descriptions,
  progress/ratio/is-met helpers.

### 1.4 Daily challenge persistence — 14 assertions PASS

```bash
godot --headless --path . res://tests/ChallengeTest.tscn
```

Result: **PASS (0 failures)**. Covers:

- three challenges load, clean progress;
- dodge challenge completes at its target and emits **one** reward;
- recording another event does not reward the completed challenge twice;
- completion persists through save reload;
- a stale date rolls to today, clears daily completion/progress and preserves the
  lifetime completed count;
- challenge progress values/ratios are exposed to the UI.

### 1.5 Five-minute spawner stress — 14 assertions PASS

```bash
godot --headless --path . res://tests/SpawnerStress.tscn
```

Result: **PASS (0 failures)** with seed `20261103`:

- 470 obstacles over 5 simulated minutes;
- six pattern types generated: single, stagger, zigzag, late switch, rush, gauntlet;
- four recovery sections;
- speed respects the 1500 ceiling;
- maximum simultaneous active obstacles: 4;
- zero unreactable two-lane blocks (0.24 s arrival-gap invariant);
- scripted safe-lane bot survives with zero collisions.

---

## 2. Visual QA

Harness:

```bash
godot --path . --resolution 1080x1920 res://tests/VisualCheck.tscn
```

Screens reviewed at 1080×1920:

| Screen | Result |
| --- | --- |
| Main menu with DAILY badge / three nav buttons | pass |
| Settings | pass |
| Skins | pass |
| Statistics (10 cards incl. best combo/perfects) | pass |
| Daily challenges (summary, 3 cards, progress bars, rewards) | pass |
| Gameplay HUD (score, top fade, combo chip/bar, daily progress, perfect callout) | pass |
| Pause | pass |
| Game over (4-stat row: best, survived, max combo, perfects) | pass |
| Simulated test ad | pass |

Design fixes/checks during this update:

- added a 430 px top readability fade so falling obstacles cannot obscure the score;
- made the combo chip opaque enough to stay readable over bright obstacles;
- verified combo milestone, perfect callout and daily-toast layering does not overlap;
- verified 4-column game-over stats fit at 920 px panel width;
- verified statistics still fit after adding two cards.

Mobile safe-area code remains present but physical notched-device verification is
still required.

---

## 3. Web verification — v1.1.0

Build:

```bash
./tools/build_web.sh
```

Output sizes:

| File | Size |
| --- | --- |
| `index.wasm` | ~38 MB raw / ~10.1 MB gzip |
| `index.pck` | ~2.2 MB |
| `index.js` | ~273 KB |
| itch.io ZIP | ~12 MB |

Smoke test (`tests/web_smoke.mjs`, Playwright, system Chrome, 390×844 touch
emulation):

- page title loaded;
- loading overlay disappeared after WASM/PCK load;
- WebGL2 Compatibility renderer initialized;
- menu rendered;
- touch PLAY started gameplay;
- playfield tap switched lane;
- pause opened;
- **0 page errors, 0 failed requests, 0 console errors**.

The 1.1.0 code (combo HUD, daily challenges screen/menu button, new HUD layers,
challenge autoload) is included in this exported build.

---

## 4. Test matrix

| Area | macOS native | Web (headless Chrome) | Android | iOS |
| --- | --- | --- | --- | --- |
| Boot / import | pass | pass | not built | not built |
| Menu / navigation | pass | pass (play/pause) | not tested | not tested |
| Touch input | synthetic pass | emulated pass | not tested | not tested |
| Mouse input | pass | pass | n/a | n/a |
| Keyboard input | pass | pass | n/a | n/a |
| Combo scoring | automated | code in build, not interacted to combo | not tested | not tested |
| Perfect dodge | automated | code in build | not tested | not tested |
| Daily challenges | automated + visual | screen included; not clicked through | not tested | not tested |
| Save persistence | automated | IndexedDB verified in 1.0 flow | not tested | not tested |
| Safe area / notch | n/a | n/a | not tested | not tested |
| Haptics | n/a | n/a | not tested | not tested |
| Real ads / IAP | not bundled | disabled | not bundled | not bundled |
| Low-end performance | not profiled | not profiled | not profiled | not profiled |

“Pass” means the listed verification actually ran; “not tested” still requires owner
hardware/accounts.

---

## 5. Manual pre-release QA (recommended)

- Play 20+ runs; verify combo milestones at 5/10/20/30 and score consistency.
- Intentionally switch late into an obstacle: no perfect reward should be granted.
- Play on a low-end Android phone and a notched iPhone.
- Background/foreground during a run, pause and ad (when enabled).
- Kill the app mid-run; relaunch and verify stats/save.
- Cross midnight or change the date to verify daily rollover and no duplicate rewards.
- Safari iOS, Firefox and Edge desktop.
- Offline mobile play; store test tracks for future IAP/ads.
- Accessibility: keyboard-only navigation, reduced effects (screen shake must be off).

---

## 6. Performance

Design targets remain 60 Hz physics / 60+ FPS where hardware allows.

New per-frame costs:

- one cached gradient texture behind the top HUD;
- one combo progress bar and a handful of labels;
- perfect detection runs only on lane switches and scans the active obstacle set
  (typically 2–5 objects);
- challenge updates occur per dodge / per second, not per frame.

No new textures, node-per-particle effects or allocations per frame were introduced.
Not measured on physical devices; profile before store claims.

---

## 7. Reproducing the web smoke test

```bash
npm install playwright
./tools/build_web.sh
python3 -m http.server 8765 --directory exports/web
node tests/web_smoke.mjs
```

Requires Google Chrome installed. Screenshots go to `tests/artifacts/`.

---

## 8. Known gaps

- Android APK/AAB and iOS builds still require SDK/Xcode/team setup; not compiled here.
- Real AdMob and IAP remain inactive.
- Physical touch devices, notches, Safari/Firefox/Edge and low-end FPS are not verified.
- Daily challenge score bonuses intentionally change the score economy; old best
  scores remain valid but are easier to beat.
- Web save commits to IndexedDB asynchronously (~1 s after a change in headless
  Chrome); avoid closing the tab instantly after a save.

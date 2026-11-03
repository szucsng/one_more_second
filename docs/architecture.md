# Architecture

## 1. Goals

ONE MORE SECOND is a small game with a deliberately production-shaped skeleton:

- instant boot, one-input gameplay, no loading between runs;
- no scene-tree global pause side effects;
- deterministic, testable difficulty;
- a save layer that survives crashes and engine upgrades;
- platform-specific code isolated from gameplay;
- monetization and analytics expressed as interfaces, not hard dependencies;
- no backend, no network calls, no paid services in v1.

Godot 4.7.2 · GDScript · Compatibility renderer · 1080×1920 portrait canvas.

---

## 2. Boot flow

```
project.godot
└─ autoloads (in order)
   Platform → SaveManager → Analytics → AudioManager → SkinManager
            → Challenges → AdsManager → Monetization → SceneRouter
└─ main scene: scenes/main/Main.tscn
   └─ Main.gd
      ├─ DisplayServer.window_set_title()
      ├─ SceneRouter.attach(ScreenContainer)
      ├─ Platform.apply_saved_display_settings()
      └─ SceneRouter.change_screen(Menu, animate = false)
```

Autoload order matters:

- `Platform` has no dependencies.
- `SaveManager` must load settings before Analytics/Audio/Skin read them.
- `Analytics` reads the persisted analytics switch and logs `session_started`.
- `AudioManager` connects to `SaveManager.settings_changed`.
- `SkinManager` reads/writes the selected skin through `SaveManager`.
- `Challenges` generates/loads the local daily set after the save is available and
  persists progress through `SaveManager`.
- `AdsManager` reads policy config and uses `Platform.is_web`.
- `SceneRouter` is last because it may reference analytics on screen changes.

`SceneRouter` adds a CanvasLayer (layer 1000) with a black fade `ColorRect`. Scene
switches are short async fades (140 ms in, 200 ms out) and block input while fading.
It owns exactly one current screen. Pause, game-over and ad UI are overlays inside
the gameplay screen, not routed screens.

---

## 3. Scene graph

### Main

```
Main (Control)
├─ Backdrop (ColorRect, clear color)
└─ ScreenContainer (Control)
   └─ current screen (Menu / Gameplay / Settings / Skins / Statistics)
```

### Gameplay

```
Gameplay (Control)  ← gameplay.gd state machine
├─ Backdrop (NeonBackdrop, moves faster with difficulty)
├─ World (Node2D)   ← screen shake offset
│  ├─ Obstacles (Node2D)
│  ├─ Spawner (ObstacleSpawner)
│  ├─ Player (PlayerShip + Trail)
│  └─ Effects (ParticleFX)
├─ HUDLayer (CanvasLayer 10)
│  └─ HUD (score, best, pause, tutorial)
└─ OverlayLayer (CanvasLayer 20)
   ├─ PausePanel
   └─ GameOver
```

The test ad overlay is a CanvasLayer 120 owned by the `Ads` autoload, so it renders
above gameplay and remains responsive even when the game state machine is frozen.

---

## 4. Gameplay state machine

`scripts/gameplay/gameplay.gd` defines:

```text
RUNNING ──pause──▶ PAUSED ──resume──▶ RUNNING
   │                  └──restart/menu──▶ finalize + new run / menu
   ├──collision──▶ DYING ──0.6 s──▶ GAME_OVER
   │                                  ├──restart──▶ finalize + new run
   │                                  ├──menu─────▶ finalize + menu
   │                                  └──continue─▶ AD ──reward──▶ RUNNING (revived)
   │                                                     └──dismiss──▶ GAME_OVER
   └──app close──▶ finalize(abandoned)
```

Key decisions:

- **No `get_tree().paused`.** The state machine freezes spawner/player explicitly.
  Autoloads and the ad overlay keep processing.
- **Timer is gameplay-owned.** `elapsed` advances only in `RUNNING`; pause and ad
  time do not inflate stats.
- **Run finalization is guarded.** `_run_finalized` ensures exactly one save and one
  `game_over` analytics event per run, no matter which exit path fires.
- **Revive does not end the run.** The score and timer continue; at most one revive is
  available per run (`REVIVED_RUNS_LIMIT = 1`). The spawner is cleared and the player
  receives 2.2 s of invulnerability.
- **Game over is not recorded immediately on death.** The player may watch the optional
  ad and continue. The run is finalized when they restart, return to the menu, close
  the app, or otherwise leave the loop.
- **Focus loss auto-pauses.** On mobile, backgrounding the app while running opens the
  pause panel instead of letting the run continue unseen.
- **Android back** pauses/resumes during play and opens the menu from game over;
  other screens return to the menu. The menu exits the app.
- **Combo** is owned by gameplay, incremented exactly once per passed obstacle,
  reset on collision and on every restart. Pause preserves it.
- **Perfect-dodge candidates** are marked on a lane switch but confirmed only when
  the obstacle passes, so a fatal late switch cannot earn the bonus.
- **Daily challenge progress** updates from dodge/perfect/combo/score/survival
  events and is persisted through the existing save document.

### Scoring and combo

`scripts/core/scoring.gd` is the pure score authority:

| Combo | Multiplier | Points per dodge |
| --- | --- | --- |
| 0–4 | ×1 | 1 |
| 5–9 | ×2 | 2 |
| 10–19 | ×3 | 3 |
| 20–29 | ×4 | 4 |
| 30+ | ×5 | 5 |

- `Obstacle` emits `passed` once; gameplay increments combo exactly once and adds
  `Scoring.obstacle_points(combo)`.
- Ten consecutive dodges therefore total 17 points.
- Milestones at 5/10/20/30 trigger HUD feedback, particles and a dedicated sound.
- Combo resets on collision and restart; `max_combo` is retained for the run report.
- Perfect dodge adds a flat `+2` (`Scoring.PERFECT_BONUS`) in addition to the normal
  dodge points, but never adds extra combo from the same obstacle.
- Challenge score rewards are added to the run score; they are once-per-day and
  marked complete before the reward signal is emitted.
- Score is saved only at run finalization, so best score/statistics remain consistent
  with the existing system and guard against double finalization.

### Perfect dodge

- Config: `Scoring.PERFECT_MIN_TIME = 0.10`, `Scoring.PERFECT_WINDOW = 0.28`.
- On a lane switch, gameplay scans active obstacles in the lane being left.
  A candidate must have a time-to-impact between 0.10 and 0.28 s and the new lane
  must be free of an obstacle within that window + 80 ms.
- The candidate is marked `perfect_pending`; the reward is confirmed only when it
  passes (`Obstacle.passed`) while the run is alive. A switch that ends in a
  collision never rewards.
- `perfect_awarded` prevents duplicate rewards even if the player switches back and
  forth. A single switch can mark at most the nearest qualifying obstacle.
- Detection is position/time based, so it is frame-rate independent and scales with
  obstacle speed. It never asks for a sub-frame input.
- Feedback: +2 score, HUD callout, cyan/gold ring and sparks, procedural SFX,
  haptic pulse, screen shake (skipped by reduced effects), challenge progress.

### Collision

- Player: `Area2D`, collision layer 1, mask 2, box **58×82**.
- Obstacle: `Area2D`, collision layer 2, mask 1, box **262×78** (visual is 292×92).
- Player monitors `area_entered`; obstacles are monitorable but do not monitor.
- The smaller obstacle collision box makes near misses feel intentional.

---

## 5. Difficulty and fairness

`scripts/core/difficulty.gd` is pure:

- speed: `620 → 1500` over 105 s with an ease-out curve (hard ceiling);
- interval: `1.05 s → 0.55 s` over 95 s with a ±4.5% cadence wave;
- minimum reaction time: **0.24 s** (`MIN_REACTION_TIME`);
- pattern unlocks (central `PATTERN_UNLOCKS`):
  single 0 s, stagger 8 s, zigzag 22 s, late switch 32 s, rush 42 s, gauntlet 74 s;
- recovery sections at 20/48/78/112 s, each **2.3 s** long.

`ObstacleSpawner` rules:

1. Every pattern item has an explicit delay (0.52–2.08 s), so lane decisions are
   spaced in **time**, not pixels.
2. A new pattern starts only after all items from the previous pattern have spawned,
   plus the current spawn interval plus the last item's delay. This prevents pattern
   overlap even at maximum speed.
3. Same-lane guard: if an existing obstacle in that lane is within `speed × 0.36` of
   the spawn point, the item is retried 0.14 s later (up to 10 attempts).
4. One lane per obstacle/pattern item; a safe lane always exists. No pattern blocks
   both lanes simultaneously.
5. `single` dominates early; advanced patterns unlock gradually and carry lower
   weights. Repeating the previous pattern multiplies its weight by 0.25.
6. Recovery sections create intentional breathing room; they are inserted only when
   the pending pattern queue is empty.
7. RNG is seeded (`start(seed)`), enabling deterministic tests and future replay.
   Visual variants (normal/pulse/heavy) remain cosmetic.

The automated stress test runs five simulated minutes at 60 Hz with a fixed seed,
checks that no two lanes are blocked inside the 0.24 s reaction window, verifies
same-lane spacing, confirms all six patterns and four recovery sections appear, and
drives a scripted safe-lane bot through 470 obstacles without collision.

---

## 6. Save system

`SaveManager` (autoload) owns a single JSON document:

```json
{
  "version": 2,
  "best_score": 0,
  "stats": {
    "games_played": 0,
    "total_score": 0,
    "best_survival_time": 0.0,
    "total_play_time": 0.0,
    "obstacles_avoided": 0,
    "revives_used": 0,
    "best_combo": 0,
    "perfect_dodges": 0
  },
  "settings": {
    "sfx": true,
    "music": true,
    "vibration": true,
    "volume": 0.8,
    "reduced_effects": false,
    "analytics": true,
    "fullscreen": false
  },
  "skins": {
    "selected": "default",
    "unlocked": ["default", "cyan", "purple", "pink", "gold"]
  },
  "ads": {
    "rewarded_views": 0,
    "interstitial_views": 0,
    "last_interstitial_unix": 0,
    "runs_since_interstitial": 0
  },
  "flags": {"onboarding_seen": false},
  "challenges": {
    "date": "2026-11-03",
    "set": [ /* three generated challenge definitions */ ],
    "progress": {
      "dodges": 0, "perfects": 0, "max_combo": 0,
      "best_score": 0, "best_survival": 0.0
    },
    "completed": [],
    "total_completed": 0
  }
}
```

Paths:

- main: `user://save.json`
- backup: `user://save.bak.json`
- atomic temp: `user://save.tmp`

Write sequence:

1. stringify with indentation;
2. write `save.tmp`, flush, close;
3. read it back and parse to verify;
4. copy the current save to `save.bak.json`;
5. rename temp over the live file;
6. fallback to a direct write if the platform cannot rename atomically.

Load sequence:

1. start from defaults;
2. read the live file; if unreadable, try the backup;
3. recursively merge, accepting int↔float JSON differences;
4. sanitize/clamp every value and ensure the selected skin exists;
5. write a default file on a fresh install.

Signals:

- `settings_changed` → audio, backdrop, HUD focus, menu label;
- `progress_changed` → menu best score;
- `skin_changed` → equipped skin updates.

The save is written synchronously on important transitions and on close/pause
notifications. Challenge progress is updated in memory and saved on challenge
completion and run finalization/close. Version 1 saves are merged forward safely:
missing fields take defaults and JSON number type differences are normalized.
There is no background thread and no network.

---

## 7. Skins

`SkinManager` is the catalog and selection API:

```
id, name, tagline, primary, secondary, accent, trail, free, coming_soon, store_price
```

- Five free skins are always selectable and have no gameplay effect.
- Three premium skins are catalogued but `coming_soon = true`; their cards are
  disabled and clearly labelled. No purchase flow is exposed.
- `PlayerShip` and `SkinPreview` use the shared `ShipRenderer` so the silhouette is
  identical in gameplay, menu and skin cards.
- The menu shows an animated preview of the equipped skin.
- Selection triggers `skin_selected` analytics and a save write.

Adding a skin: append a definition in `SkinManager._skins`; it appears automatically
in the gallery. A premium unlock will eventually call `SaveManager.unlock_skin(id)`
after a validated store transaction.

---

## 8. Daily challenges

`ChallengeManager` (autoload) implements a local-only daily system.

- The date string (`YYYY-MM-DD`, local time) seeds `ChallengeCatalog.generate()`.
- The set is always three challenges:
  1. cumulative dodges;
  2. cumulative perfect dodges;
  3. one rotating challenge: max combo, best single-run score, or best single-run
     survival.
- Targets/rewards are deterministic for the date; the generated set is stored in the
  save so a mid-day code update cannot silently change the challenge.
- Progress fields are updated from gameplay events:
  - every dodge → dodges + combo/score checks;
  - every confirmed perfect dodge → perfects + score;
  - each whole second → best survival;
  - every score change → best score.
- On completion the manager **marks and saves completion before emitting**
  `challenge_completed`; gameplay then adds the reward to the run score. Reloading or
  replaying the event cannot grant the reward twice.
- At local midnight (detected on the next menu/gameplay/challenge load) the set and
  daily progress reset; the lifetime `total_completed` count is preserved.
- No account, network, paid item or backend is involved. Rewards are score bonuses,
  not pay-to-win.

UI: dedicated Daily screen (three progress cards/rewards), menu DAILY n/3 button, HUD
daily chip and completion toast.

---

## 9. Audio

`AudioManager` creates `Music` and `SFX` buses at runtime and routes them to Master.

- Master volume: settings slider (linear → dB, mute below 0.1%).
- SFX mute: settings; music mute: independent.
- Music bed: one looping OGG (`assets/music/neon_drive.ogg`).
- SFX: a pool of 10 non-positional `AudioStreamPlayer`s with ±3% pitch variation.
- Web autoplay: music is started at ready and retried on the first input event;
  browsers require a user gesture.
- All audio is generated by `tools/generate_audio.py` (no samples, no copyrighted
  music).

---

## 10. Platform layer

`systems/platform/platform.gd` centralizes every OS-specific call:

| API | Desktop | Web | Android | iOS |
| --- | --- | --- | --- | --- |
| `vibrate()` | no-op | no-op | `Input.vibrate_handheld` | `Input.vibrate_handheld` |
| `open_url()` | `OS.shell_open` | `JavaScriptBridge.eval(window.open)` | shell | shell |
| `set_fullscreen()` | window mode | Fullscreen API | configured in export | configured in export |
| safe-area insets | zero | zero | display safe area | display safe area |
| platform name | macos/windows/linux | web | android | ios |

JavaScript access uses `Engine.get_singleton("JavaScriptBridge")` so desktop builds
never reference a web-only singleton directly.

Safe-area insets are converted into the 1080×1920 design space and applied to menu
and screen margins plus the gameplay HUD. This keeps headers/buttons away from
notches and the Dynamic Island on phones that report a safe area.

---

## 11. Ads abstraction

```
Gameplay / GameOver
   │
AdsManager (autoload: policy, timeouts, duplicate reward guard, analytics)
   │
AdProvider (Node contract)
   ├── MockAdProvider          debug/test only, local overlay
   ├── WebH5AdProvider         AdSense H5 Games Ads
   ├── NativeAdMobProvider     prepared native stub, fails closed
   └── UnavailableAdProvider   explicit no-provider result
```

Public manager signals:

`ad_loaded`, `ad_shown`, `ad_closed`, `ad_failed`, `rewarded_ready_changed`,
`rewarded_granted`, `rewarded_dismissed`, `interstitial_finished`.

Public capability API:

`can_show_rewarded_ad()`, `show_rewarded_ad()`, `prepare_rewarded_ad()`,
`can_show_interstitial()`, `show_interstitial()`, `cancel_rewarded_prompt()`,
`uses_dom_reward_prompt()`.

### Provider selection

- Production disabled (`AdConfig.PRODUCTION_ADS_ENABLED = false`) → unavailable
  provider on web/release; mock provider only in debug desktop/native builds.
- Production enabled + web → `WebH5AdProvider`.
- Production enabled + Android/iOS → `NativeAdMobProvider` stub (no plugin bundled).
- Production enabled + desktop → unavailable.
- `ALLOW_MOCK_ON_WEB` is false; fake ads never ship on web.

### Rewarded flow

1. Game over calls `prepare_rewarded_ad()`.
2. Web: `web/ads-bridge.js` invokes the official `adBreak({type: "reward"})`.
3. The API calls `beforeReward(showAdFn)` only when an ad is actually available.
4. The bridge shows a DOM reward prompt. Its watch button calls `showAdFn()` directly
   from the browser click, preserving the user gesture required by Google.
5. Lifecycle: `beforeAd` → shown, `adViewed` → reward earned, `adDismissed` → no
   reward, `afterAd` → closed, `adBreakDone` → always.
6. `AdsManager` grants only after a provider-confirmed reward and close. A
   `_reward_granted_this_attempt` guard blocks duplicate callbacks.
7. `Gameplay.revive_used` is the final one-revive-per-run guard.
8. Any failure/no fill/timeout leaves Restart and Menu available.

The mock provider uses `TestAdOverlay.tscn`; it is clearly labelled as a simulation
and is restricted to debug builds. The native provider is a deliberate fail-closed
stub until a maintained AdMob plugin is installed and tested.

### Web bridge

- `web/ads-config.js` is public, non-secret configuration: enabled switch, AdSense
  publisher ID, test mode, consent state, frequency hint, optional interstitial flag.
- `web/ads-bridge.js` owns all Google JavaScript, dynamic AdSense tag injection,
  consent/host gating, the Ad Placement callbacks and the DOM prompt.
- With default config it does not load Google's script and makes no ad requests.
- `web/shell.html` includes the bridge/config scripts; `tools/build_web.sh` copies
  them and the prompt font into the export. The GitHub Pages workflow does the same.
- The bridge exposes a single `OMSAdsBridge` interface to Godot through
  `JavaScriptBridge`; provider-specific JavaScript never enters gameplay scripts.

### Interstitial policy

- `AdConfig.INTERSTITIAL_ENABLED` + web config `interstitialEnabled`; both default
  false.
- Policy: at least 3 completed runs and 150 s since the last impression.
- Requested only from the explicit Restart action at game over, never during play,
  pause, a reward prompt or another ad.
- If unavailable/failing/timing out, the next run starts immediately.
- Ads are counted only when the provider actually calls `beforeAd`/shown.

Banners remain unimplemented and disabled. Production enablement requirements are
documented in [monetization.md](monetization.md).

---

## 12. Analytics

`Analytics` (autoload) validates against an allow-list and writes JSONL:

```
user://analytics/events-YYYY-MM-DD.jsonl
```

Each line:

```json
{"name":"game_over","session":"4f1c…","unix":1780000000.0,"data":{"score":12,"duration":31.4,"new_record":true}}
```

- `session_id` is a random 12-hex string generated per launch; it is not a device or
  advertising identifier.
- Rotation at 512 KB to `.1.jsonl` for the current date.
- `enabled` is loaded from settings before any event is written.
- Unknown event names are ignored in release builds (warning in debug).
- `analytics_toggled`, `settings_changed`, `screen_view` and lifecycle events are
  included in addition to the product events.
- `_exit_tree` writes `session_ended` once if possible.

No upload code exists. A future adapter would replace `_write_event` and must add
consent/opt-out and a privacy policy first.

Events used by the game:

`session_started`, `session_ended`, `game_started`, `game_over`, `score_reached`,
`new_record`, `skin_selected`, `rewarded_ad_requested`, `rewarded_ad_completed`,
`rewarded_ad_failed`, `revive_used`, `analytics_toggled`, `settings_changed`,
`screen_view`, `interstitial_shown`, `combo_milestone`, `perfect_dodge`,
`challenge_completed`.

---

## 13. Store abstraction

`Monetization` (autoload) catalogs future products:

| Product | Type | Planned price |
| --- | --- | --- |
| Aurora skin | skin | €0.99 |
| Solar Flare skin | skin | €0.99 |
| Voidwalker skin | skin | €0.99 |
| Neon Pack (all three) | pack | €1.99 |
| Remove Ads | no_ads | €1.99 |

`store_available = false`; `purchase()` returns `false` and emits `purchase_failed`
with `store_unavailable`. No UI calls it. The skins screen labels premium content
“COMING SOON”. Localized prices must come from the store, not these strings.

See [monetization.md](monetization.md) for activation.

---

## 14. UI architecture

- A single generated `Theme` (`assets/theme/ui_theme.tres`) is registered as the
  project theme, so every control inherits the design system.
- Type variations: `TitleLabel`, `HeadingLabel`, `KickerLabel`, `ScoreLabel`,
  `ValueLabel`, `GoldLabel`, `BadgeLabel`, `PrimaryButton`, `GhostButton`,
  `IconButton`, `ToggleButton`, `SkinCard`, `DangerButton`, `CardPanel`, `RowPanel`,
  `ChipPanel`, `HudPanel`.
- `tools/build_theme.gd` regenerates the theme from `Palette` + font files. It is the
  source of truth; edit the tool and re-run, do not hand-edit the generated `.tres`.
- `NeonButton` adds hover/press scaling and the UI tap sound; styling stays in the theme.
- `ToggleRow` is the single ON/OFF pill used in settings.
- `NeonBackdrop` is pure canvas drawing plus two cached gradient textures:
  - animated 90×150 grid;
  - drifting particles;
  - top/bottom neon glows;
  - lane guides during play;
  - cached vignette;
  - reduced-effects mode halves particle count and removes the scanline.
- `ShipRenderer` draws the ship shape, glow layers, shield and fins. It is used by the
  player, menu preview and skin cards.
- `ParticleFX` is a custom canvas particle system with additive blending; it avoids
  node-per-particle overhead on mobile.
- The HUD adds a cached top gradient for readability, combo chip/progress, daily chip,
  combo-milestone/perfect/challenge/recovery callouts. All callouts are tweened and
  reset between runs.
- The Daily screen builds three cards from ChallengeManager data; it does not own a
  second save system.

All screens support keyboard focus. Android back and `Esc` are handled per screen.

---

## 15. Extension points

### Global leaderboard

Daily challenges are already local; a global leaderboard would still need a server.
Do not trust client scores. Recommended shape:

1. a server endpoint validates the run (signed session nonce, monotonic timestamps,
   score bounds, pattern seed replay if feasible);
2. score submission is idempotent and rate-limited;
3. the client treats the leaderboard as read-only decoration if offline;
4. no personal data beyond an anonymous, rotating player id;
5. privacy policy and consent are updated before shipping.

`Analytics`/`Ads`/`Monetization` show the adapter pattern to follow. No backend is
implemented now.

### Cloud save

Keep `user://save.json` as the offline source of truth. Add a cloud adapter with
last-write-wins + conflict resolution for stats; never block local play on network.

### More skins / trails

Add definitions to `SkinManager`; trails are just a color in the current renderer.
A future trail-effect system can extend the definition dictionary with an effect id.

### Real ads / purchases

Implement the provider interfaces described in [monetization.md](monetization.md),
then switch flags. Never fake a transaction and never auto-show an interstitial.

---

## 16. Performance notes

- Fixed 60 Hz physics; no dynamic physics simulation beyond Area2D overlap checks.
- Custom drawing avoids per-frame allocations in most paths. `Obstacle._draw` creates
  no nodes; StyleBoxes are created once in `_ready`.
- Particle count is capped and reduced on demand.
- The spawner keeps only the active obstacles and pending pattern items.
- Combo/perfect detection scans only the small active obstacle set, on input events.
- Daily progress writes update the in-memory save; challenge completion triggers an
  immediate disk save. Per-second survival updates do not write the file.
- The world shake offsets the entire world node rather than every object; REDUCE
  EFFECTS disables all shake.
- Save/analytics files are tiny; analytics writes are line-buffered.
- Web: Compatibility renderer, no threads, no GDExtension. Initial wasm is large by
  nature of Godot; compression is a hosting concern.
- Mobile: portrait, low draw-call count, no textures beyond icons/splash/fonts and
  the cached gradients.

For profiling, use Godot's *Debugger → Monitors* and *Profiler* on a device; the
visual harness/QA matrix is documented in [testing.md](testing.md).

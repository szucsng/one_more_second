# Changelog

All notable changes to ONE MORE SECOND are documented here.
Format follows the spirit of Keep a Changelog; versions follow semantic versioning.

## [1.2.0] — 2026-11-03

### Added

- **Web ad integration (disabled by default):** isolated Google AdSense H5 Games
  Ads bridge (`web/ads-bridge.js`) using the official Ad Placement API
  (`adBreak`/`adConfig`), a public non-secret `web/ads-config.js`, consent/host/
  publisher-ID gating, test-mode support, and build/CI copying of the web assets.
- **Provider architecture:** `AdProvider` lifecycle contract, `AdsManager` mediation,
  `MockAdProvider`, `WebH5AdProvider`, fail-closed `NativeAdMobProvider` stub,
  `UnavailableAdProvider`, and pure `AdPolicy` frequency rules.
- **Rewarded UX:** provider-confirmed revive, styled DOM reward prompt for web
  (preserves the browser user gesture), loading/unavailable/dismissed/failure states,
  duplicate reward-callback guard, one revive per run, and restart/menu always
  available.
- **Interstitials:** natural-break restart flow, minimum 3 runs / 150 s cooldown,
  no gameplay interruption, automatic restart after no-fill/failure/timeout; disabled
  by default.
- **Ads tests:** provider unavailable, load/display failure, ready/close timeout,
  duplicate rewards, dismissed/no reward, interstitial policy/impression counting,
  web ad-free verification, and mocked-provider web integration.
- Web font subset for the loading shell and reward prompt; build script and GitHub
  Pages workflow copy it with the ad bridge/config.
- Production safety switches and owner setup/approval documentation for AdSense H5,
  native AdMob, consent/CMP, privacy and deployment.

### Changed

- Version 1.2.0; Android version code 3; iOS build 3.
- Mock ads are now debug-builds only; release builds never display simulated ads.
- Rewarded reward is not granted until the provider confirms completion and the ad
  closes.
- Game-over results (best score and run stats) are persisted immediately on death,
  because the app can be swiped away from the result screen. A successful revive
  rolls the provisional record back so a revived run is counted once when it ends.
- Interstitial stats are recorded only when an ad is actually shown.
- README, architecture, monetization, privacy, web deployment, testing and release
  checklist updated.

### Preserved

- Default builds remain free, offline-capable and ad-free; no real IDs, secrets, live
  ads, purchases or external services are enabled by default.
- Existing save data, skins, challenges, scoring, settings and platform behavior.

## [1.1.0] — 2026-11-03

### Added

- **Combo system:** consecutive dodges build a multiplier at 5/10/20/30
  (×1→×5), with a HUD combo chip, progress bar, milestone flash, particles and
  procedural milestone SFX. Combo resets on collision and restart.
- **Perfect Dodge:** a lane switch within a configurable 0.10–0.28 s impact window
  marks the narrowly avoided obstacle; the +2 bonus, HUD callout, ring/sparks and
  sound are confirmed only after the obstacle passes, so late switches that end in
  a collision never earn the reward. One reward per obstacle.
- **Seeded obstacle patterns:** deterministic RNG, a `pattern_spawned` signal,
  repeat-damped pattern selection, new `late_switch` and `gauntlet` patterns, and
  gradual unlocks (single → stagger → zigzag → late switch → rush → gauntlet).
- **Recovery pacing:** four configured breathing sections during a long run, with a
  HUD RECOVERY callout, plus a mild spawn-interval wave.
- **Daily challenges:** three locally generated, date-seeded challenges per day
  (dodges, perfect dodges, plus combo/score/survival), cumulative daily progress,
  date rollover, score-bonus rewards, a new Daily screen, menu badge, HUD daily chip
  and completion toast. Persisted through the existing SaveManager; no account,
  network or backend.
- **Run breakdown:** game-over screen now shows MAX COMBO and PERFECT dodges.
- **Statistics:** best combo, perfect dodges and now-correct obstacles-avoided
  counters, plus new procedural reward SFX.
- **Seeded/spawner tests:** pattern variety and recovery coverage in the five-minute
  fairness simulation.

### Changed

- Version 1.1.0, Android version code 2, iOS build 2.
- Rank thresholds adjusted for the new multiplier-based score scale.
- Screen shake is now fully disabled by the existing REDUCE EFFECTS setting.
- HUD gained a top readability fade so obstacles never obscure the score.

### Preserved

- No real ads, purchases, external services, identifiers or network calls.
- Free skins, local save compatibility, settings, platform abstractions and web
  ad-free policy.
- Existing 1.0.0 saves are upgraded by merge (new fields default safely).

## [1.0.0] — 2026-11-03

### Added

- Complete two-lane reflex arcade loop with tap / mouse / keyboard input.
- Pattern-based obstacle spawner with difficulty ramp, same-lane spacing guard,
  visual variants and a five-minute fairness test.
- Animated neon presentation: dark tech grid, drifting particles, vignette, cached
  glows, tapered ship trail, lane sparks, hit burst, screen shake and shield.
- Main menu with animated equipped-skin preview, best score, play, skins, statistics,
  settings and a global sound toggle.
- Skins gallery: Default Neon, Pure Cyan, Violet Shift, Hot Signal, Gold Rush.
  Three premium skins are catalogued as inactive “coming soon” entries.
- Settings: SFX, music, master volume, vibration (mobile), reduced effects,
  fullscreen (web/desktop), local analytics, two-step progress reset.
- Statistics screen: personal best, runs, total score, best/total survival time,
  obstacles avoided, revives, average score and rank.
- Pause, restart, menu flow; game-over screen with score count-up, rank, new-record
  celebration, best/survival stats, optional rewarded continue, restart and menu.
- Simulated, clearly labelled rewarded test ad with a five-second timer, claim step and
  always-available close; one revive per run with invulnerability and spawner cleanup.
- Local save system with validation, backup rotation, atomic replace and JSON
  int/float migration.
- Privacy-first local analytics (JSONL, 512 KB rotation) with an allow-list, on/off
  setting and lifecycle events.
- Ad provider abstraction, frequency policy hooks, inactive interstitial/banner
  configuration and Google test IDs for a future adapter.
- Inactive store abstraction with planned skins/pack/remove-ads products.
- Optional support link (hidden until configured).
- Platform layer: desktop/web/Android/iOS detection, fullscreen, URL opening, haptics
  and safe-area insets in the design space.
- Custom responsive web shell with loading progress, failure handling, fullscreen
  button, no external requests and a branded loading screen.
- Export presets for Web, Android (portrait, adaptive icons, immersive) and iOS
  (portrait, icon set, signing placeholders).
- Generated original audio: seven SFX and a 19.2 s synthwave loop.
- Generated icon/splash set for all platforms.
- Generated UI theme and design system.
- Headless gameplay integration test, five-minute spawner stress test and a visual
  screenshot harness.
- GitHub Actions workflow for web export + GitHub Pages deployment, plus an itch.io
  ready ZIP script.
- Full documentation: architecture, development, web deployment, Android, iOS,
  monetization, privacy, testing, troubleshooting and release checklist.

### Fixed during development / QA

- Save merge no longer discards JSON integer values due to float parsing.
- Spawner pattern overlap eliminated by scheduling the next pattern after the previous
  pattern's last item.
- Statistics cards no longer overlap (container-safe animation).
- Skin screen header no longer overflows at 1080 px.
- Numeric labels use Rajdhani to avoid Audiowide's slashed zero.
- Removed duplicate game-over sound cue.
- Revive no longer reduces the recorded survival time.
- Obstacle pass signal argument binding fixed.
- Full-screen root Controls swallowed mouse/touch input; gameplay now receives taps
  (touch debounce prevents emulated mouse double-switching).
- Web ad prompt hidden by design.

### Security / privacy

- No network requests, trackers, real ad IDs or payment processing in v1.
- No secrets or signing material committed.
- Real store/ad activation requires owner-supplied credentials and updated policies.

### Known issues

- Android/iOS builds are documented but **not compiled or device-tested** in this
  environment.
- Real AdMob and in-app purchases are inactive.
- Web wasm is large (~38 MB raw, ~10 MB gzip).
- Physical Safari/Firefox/Edge and low-end phone performance are not verified.
- The Godot headless test runner emits an engine shutdown warning about lingering
  ObjectDB instances/resources; normal gameplay is unaffected.

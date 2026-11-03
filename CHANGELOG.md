# Changelog

All notable changes to ONE MORE SECOND are documented here.
Format follows the spirit of Keep a Changelog; versions follow semantic versioning.

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

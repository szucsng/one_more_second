# ONE MORE SECOND

**A minimalist neon reflex arcade game. Two lanes. One tap. Stay alive.**

<p align="center">
  <img src="docs/screenshots/menu.png" width="240" alt="Main menu">
  <img src="docs/screenshots/gameplay.png" width="240" alt="Gameplay">
  <img src="docs/screenshots/game-over.png" width="240" alt="Game over">
  <img src="docs/screenshots/skins.png" width="240" alt="Skins">
</p>

ONE MORE SECOND is a portrait endless runner built in **Godot 4.7.2** with GDScript.
You sit in one of two neon lanes while hazards fall from above; tap (or press a key) to
switch lanes, survive as long as possible, and chase a personal best.

The project is designed as a commercially extensible foundation: a finished, polished
core game with local saves, skins, settings, statistics, platform layers, a local-first
analytics facade, and deliberately inactive monetization hooks.

---

## Contents

- [Feature overview](#feature-overview)
- [Screens](#screens)
- [Quick start](#quick-start)
- [Controls](#controls)
- [Project structure](#project-structure)
- [Building and deploying](#building-and-deploying)
- [Monetization status](#monetization-status)
- [Privacy](#privacy)
- [Testing and verification](#testing-and-verification)
- [Known limitations](#known-limitations)
- [Documentation](#documentation)
- [Credits and licensing](#credits-and-licensing)

---

## Feature overview

### Core game
- Two-lane, one-input reflex gameplay with forgiving hitboxes.
- Pattern-based obstacle generator with a five-minute-proven fairness envelope.
- Smooth difficulty ramp: speed, spawn cadence and pattern variety all scale.
- Score per obstacle, live HUD, personal best, run rank, survival time.
- Screen shake, hit flashes, particles, tapered ship trail, lane sparks.
- Pause/resume, restart, menu transition, auto-save.
- Frame-rate independent movement; designed for 60 FPS and low-end devices.
- Reduced-effects mode for weaker hardware or motion sensitivity.

### Meta
- Polished main menu with animated vector ship preview of the equipped skin.
- Five free skins (Default Neon, Cyan, Violet Shift, Hot Signal, Gold Rush).
- Three premium skins prepared but **not purchasable** in v1.
- Local statistics: best score, runs, total score, best/total play time, obstacles
  avoided, revives, average score, highest rank.
- Settings: SFX, music, master volume, vibration (mobile), reduced effects, fullscreen
  (web/desktop), local analytics, reset progress.
- Local JSON save with backup rotation and corruption recovery.
- Simulated, clearly-labelled rewarded ad for the revive loop; real ads are not bundled.
- Privacy-first local analytics (JSONL) with an on/off setting; no network calls.

### Platforms
- **Web/HTML5**: Godot Web export, custom responsive HTML shell, mobile touch and
  keyboard, fullscreen support, GitHub Pages and itch.io packaging documented.
- **Android**: configured portrait export preset, adaptive icons, immersive mode,
  APK/AAB workflow documented.
- **iOS**: configured portrait export preset, icon set, Xcode/App Store workflow
  documented. Signing and on-device verification require the owner's Apple account.

### Engineering
- Typed GDScript, central palette/design system, reusable theme generated from code.
- No paid or third-party game assets. Fonts are OFL; all art and audio are generated
  procedurally by scripts in `tools/`.
- Headless integration tests and a five-minute spawner stress test.
- CI workflow that builds and deploys the web version to GitHub Pages.

---

## Screens

| Menu | Game over |
| --- | --- |
| ![Menu](docs/screenshots/menu.png) | ![Game over](docs/screenshots/game-over.png) |

Game over includes a reward loop only where a rewarded ad provider is available.
The web build ships without ads, so no ad prompt is shown there.

---

## Quick start

### Requirements
- **Godot 4.7.2** (standard build, not .NET).
- macOS, Windows or Linux for development.
- Optional: Android SDK/JDK and Xcode for mobile exports.

### Run the game
1. Open Godot, choose **Import**, and select `project.godot` from this folder.
2. Let the editor import assets (a few seconds).
3. Press **F5** (Run Project).

The project boots into the main menu. Saves and analytics are written under Godot's
`user://` directory, not inside the repository.

Command line:

```bash
godot --path . --editor   # open in editor
godot --path .            # run
```

### First verification pass

```bash
godot --headless --path . --import
godot --headless --path . res://tests/GameplayTest.tscn
godot --headless --path . res://tests/SpawnerStress.tscn
```

Both tests print `PASS (0 failures)` and exit non-zero on failure.

### Build the web version

Install the matching **Web export templates** in Godot, then:

```bash
./tools/build_web.sh
python3 -m http.server 8080 --directory exports/web
# open http://localhost:8080
```

`exports/web/` is ready for any static host. `exports/one-more-second-web.zip` is
ready to upload to itch.io (HTML game, `index.html` at the ZIP root).

See [docs/web-deployment.md](docs/web-deployment.md) for hosting, compression,
GitHub Pages and itch.io details.

---

## Controls

| Action | Touch | Keyboard |
| --- | --- | --- |
| Switch lane | Tap anywhere | `Space`, `W`, `↑`, `A`, `D`, `←`, `→` |
| Pause / resume | Pause button | `Esc`, `P` |
| Menu navigation | Tap | Arrow keys / Tab + Enter |

On mobile, tapping UI buttons does not switch lanes; only taps on the playfield do.

---

## Project structure

```text
one_more_second/
├── project.godot              # Godot 4.7 project configuration
├── export_presets.cfg         # Web / Android / iOS presets
├── scenes/
│   ├── main/                  # App shell
│   ├── menu/
│   ├── gameplay/              # Gameplay, HUD, pause
│   ├── player/
│   ├── obstacles/
│   ├── game_over/
│   ├── settings/
│   ├── skins/
│   ├── stats/
│   └── components/            # Reusable toggle, test ad overlay
├── scripts/
│   ├── core/                  # Palette, config, difficulty, router, app shell
│   ├── gameplay/              # Player, trail, obstacle, spawner, FX, state machine
│   └── ui/                    # Screens, shared widgets, ship renderer
├── systems/
│   ├── save/
│   ├── audio/
│   ├── skins/
│   ├── ads/                   # Provider contract, policy, test placement
│   ├── analytics/
│   ├── monetization/
│   └── platform/
├── assets/
│   ├── fonts/                 # Audiowide + Rajdhani (OFL, licenses included)
│   ├── icons/                 # Generated vector + PNG export sizes
│   ├── textures/              # Generated splash
│   ├── sounds/                # Generated SFX
│   ├── music/                 # Generated synthwave loop
│   └── theme/                 # Generated UI theme
├── tools/                     # Reproducible theme/icon/audio generators + build script
├── tests/                     # Headless integration + stress tests, visual harness
├── web/shell.html             # Custom web loading shell
├── docs/                      # Architecture, platform builds, monetization, QA
├── .github/workflows/         # GitHub Pages deployment
├── BUILDING.md                # Platform build quick reference
├── CHANGELOG.md
├── THIRD_PARTY_NOTICES.md
└── LICENSE
```

---

## Building and deploying

- **Web / itch.io / GitHub Pages:** [docs/web-deployment.md](docs/web-deployment.md)
- **Android APK and AAB:** [docs/android-build.md](docs/android-build.md)
- **iOS and Xcode:** [docs/ios-build.md](docs/ios-build.md)
- **All platforms, short version:** [BUILDING.md](BUILDING.md)
- **GitHub Actions:** `.github/workflows/deploy-web.yml` builds and publishes the web
  game to GitHub Pages on every push to `main`/`master` (or manually).

Version 1.0.0 uses Godot **4.7.2**. Export templates must match the editor version
exactly. The project uses the **Compatibility** renderer for broad web/mobile support.

---

## Monetization status

The base game is free and fully playable offline.

- Rewarded revive is implemented behind an ad abstraction and runs as a **clearly
  labelled local simulation**. No real ad SDK is bundled. The host can close the
  test ad at any time without losing the run.
- On web, ads are deliberately **disabled**. The web ad strategy must be decided
  separately, with its own approval and privacy work.
- Interstitial/banner code paths and frequency policy exist but are disabled.
- The store abstraction lists planned products and prices; **no purchase flow is
  active** and no fake transaction is exposed.
- AdMob test IDs are included only as documentation constants. Production IDs must
  be supplied by the owner. Integration steps: [docs/monetization.md](docs/monetization.md).

Optional support for the developer is prepared: set `GameConfig.SUPPORT_URL` in
`scripts/core/game_config.gd` to a real page (itch.io, Ko-fi, etc.). While the string
is empty, the button is hidden.

---

## Privacy

- No location, contacts, advertising identifiers or personal data are collected.
- Analytics v1 is **local only**: JSONL files under `user://analytics/`, capped and
  rotated, controllable in Settings.
- No network calls are made by the game, the analytics layer or the store layer.
- If a real ad network or a cloud leaderboard is added later, the owner must add the
  corresponding consent, privacy-policy and store disclosures.
- Saves remain on the device (IndexedDB for web, app data for Android/iOS).

See [docs/privacy.md](docs/privacy.md).

---

## Testing and verification

Verified in this build:

- Godot 4.7.2 project import with zero parse errors.
- Headless gameplay integration test: boot, scoring, collision, game over, restart,
  pause/resume, rewarded revive, save round-trip, analytics file.
- Headless five-minute spawner stress test: 487 obstacles, bounded active set, zero
  unreactable two-lane overlaps, scripted safe-lane bot survives.
- Native visual review of every screen at 1080×1920 (macOS, Compatibility renderer).
- Web export loaded from a local HTTP server in headless Chrome (WebGL2): menu,
  mouse/touch/keyboard input, Play, pause, no console/page errors.
- Mobile browser emulation (390×844, touch): portrait layout, touch PLAY, single-tap
  lane switch, touch pause, no console errors.

Not verified (requires owner accounts/hardware):

- Android APK/AAB compilation and on-device run (Android SDK not installed here).
- iOS export, signing, Xcode build and device/App Store run (no Apple account/team).
- Real AdMob serving and real in-app purchases.
- Low-end physical phones, Safari/Firefox/Edge on physical devices.

Exact test matrix and evidence: [docs/testing.md](docs/testing.md).

---

## Known limitations

- Godot Web exports are relatively large: the wasm file is ~38 MB uncompressed,
  ~10 MB gzip. Enable compression on the host; see the deployment guide.
- The project is portrait-first and uses a 1080×1920 design canvas with letterboxing
  on unusual aspect ratios.
- Web audio starts after the first user interaction (browser policy).
- The web build has no ads; the test ad is available only on desktop/native QA.
- Real store/ads plugins are intentionally absent from v1.
- Cloud saves, global leaderboards and daily challenges are future work; the
  architecture leaves room for them but no backend exists.

---

## Documentation

| Document | Purpose |
| --- | --- |
| [BUILDING.md](BUILDING.md) | Quick platform build commands |
| [docs/architecture.md](docs/architecture.md) | Systems, state machines, save schema, extension points |
| [docs/development.md](docs/development.md) | Local workflow, tests, asset regeneration, conventions |
| [docs/web-deployment.md](docs/web-deployment.md) | Own site, GitHub Pages, itch.io, caching/compression |
| [docs/android-build.md](docs/android-build.md) | SDK setup, APK/AAB, signing, store checklist |
| [docs/ios-build.md](docs/ios-build.md) | Xcode, signing, App Store notes |
| [docs/monetization.md](docs/monetization.md) | Ads abstraction, IAP plan, consent, activation steps |
| [docs/privacy.md](docs/privacy.md) | Data practices for stores and players |
| [docs/testing.md](docs/testing.md) | Verification matrix and manual QA |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common failures and fixes |
| [docs/release-checklist.md](docs/release-checklist.md) | Final go-live audit |

---

## Credits and licensing

- **Design, code, generated art and generated audio:** © 2026 ONE MORE SECOND.
  All rights reserved; see [LICENSE](LICENSE).
- **Audiowide** by Brian J. Bonislawsky / Astigmatic (OFL 1.1).
- **Rajdhani** by Indian Type Foundry (OFL 1.1).
- Full font licenses: `assets/fonts/LICENSE-*.txt`;
  see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- No third-party samples, paid asset packs, copyrighted music or trademarks are used.

The repository is **private/proprietary by default**. Viewing or forking it on GitHub
does not grant commercial rights. The bundled fonts remain available under the OFL.

---

## One more press?

The game is built to make the player think *“one more try.”*
If you extend it, keep the loop fast, the input honest, and the ads optional.

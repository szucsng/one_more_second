# Release Checklist — ONE MORE SECOND

Use this before every public build. Check only what was actually done.

---

## 0. Scope and approvals

- [ ] Owner approved the release scope (v1.1.0: no real ads, no purchases).
- [ ] No paid service, store submission or publishing action was performed without
      explicit owner approval.
- [ ] Package/bundle id, app name and support contact are final.
- [ ] Privacy policy URL is live.
- [ ] `GameConfig.SUPPORT_URL` is either a real URL or intentionally empty (button
      hidden).
- [ ] No real AdMob IDs, keystores, provisioning profiles or secrets are committed.

## 1. Versioning

- [ ] `project.godot` → `application/config/version` updated (1.1.0).
- [ ] `scripts/core/game_config.gd` → `VERSION` updated.
- [ ] Android `version/code` increased (integer; 1.1.0 = 2).
- [ ] Android `version/name` updated.
- [ ] iOS `application/short_version` updated.
- [ ] iOS `application/version` (build) increased (1.1.0 = 2).
- [ ] `CHANGELOG.md` updated.
- [ ] Git tag prepared (e.g. `v1.1.0`).

## 2. Code and content freeze

- [ ] No debug prints, test scores or temporary flags in release paths.
- [ ] `AdConfig.TEST_MODE` matches the intended release behavior.
- [ ] `AdConfig.ALLOW_TEST_ADS_ON_WEB` is false for a public web build.
- [ ] `Monetization.store_available` false unless billing is actually implemented.
- [ ] `GameConfig.SUPPORT_URL` has no placeholder domain.
- [ ] No TODOs for v1 features.
- [ ] `.gitignore` excludes exports, caches, keystores and artifacts.

## 3. Automated tests

- [ ] `godot --headless --path . --import` with zero parse errors.
- [ ] `GameplayTest` → PASS (0 failures).
- [ ] `SpawnerStress` → PASS (0 failures).
- [ ] Save round-trip verified.
- [ ] Analytics local log written.
- [ ] No red errors in the editor debugger during a 5-minute play session.

## 4. Manual QA — desktop

- [ ] Menu, skins, settings, statistics open and go back.
- [ ] Skin selection updates menu preview and persists.
- [ ] Sound/music toggles and volume.
- [ ] Reduced effects visibly reduces particles/shake.
- [ ] Fullscreen toggle works (desktop/web where supported).
- [ ] Pause/resume, restart, menu.
- [ ] Collision, game over, NEW RECORD, best score.
- [ ] Combo tiers at 5/10/20/30, exact multiplier totals, reset on collision/restart.
- [ ] Perfect dodge awards once per obstacle; late/fatal switches do not award.
- [ ] Daily screen, date-seeded set, progress and reward integration.
- [ ] Completing a challenge cannot reward twice; date rollover preserves lifetime count.
- [ ] Reset progress (two-step) behaves as documented.
- [ ] Keyboard-only navigation works.
- [ ] Window resize/letterboxing looks correct.
- [ ] No UI clipped at 1080×1920 and at the 540×960 window size.

## 5. Manual QA — web

- [ ] Build via `./tools/build_web.sh` from a clean export.
- [ ] `index.wasm` served as `application/wasm`.
- [ ] gzip/Brotli enabled on the host; measured transfer size.
- [ ] Loads in current Chrome, Edge, Firefox and Safari desktop.
- [ ] Loading overlay hides; failure message works if WebGL2 missing.
- [ ] Mouse + touch + keyboard input.
- [ ] Audio starts after a gesture.
- [ ] Fullscreen (where supported).
- [ ] Saves survive reload.
- [ ] No console errors.
- [ ] No ad prompt (web is ad-free).
- [ ] GitHub Pages/itch.io deployment tested on a phone.
- [ ] Cache/version strategy documented for the fixed filenames.

## 6. Manual QA — Android (when building)

- [ ] SDK/JDK paths configured; templates match 4.7.2.
- [ ] Debug APK installs and launches.
- [ ] Portrait lock and immersive mode.
- [ ] Safe area/notch on a physical phone.
- [ ] Touch input; buttons don't switch lanes.
- [ ] Back button behavior (pause/resume/menu/exit).
- [ ] Background/foreground auto-pause.
- [ ] Save survives force-stop.
- [ ] Vibration on/off.
- [ ] Audio/music/volume.
- [ ] Reduced effects.
- [ ] Offline full playthrough.
- [ ] Low-end device performance.
- [ ] Adaptive icon on launcher.
- [ ] Release keystore configured; AAB exported.
- [ ] `apksigner verify` passes.
- [ ] Play Console internal test install.
- [ ] Data safety form matches reality.
- [ ] Content rating completed.
- [ ] Store screenshots/icons/feature graphic uploaded.

## 7. Manual QA — iOS (when building)

- [ ] Matching iOS export template installed.
- [ ] Team ID, bundle id, signing configured.
- [ ] Xcode archive builds without errors.
- [ ] Portrait-only target.
- [ ] Safe area/Dynamic Island.
- [ ] Touch, audio after gesture, vibration (if supported).
- [ ] Background/foreground.
- [ ] Save survives force-quit.
- [ ] Offline play.
- [ ] TestFlight internal build installed and upgraded.
- [ ] App Store privacy answers match actual behavior.
- [ ] Privacy manifest reviewed.
- [ ] Screenshots and metadata uploaded.
- [ ] No unverified claim that iOS was tested before it was.

## 8. Monetization (only if enabled)

- [ ] Real provider plugin compatible with Godot 4.7.2.
- [ ] Production IDs supplied by the owner; test IDs removed/disabled.
- [ ] Consent/UMP implemented where required.
- [ ] ATT implemented only if tracking is used.
- [ ] Rewarded ad: optional, one per run, failure-safe.
- [ ] Interstitial: off during gameplay; frequency cap verified.
- [ ] Banner: not covering gameplay/UI.
- [ ] IAP products created; restore works; receipts validated.
- [ ] Remove Ads semantics match the description.
- [ ] Privacy policy and store forms updated.
- [ ] Ad/IAP content appropriate for the age rating.
- [ ] No misleading buttons or forced ads.

## 9. Repository and CI

- [ ] Git status clean except intended files.
- [ ] Screenshots/docs updated if UI changed.
- [ ] `.github/workflows/deploy-web.yml` green (if Pages is used).
- [ ] Pages source set to GitHub Actions.
- [ ] Deployment URL tested in a private window.
- [ ] No secrets in git history.
- [ ] License and third-party notices present.
- [ ] Tag created and pushed only with owner approval.

## 10. Post-release

- [ ] Smoke-test the live web build.
- [ ] Monitor store review / crash reports / player feedback.
- [ ] Keep a backup of the release keystore and store metadata.
- [ ] Record actual transfer sizes and load times.
- [ ] Plan 1.0.1 fixes; never hot-patch builds without bumping version codes.
- [ ] If ads/IAP were enabled, verify consent, revenue events and refund flows.
- [ ] Update the changelog and support pages.

---

## Go / No-Go rule

Ship only if:

1. all automated tests pass;
2. a complete run can be played on every target claimed in the store listing;
3. saves work after a force-quit;
4. no real ad/purchase flow is fake or misleading;
5. privacy and store disclosures match the build;
6. the owner has explicitly approved publication.

If any item above is unverified, mark it and either test it or narrow the release
claims — do not guess.

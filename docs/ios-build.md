# iOS Build Guide

The project includes an iOS export preset, an iPhone icon set (plus generated iPad
sizes for later), a splash image, portrait orientation and safe-area handling for
notched iPhones. v1 targets iPhone only (`application/targeted_device_family = 0`).

> **Verification status:** iOS has **not** been exported, signed, built in Xcode or
> run on a device in this repository. That requires macOS + Xcode plus the owner's
> paid Apple Developer team and provisioning. Nothing here claims a tested iOS build.
> No Apple Developer membership has been purchased.

---

## 1. Prerequisites

- macOS with a supported Xcode version for your Godot release.
- Godot **4.7.2** standard + matching **iOS export template**.
- Apple Developer Program membership (for TestFlight/App Store and device signing).
- An App Store Connect app record.
- A Mac with the signing certificate and provisioning profile for your team.

Install the iOS export template from Godot: *Editor → Manage Export Templates*.

---

## 2. Preset configuration

`export_presets.cfg` → iOS preset contains:

- bundle identifier: `com.onemoresecond.game` **← change to your owned id before
  first upload**
- short version: `1.2.0`; build number: `3`
- orientation: portrait via `project.godot`
- app icons: `assets/icons/ios/icon_*.png` (20–1024 px), including iPad sizes
- App Store 1024×1024 icon
- launch/splash: project boot splash (`assets/textures/splash.png`)
- export method: App Store (release)
- team ID / provisioning / signing identity: **empty placeholders**
- no camera/microphone/photos permissions requested
- project-only export off

Before exporting, fill in:

- *App Store Team ID*
- bundle identifier (if not using the default)
- signing identity + provisioning profile, or select “automatic signing” in Xcode
- version/build numbers

The app uses local storage only. It does not request tracking permission and contains
no ads or IAP in v1.

---

## 3. Export

### Editor

1. *Project → Export…*.
2. Select **iOS**.
3. Set the export path, e.g. `exports/ios/`.
4. Click **Export Project**.
5. Godot creates an Xcode project (and may create an `.ipa` only if signing is fully
   configured).
6. Open the generated `.xcodeproj`/`.xcworkspace` in Xcode.

### Command line

```bash
mkdir -p exports/ios
godot --headless --path . --export-release "iOS" \
  "$PWD/exports/ios/one-more-second.ipa"
```

With an empty Team ID the export intentionally fails with:

```
Cannot export project with preset "iOS" due to configuration errors:
App Store Team ID not specified.
```

Set the team ID in the Godot preset for CLI exports, or use the editor.

If you only need the Xcode project:

- set *Export Project Only* in the preset, or
- export and open the generated project in Xcode.

---

## 4. Xcode signing and running

1. Open the generated project in Xcode.
2. Select the app target → **Signing & Capabilities**.
3. Choose your Team.
4. Set a unique bundle identifier if the default is already registered to someone
   else; update App Store Connect to match.
5. Select a connected iPhone (or simulator for UI checks; WebGL2 compatibility may
   differ in the simulator).
6. Build & Run.

If automatic signing is unavailable, install the provisioning profile and select it
manually.

### Orientation

Godot generates the supported orientations from the project setting. Confirm in the
Xcode target that only **Portrait** is enabled for iPhone. The game is designed for
portrait; do not enable landscape unless you also redesign the layout.

### Safe area

`Platform.get_safe_insets()` converts the device safe area into the 1080×1920 design
space. Menu and screen margins plus the gameplay HUD are adjusted. Verify on a notched
iPhone that:

- the sound button/menu header clears the Dynamic Island;
- the pause button and score clear the top inset;
- the bottom hint clears the home indicator.

If the title bar still sits too high on a specific device, adjust the base margins in
`scripts/ui/menu.gd`, `settings.gd`, `skins.gd`, `statistics.gd`, and adjust the HUD
offsets in `scripts/ui/hud.gd`. Do not hard-code one device's inset.

---

## 5. Icons and splash

Generated icons:

```
assets/icons/ios/icon_20.png, icon_29, icon_40, icon_58, icon_60,
icon_76, icon_80, icon_87, icon_120, icon_152, icon_167, icon_180, icon_1024
```

To change the brand:

1. edit `assets/icons/icon.svg`;
2. run `godot --headless --path . --script tools/build_icons.gd`;
3. re-export and rebuild in Xcode.

iOS applies its own rounded mask. The source art is a rounded square; the corners are
safe for the mask. Keep the ship mark inside the central safe area for future
adaptive assets.

Launch screen: the project boot splash is used by Godot's iOS template. It is a
portrait image on a `#050505` background, matching the menu.

---

## 6. App Store Connect

1. Create an app record with the same bundle id.
2. Fill in name, subtitle, category, age rating, privacy policy URL and support URL.
3. Upload screenshots (6.9"/6.5" iPhone required; iPad if supporting it).
   Use real gameplay captures, not debug values.
4. Add a TestFlight build:
   - in Xcode choose **Product → Archive**;
   - **Distribute App → App Store Connect → Upload**;
   - wait for processing, then invite internal testers.
5. Complete export compliance (the game uses standard encryption only; answer
   according to Apple's current questionnaire).
6. Submit for review only when the owner approves.

The game is **free**. In v1 there are no real ads or purchases, so do not fill in
IAP/ads disclosures that do not apply. If ads or IAP are added later, update:

- App Store privacy disclosures;
- ATT prompts if tracking is introduced;
- review notes explaining optional rewarded ads and restore-purchases behavior.

### Privacy

v1 collects no personal data and makes no network requests. Local analytics stay in
the app sandbox and can be disabled in Settings. Provide a real privacy policy URL
before submission; see [privacy.md](privacy.md).

Apple requires a privacy manifest for certain “required reason” APIs in some SDKs.
Godot's export templates may generate/adjust this; review the generated Xcode project
and App Store Connect warnings. Do not declare data collection that does not occur.

---

## 7. Testing checklist on device

- [ ] App installs, launches into the menu, splash matches the theme.
- [ ] Portrait only; no rotation layout break.
- [ ] Safe area: notch/Dynamic Island and home indicator cleared.
- [ ] Touch switches lanes; buttons do not.
- [ ] Pause/resume, backgrounding, returning to the app.
- [ ] Audio starts after first tap; respects silent switch/mute behavior.
- [ ] Vibration on supported devices and respects the setting.
- [ ] Save survives force-quit and relaunch.
- [ ] Best score, settings, skins and statistics persist.
- [ ] Offline play works completely.
- [ ] Reduced effects mode.
- [ ] Fullscreen/immersive behavior (iOS handles it automatically).
- [ ] 60 FPS target on the oldest supported iPhone.
- [ ] TestFlight install and upgrade path.

Not tested here: any of the above on physical iOS hardware.

---

## 8. Real ads / IAP on iOS

No AdMob/StoreKit code is bundled. To add them:

1. Verify a maintained AdMob plugin compatible with **Godot 4.7.2** (the Poing Studios
   plugin documents Godot 4.5+, Xcode 15+, iOS 15+; verify the current release).
2. Implement the existing `NativeAdMobProvider` contract against that plugin, including
   app/unit IDs, rewarded/interstitial loading and reward callbacks. The current stub
   intentionally fails closed.
3. Add UMP consent before initialization/loading; add ATT only if tracking is actually
   used, and request permission before personalized ads.
4. Test with Google test ad units on physical devices, then enable
   `AdConfig.PRODUCTION_ADS_ENABLED` only when IDs, consent and signing are ready.
5. Add StoreKit for the planned skins/remove-ads products; validate transactions and
   restore purchases.
6. Update the privacy policy, App Store Connect disclosures and review notes.

See [monetization.md](monetization.md).

---

## 9. Common iOS failures

| Symptom | Fix |
| --- | --- |
| “App Store Team ID not specified” | Fill the Team ID in the preset |
| No signing identity | Install certificate/profile from Apple Developer; use Xcode automatic signing |
| Bundle id conflict | Change `application/bundle_identifier` and App Store Connect record |
| Blank screen on launch | Check Xcode console; ensure the export template matches the editor version |
| Wrong orientation | Check the Xcode target orientations and Godot project setting |
| HUD under the notch | Test safe-area handling; verify the device reports insets |
| Audio silent | iOS silent switch / first gesture; verify mute behavior |
| App Store upload warnings | Review privacy manifest and icon requirements in Xcode |
| Icon missing | Regenerate icons and re-export; confirm files are referenced in the preset |

# BUILDING — ONE MORE SECOND

Quick platform-by-platform build reference. Detailed guides are linked in each section.

- Engine: **Godot 4.7.2** (standard build)
- Renderer: **Compatibility** (WebGL2 / OpenGL ES 3)
- Design canvas: **1080 × 1920**, portrait
- Version: **1.0.0** (version code `1`)
- Package / bundle id: **com.onemoresecond.game** (change before store release)

Install the matching **export templates** first:
Godot editor → *Editor → Manage Export Templates → Download and Install*.
Without matching templates, export fails before producing files.

All commands below run from the repository root. Set:

```bash
export GODOT_BIN="/path/to/Godot_v4.7.2-stable..."
```

---

## 1. Run and test locally

```bash
"$GODOT_BIN" --path . --editor       # editor
"$GODOT_BIN" --path .                # run the game
"$GODOT_BIN" --headless --path . --import

"$GODOT_BIN" --headless --path . res://tests/GameplayTest.tscn
"$GODOT_BIN" --headless --path . res://tests/SpawnerStress.tscn
```

Visual QA harness (opens a window, writes screenshots to `tests/artifacts/`):

```bash
"$GODOT_BIN" --path . --resolution 1080x1920 res://tests/VisualCheck.tscn
```

---

## 2. Web / HTML5

### One-command release build

```bash
./tools/build_web.sh
```

Outputs:

```text
exports/web/                    static site (index.html + wasm + pck + js + icons)
exports/one-more-second-web.zip itch.io-ready ZIP (index.html at root)
```

### Manual export

```bash
mkdir -p exports/web
"$GODOT_BIN" --headless --path . --export-release "Web" "$PWD/exports/web/index.html"
```

The preset uses:

- custom shell: `web/shell.html`
- adaptive canvas resizing
- compatibility renderer
- no threads / no extensions
- tests, tools and docs excluded from the build

### Preview

```bash
python3 -m http.server 8080 --directory exports/web
# http://localhost:8080
```

Do **not** open `index.html` via `file://`; WebAssembly and fetch require HTTP.

### Host

- GitHub Pages: `.github/workflows/deploy-web.yml` builds and deploys automatically.
- itch.io: upload `exports/one-more-second-web.zip` as an HTML game, 540×960 or
  “embed in page”, fullscreen enabled.
- Own host: serve `.wasm` as `application/wasm` and enable gzip/Brotli.

Full details, headers and caching: [docs/web-deployment.md](docs/web-deployment.md).

---

## 3. Android

Status in this repository: **preset configured, not compiled here** because no Android
SDK/JDK was installed in the build environment. See
[docs/android-build.md](docs/android-build.md) for the complete setup.

### Prerequisites

- JDK 17
- Android SDK command-line tools
- Platform tools, build-tools, platform 35
- Godot Editor Settings → Export → Android: SDK path + debug keystore
- Android export template installed

### Debug APK (GUI)

1. *Project → Install Android Build Template…* is **not** required for a basic APK.
2. *Project → Export… → Android*.
3. Choose `exports/android/one-more-second.apk`.
4. *Export Project*. For a debug build, use the debug export or configure a debug
   keystore in Editor Settings.

### CLI

```bash
mkdir -p exports/android
"$GODOT_BIN" --headless --path . --export-debug "Android" \
  "$PWD/exports/android/one-more-second-debug.apk"
```

Release builds require a keystore and signing configuration:

```bash
keytool -genkey -v -keystore one-more-second.keystore \
  -alias onemoresecond -keyalg RSA -keysize 2048 -validity 10000
```

Store the keystore and passwords outside the repository. Configure them in
*Editor Settings → Export → Android* (debug/release keystore), then export release:

```bash
"$GODOT_BIN" --headless --path . --export-release "Android" \
  "$PWD/exports/android/one-more-second.apk"
```

### AAB for Google Play

1. *Project → Install Android Build Template…*
2. In the Android preset, enable **Gradle Build**.
3. Set **Export format** to **AAB**.
4. Export to `exports/android/one-more-second.aab`.

Testing/signing requirements, version bumps and store assets are in
[docs/android-build.md](docs/android-build.md).

---

## 4. iOS

Status in this repository: **preset configured, not exported or tested**. Exporting
requires macOS, Xcode, a valid Apple Developer team and provisioning profiles.
No Apple Developer membership is included or purchased.

### Steps

1. Install the iOS export template in Godot.
2. In the iOS preset, set:
   - App Store Team ID
   - bundle identifier (`com.onemoresecond.game` by default)
   - signing identity / provisioning profile for release
3. *Project → Export… → iOS* → **Export Project**.
4. Open the generated Xcode project/workspace.
5. Set the team/signing and a unique bundle id if needed.
6. Build/run on a device or archive for TestFlight/App Store.

Portrait orientation, app icon set, launch splash and bundle metadata are prepared.
Full guide: [docs/ios-build.md](docs/ios-build.md).

---

## 5. Versioning

Before a store release, update all of these:

| File | Field |
| --- | --- |
| `project.godot` | `application/config/version` |
| `scripts/core/game_config.gd` | `VERSION` (used by menu/footer) |
| `export_presets.cfg` | Android `version/code` (must increase every upload) |
| `export_presets.cfg` | Android `version/name` |
| `export_presets.cfg` | iOS `application/short_version` |
| `export_presets.cfg` | iOS `application/version` (build number, must increase) |
| `CHANGELOG.md` | release notes date/version |

Android version code is an integer and must strictly increase. iOS build number is a
string but should also increase.

---

## 6. Clean build tip

If a cached import breaks after an engine upgrade:

```bash
rm -rf .godot
"$GODOT_BIN" --headless --path . --import
```

Never commit `.godot/`, export artifacts, keystores or provisioning profiles.

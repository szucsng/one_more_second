# Web Deployment

The web build is a static HTML5/WASM bundle. No server-side code is required.

- Exported with Godot 4.7.2, **Compatibility** renderer, single-threaded.
- Custom loading shell: `web/shell.html`.
- Tested locally in headless Chrome with WebGL2. See [testing.md](testing.md).

---

## 1. Build

Install the matching Web export templates, then:

```bash
./tools/build_web.sh
```

Output:

```text
exports/web/
├── index.html                    custom shell
├── index.js
├── index.pck                     game data (~2.2 MB)
├── index.wasm                    engine (~38 MB uncompressed)
├── index.audio.worklet.js
├── index.audio.position.worklet.js
├── index.icon.png
├── index.apple-touch-icon.png
├── ads-config.js                public web-ad config (disabled by default)
├── ads-bridge.js                isolated AdSense H5 bridge
├── fonts/rajdhani-bold.woff2    loading screen / ad prompt font
└── .nojekyll
exports/one-more-second-web.zip  itch.io upload
```

Typical transfer size with gzip: **~10 MB wasm + ~1.5 MB pck**; the itch ZIP is ~12 MB. Enable compression
on the host. There is no CDN dependency in the game.

Manual equivalent (advanced; also copy the ad/font support files):

```bash
mkdir -p exports/web
godot --headless --path . --export-release "Web" "$PWD/exports/web/index.html"
cp web/ads-config.js exports/web/
cp web/ads-bridge.js exports/web/
mkdir -p exports/web/fonts
cp web/fonts/rajdhani-bold.woff2 exports/web/fonts/
```

Using `./tools/build_web.sh` is preferred because it performs those copies
automatically and packages the ZIP.

Do not open the file directly with `file://`.

---

## 2. Local preview

```bash
python3 -m http.server 8080 --directory exports/web
# http://localhost:8080
```

The Python server is fine for functional checks but does not enable compression.
For a production-like test use:

```bash
npx serve exports/web --compress
# or
caddy file-server --root exports/web --listen :8080
```

Check that `.wasm` is served as `application/wasm`:

```bash
curl -I http://localhost:8080/index.wasm
```

Expected header: `Content-Type: application/wasm`.

### Embedding on your own page

The build is a normal static site. You can embed it in an existing page with an
iframe while keeping the game's own responsive shell:

```html
<iframe
  src="/games/one-more-second/"
  title="ONE MORE SECOND"
  width="540"
  height="960"
  style="border:0;max-width:100%;aspect-ratio:9/16;"
  allow="fullscreen; autoplay; gamepad"
  loading="lazy">
</iframe>
```

For a seamless full-page experience, link to the export directly instead. Do not
remove the custom shell's viewport meta tag; mobile scaling depends on it.

### Fullscreen

- The Settings screen exposes a **FULLSCREEN** toggle on web/desktop.
- The custom shell also has an **Enter fullscreen** button on the loading screen.
- The Fullscreen API requires a user gesture. Desktop Chrome/Edge/Firefox support it;
  iPhone Safari has limited support for arbitrary elements and may ignore the request.
  This degrades gracefully.
- The game remains playable without fullscreen.

### Audio

Browsers block autoplay. Music/SFX begin after the first click/tap. This is expected
and handled by `AudioManager`; do not add a fake audio prompt.

### Saves on web

Godot persists `user://` to the browser's IndexedDB for the page's origin.

- Changing domain/subdomain/path origin creates a separate save store.
- Private/incognito data may be cleared by the browser.
- There is no cloud sync in v1.

---

## 3. Own website (nginx)

```nginx
server {
    listen 443 ssl http2;
    server_name game.example.com;
    root /srv/one-more-second/exports/web;
    index index.html;

    types {
        application/wasm wasm;
    }

    gzip on;
    gzip_comp_level 6;
    gzip_min_length 1024;
    gzip_types application/javascript application/wasm application/json text/css text/html image/svg+xml;

    # Optional: Brotli if the module is available.
    # brotli on;
    # brotli_comp_level 5;
    # brotli_types application/javascript application/wasm application/json text/css text/html;

    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;

    # Fixed filenames mean stale caches are dangerous after a deploy.
    # Either purge the CDN or use a versioned directory (recommended).
    location = /index.html {
        add_header Cache-Control "no-cache";
    }
    location ~* \.(wasm|pck|js)$ {
        add_header Cache-Control "public, max-age=3600";
    }
}
```

Caddy equivalent:

```caddy
game.example.com {
    root * /srv/one-more-second/exports/web
    encode zstd gzip
    file_server
    header {
        X-Content-Type-Options nosniff
        Referrer-Policy strict-origin-when-cross-origin
    }
}
```

**Cross-origin isolation is not required.** The build is single-threaded and does not
use SharedArrayBuffer. Do not add COOP/COEP headers unless a future threaded build
requires them.

### Versioned deployments

Because Godot outputs fixed filenames, a cached `index.wasm` can pair with a new
`index.pck` and break. Recommended:

- deploy to `/releases/1.2.0/` and point the homepage link at the new folder;
- or purge the CDN on deploy;
- or keep `index.html` and `index.js` `no-cache` and use short wasm/pck TTLs.

The GitHub Actions workflow deploys to the Pages root, so bumping the version and
letting Pages invalidate caches is enough for small releases. For heavy traffic,
prefer versioned paths.

---

## 4. GitHub Pages

The repository includes `.github/workflows/deploy-web.yml`.

1. Push the project to GitHub.
2. Repository → **Settings → Pages → Build and deployment**.
3. Source: **GitHub Actions**.
4. Push to `main`/`master` or run **Actions → Deploy Web Build → Run workflow**.
5. The workflow:
   - downloads Godot 4.7.2 + export templates (cached);
   - imports the project;
   - exports the web release;
   - uploads the itch.io ZIP as an artifact;
   - deploys `exports/web` to Pages.

Notes:

- Pages URLs are served from a subpath. All game URLs are relative, so this works.
- `.nojekyll` is created to stop Jekyll processing.
- GitHub Pages does **not** guarantee gzip/Brotli for wasm. Check with:

  ```bash
  curl -sI -H "Accept-Encoding: gzip" https://USER.github.io/REPO/index.wasm | grep -i content-encoding
  ```

  If it is not compressed and load time matters, use Cloudflare Pages, Netlify,
  Vercel or your own nginx/Caddy host instead. The workflow output is fully static;
  any host works.
- GitHub Pages has a 1 GB published-site limit; this build is far below it.
- Pages HTTPS is automatic.

### Custom domain

Settings → Pages → Custom domain, create the DNS CNAME, enable HTTPS. Update the
domain in store listings and social links. Remember saves are origin-specific.

---

## 5. itch.io

1. Run `./tools/build_web.sh`.
2. On itch.io create a new project.
3. **Kind of project**: `HTML`.
4. Upload `exports/one-more-second-web.zip`.
5. Tick **This file will be played in the browser**.
6. Embed options:
   - viewport: **540 × 960** (portrait);
   - enable **Fullscreen button**;
   - enable **Mobile friendly** / responsive;
   - optionally “Click to play” to satisfy audio restrictions.
7. Set the project to **Restricted / Draft** until final approval.
8. Test the uploaded build on a phone and a desktop browser before publishing.
9. Optional: set a support link and link it in `GameConfig.SUPPORT_URL` in a future
   build so the in-game SUPPORT button appears.

The ZIP has `index.html` at the root, as itch.io expects.

---

## 6. Loading and error behavior

The custom shell:

- shows the ONE MORE SECOND wordmark and a neon progress bar;
- installs no service worker and makes no external requests **unless web ads are
  explicitly enabled**;
- shows a readable failure message if WebGL2 or required browser features are missing;
- allows fullscreen from the loading screen;
- prevents context menus, scrolling and double-tap zoom;
- uses `viewport-fit=cover` and safe-area padding for notched phones;
- respects `prefers-reduced-motion` for its own animation;
- replaces the Godot default splash/loading UI.

If loading stalls:

1. open DevTools → Network and confirm `index.wasm` is 200 and
   `application/wasm`;
2. confirm the host supports range requests / large files;
3. confirm the page is served over HTTP(S), not `file://`;
4. check the Console for WebGL2 errors;
5. try a fresh build after `rm -rf .godot && godot --headless --path . --import`.

---

## 7. Browser support

Expected support follows Godot 4.7 Web:

- Chrome / Edge (desktop & Android): recommended;
- Firefox (desktop & Android): supported;
- Safari (macOS): supported;
- Safari iOS: supported on modern versions; fullscreen and audio behavior are the
  most browser-dependent parts.

The game requires **WebGL2**. Very old devices or browsers with WebGL disabled will
show the shell error message.

Not verified on this build: physical Firefox/Safari/Edge devices, older Android
phones, iOS Safari. Validate on the target matrix before a marketing push.

---

## 8. Web analytics and ads

- No analytics data leaves the browser. Local events are stored in IndexedDB and are
  only visible to the player (or via DevTools).
- **The default web build is ad-free.** With `AdConfig.PRODUCTION_ADS_ENABLED = false`
  and `web/ads-config.js` `enabled: false`, the bridge makes **no Google network
  requests**, loads no AdSense script and creates no ad prompt.
- The Google AdSense H5 Games Ads integration is prepared in
  `web/ads-bridge.js` + `systems/ads/providers/web_h5_ad_provider.gd`.
  H5 Games Ads is **by application** and requires an approved AdSense account,
  domain approval, HTTPS and a Google-certified CMP for EEA/UK consent.
- To enable, follow [monetization.md](monetization.md) exactly, including:
  - `web/ads-config.js` publisher ID/test mode/consent;
  - `AdConfig.PRODUCTION_ADS_ENABLED = true`;
  - test mode first, then production;
  - real policy/consent review.
- The reward prompt is a styled DOM dialog. Its watch button calls the provider's
  `showAdFn()` directly from the browser click, which preserves the user gesture
  required by the Ad Placement API. The prompt clearly labels production/optional
  ads and offers **NO THANKS**.
- Interstitials remain disabled by default. If enabled later, test web user
  activation with the approved provider before shipping.
- Do not enable a banner in active gameplay.
- Giving the game an ad provider changes the privacy/network profile: update the
  privacy policy, CMP consent and store disclosures first.
- If you add a Content-Security-Policy, allow the Google ad script/frame domains
  required by Google's current documentation; test the actual ad flow afterward.

---

## 9. Post-deploy checklist

- [ ] Page loads over HTTPS with no console errors.
- [ ] Loading overlay disappears after download.
- [ ] Menu buttons work with mouse, touch and keyboard.
- [ ] PLAY starts a run; tap/space switches lanes.
- [ ] Pause/resume works; tab-away auto-pauses.
- [ ] Game over appears; restart and menu work.
- [ ] Best score survives a page reload.
- [ ] Settings persist after reload (audio, reduced effects, analytics).
- [ ] Portrait layout on a phone; no content under the notch.
- [ ] Fullscreen enters/exits where the browser allows it.
- [ ] Sound begins after the first interaction.
- [ ] Default ad-free build: no AdSense script and zero Google ad requests.
- [ ] Ad-enabled build (only after approval): CMP consent, test mode, domain
      approval, prompt, reward, no-fill/failure paths.
- [ ] `index.wasm` is compressed (gzip/Brotli) in production.
- [ ] Mobile data load time acceptable; if not, consider a lighter future engine
      build or a native app funnel.

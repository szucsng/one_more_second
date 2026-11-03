# Privacy

**Summary: v1.2.0 ships with ads disabled and makes no network requests by default.
When production ads are explicitly enabled, Google AdSense H5 Games Ads loads a
third-party script subject to Google's policies and the owner's CMP/consent setup.**

This document describes the current build. It is not legal advice; adapt it to your
jurisdiction and distribution stores before release.

---

## 1. Data stored on the device

| Data | Purpose | Location |
| --- | --- | --- |
| Best score | Personal record | `user://save.json` |
| Run statistics (games, total score, play time, obstacles, revives) | Statistics screen | `user://save.json` |
| Settings (audio, volume, vibration, effects, analytics, fullscreen) | Remember preferences | `user://save.json` |
| Skin selection / unlocked skins | Cosmetics | `user://save.json` |
| Ad counters / last interstitial timestamp | Frequency limiting (future ads) | `user://save.json` |
| Local analytics events | Local QA/product insight | `user://analytics/events-*.jsonl` |
| Daily challenge set/progress/completions | Local replayability | `user://save.json` |

- No name, email, phone, address, precise location, contacts, photos, microphone,
  camera, advertising identifier or payment data is collected.
- The random `session` id is generated per app launch and stored only inside local
  analytics lines. It is not a device fingerprint and is not transmitted.
- No cloud sync or account exists in v1.
- Daily challenges are generated from the local date and stored only in the local
  save; changing the device date changes the local set.
- Web saves use the browser's IndexedDB for the game origin. Native saves live in the
  app's sandbox.

---

## 2. Network

The default release has **no third-party network requests**:

- analytics is local JSONL;
- ads are disabled by default (`AdConfig.PRODUCTION_ADS_ENABLED = false` and
  `web/ads-config.js` enabled false);
- the store is inactive;
- no crash reporting, no telemetry, no third-party fonts/CDNs.

### If web ads are enabled

Enabling the prepared Google AdSense H5 Games Ads integration changes the network
profile:

- the browser loads Google's AdSense/Ad Placement script and may contact Google ad
  servers;
- Google may use cookies/identifiers under its own policies;
- EEA/UK/Switzerland personalized ads require a Google-certified CMP and valid
  consent; the game does not claim that the owner's deployment is compliant;
- the game/bridge must not be used to send player names, save data, scores or other
  personal data to the provider. Our bridge sends only ad configuration and provider
  callbacks;
- the owner must update this policy, provide a privacy/consent UI through the CMP,
  and complete the store data-safety disclosures before enabling production ads.

Native AdMob is prepared but not active. The native adapter fails closed until an
AdMob plugin, IDs, UMP consent and signed/tested builds are supplied.

---

## 3. Analytics toggle

Settings → **LOCAL ANALYTICS** can be turned off at any time. When disabled:

- no new events are written;
- a final `analytics_toggled` event with `enabled: false` is written before disabling;
- gameplay and saves are unaffected.

Local logs rotate at 512 KB per day and are not uploaded anywhere. A player can delete
them by deleting the app data / site data.

---

## 4. Deletion and control

- **Reset Progress** (Settings) clears best score and statistics; settings, skins and
  ad counters are kept.
- Deleting the app / clearing browser site data removes the save and local analytics.
- There is no server-side data to request or delete in v1.

For store listings, describe:
- data collected: **none** (v1);
- data shared: **none** (v1);
- data stored locally: game progress and preferences;
- privacy policy URL: host this document or an adapted version on the game's website.

---

## 5. Children

The game contains no chat, user-generated content, external links in gameplay,
purchases or real ads in v1. Age rating should still be set honestly on each store.
If real ads or purchases are added, review child-directed rules (COPPA, GDPR-K,
Google Play Families, App Store Kids) before distribution.

---

## 6. Future integrations (not active)

If you add:

- **AdMob / any ad SDK** — add consent (UMP/CMP), a privacy policy update, store
  data-safety disclosures, ATT on iOS if tracking is enabled, and an ad-free option
  where required.
- **Hosted analytics** — minimize events, avoid identifiers, offer opt-out, document
  the processor and retention.
- **Global leaderboard / cloud save** — create a privacy policy, define retention and
  deletion, validate scores server-side, and avoid unnecessary personal data.
- **IAP** — process payments only through Google Play / Apple; do not collect card
  data yourself. Disclose purchase history handling.

The app currently has no placeholder network endpoint, API key or secret.

---

## 7. Contact

Before publishing, replace this section with the owner's real support contact and
privacy policy URL:

```text
Support: [your support email]
Privacy policy: [https://your-domain/privacy]
Last updated: 2026-11-03
```

**Do not ship a privacy policy with placeholder contact details.**

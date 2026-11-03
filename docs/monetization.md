# Monetization

## 1. Current state (v1.1.0)

The game is free, complete and playable without spending money or watching anything.

| Feature | State |
| --- | --- |
| Rewarded revive | Implemented behind an abstraction; runs as a **local simulated test ad** |
| Real AdMob SDK | **Not bundled** |
| Web ads | **Disabled** |
| Interstitial | Code policy exists; disabled |
| Banner | Interface exists; disabled |
| In-app purchases | Catalog + inactive abstraction; **no purchase UI/flow** |
| Support link | Prepared; hidden until a real URL is configured |
| Backend/payments | None |

The simulated overlay is deliberately explicit:

- title: **TEST AD / SIMULATED AD**
- text: no ad network, tracking or purchase is involved
- close button always available, no reward
- five-second timer, then **CLAIM REWARD**
- only `complete` grants a revive
- no automatic display, ever

This lets the revive loop be tested without fake revenue, real IDs or privacy risk.

---

## 2. Rewarded revive rules

- Offered only on the game-over screen, after a run.
- Clearly optional; restart and menu are always available.
- One revive per run (`GameConfig.REVIVED_RUNS_LIMIT = 1`).
- On reward:
  - the same run continues (score and survival time are preserved);
  - all current obstacles are removed;
  - spawner difficulty is eased by up to 7 elapsed seconds (never below 6);
  - the player receives 2.2 s of invulnerability;
  - revive count and analytics are recorded.
- If the provider fails to load, the button is not offered.
- Closing the test ad returns to the game-over screen with the same options.
- No ad is shown during gameplay, and no interstitial is shown on restart.

`AdsManager.is_rewarded_available()` returns false on web unless an internal QA flag
is changed. The shipped web build therefore has no ad prompt.

---

## 3. Provider abstraction

`systems/ads/ad_provider.gd` (class `AdProvider`) is the contract:

```gdscript
func initialize() -> bool
func is_rewarded_available() -> bool
func show_rewarded() -> bool
func show_interstitial() -> bool
func show_banner() -> bool
func hide_banner() -> void
```

Signals: `rewarded_ready_changed`, `rewarded_granted`, `rewarded_dismissed`,
`interstitial_closed`.

`AdsManager` owns policy, analytics, the one-per-run guard and the overlay. Gameplay
never talks to a network SDK. Swapping a real adapter in should not require changes to
`gameplay.gd` or any UI scene.

`AdConfig` (`systems/ads/ad_config.gd`) controls:

```gdscript
USE_REAL_ADS = false
TEST_MODE = true
ALLOW_TEST_ADS_ON_WEB = false
INTERSTITIAL_ENABLED = false
BANNER_ENABLED = false
INTERSTITIAL_MIN_RUNS = 3
INTERSTITIAL_MIN_SECONDS = 150.0
```

Google's official **test** IDs are included as constants for the future adapter:

```text
app id:        ca-app-pub-3940256099942544~3347511713
rewarded:      ca-app-pub-3940256099942544/5224354917
interstitial:  ca-app-pub-3940256099942544/1033173712
banner:        ca-app-pub-3940256099942544/6300978111
```

These are public test units, not monetized. **Never ship production IDs found in
documentation or another project.** The owner must supply their own account's IDs.

---

## 4. Activating AdMob (optional, later)

1. **Choose a maintained Godot 4.7-compatible AdMob plugin/bridge.** Verify:
   - Godot 4.7.2 support,
   - Android and iOS support (or separate native bridges),
   - current Google Mobile Ads SDK,
   - consent/UMP support,
   - privacy manifest handling.
   The plugin is intentionally not vendored in this repository.
2. Add the plugin and required Android/iOS configuration (AdMob app ID, SKAdNetwork
   identifiers if applicable, ATT description only if tracking is used).
3. Implement the adapter:

   ```gdscript
   class_name AdMobProvider
   extends AdProvider

   func initialize() -> bool:
       # 1. initialize the plugin with the platform app ID
       # 2. load the rewarded unit
       # 3. connect ready/failed/dismissed callbacks
       return true

   func is_rewarded_available() -> bool:
       return _rewarded_loaded

   func show_rewarded() -> bool:
       # plugin show; relay user-earned reward to rewarded_granted
       return true
   ```

4. In `AdsManager`, prefer the real provider when available; keep the test provider
   only in debug builds.
5. Keep test ads while validating on devices. Set `AdConfig.TEST_MODE = false` only
   when production IDs are in place and tested.
6. Update privacy policy, store data-safety forms and consent flows before release.
7. For EEA/UK, integrate Google UMP (or an equivalent CMP). Do not request ads before
   consent is resolved.
8. For iOS personalized ads, add ATT and request permission before accessing the
   advertising identifier. If you do not personalize, request no tracking permission.
9. Test:
   - no fill / load failure → no button, game still fully playable;
   - dismiss → no reward, no crash;
   - reward → one revive, second death offers no continue;
   - background/foreground during an ad;
   - rotated/locked portrait;
   - low-end device memory.

### Interstitials

Disabled. If enabled later:

- only between runs, after the game-over screen has been dismissed or on restart;
- **never during gameplay**;
- at most once every **3 runs** and **150 seconds** (already encoded);
- never on the very first session;
- never block a player who cannot load an ad;
- always keep a visible path to play without watching;
- consider removing interstitials for anyone who purchases Remove Ads.

### Banners

Disabled. Do not place banners inside the playfield or behind buttons. If added,
reserve layout space so gameplay/UI does not shift, and never cover the score, pause
button or tap area.

---

## 5. In-app purchases (planned, inactive)

Catalog in `systems/monetization/monetization_manager.gd`:

| Product ID | Type | Planned price | Effect |
| --- | --- | --- | --- |
| `skin_aurora` | skin | €0.99 | Unlock Aurora skin |
| `skin_solar` | skin | €0.99 | Unlock Solar Flare skin |
| `skin_void` | skin | €0.99 | Unlock Voidwalker skin |
| `skin_pack_neon` | pack | €1.99 | Unlock all three premium skins |
| `remove_ads` | no_ads | €1.99 | Remove forced ads (rewarded stays optional) |

Rules:

- Prices are **planned only**. The store's localized price is authoritative.
- Use **Google Play Billing** and **StoreKit** through a maintained plugin/native
  bridge. Never implement a custom card processor.
- Validate/acknowledge purchases according to store rules; restore purchases on
  reinstall/device change.
- Grant content only after a verified transaction:
  - skins → `SaveManager.unlock_skin(id)` + select;
  - pack → unlock all included skins;
  - remove ads → persist an owned flag and skip interstitial/banner logic.
- Do not present a buy button until billing is configured and tested. The skins
  screen intentionally shows **COMING SOON** and disables premium cards.
- Remove Ads semantics are explicit: forced ads (interstitial/banner) are disabled;
  the optional rewarded revive remains available unless the product description says
  otherwise. Update the copy before shipping.
- Refunds/revocations should be reflected on next launch where the store API allows.

### Activation checklist

- [ ] Store products created with matching IDs.
- [ ] Billing plugin compatible with Godot 4.7.2.
- [ ] `Monetization.store_available = true`.
- [ ] `purchase()` implemented with real store calls.
- [ ] `restore_purchases()` implemented.
- [ ] UI switches premium skin cards from disabled to purchasable.
- [ ] Owned state saved and survives reload.
- [ ] Receipt validation plan (server-side recommended).
- [ ] Refund/restore tested.
- [ ] Store listings and disclosures updated.
- [ ] No fake success path remains.

---

## 6. Optional web support link

The user-facing support option is prepared as an external link:

```gdscript
# scripts/core/game_config.gd
const SUPPORT_URL := ""             # set to an itch.io/Ko-fi/other URL
const SUPPORT_LABEL := "SUPPORT THE DEVELOPER"
```

- While `SUPPORT_URL` is empty, the menu button is hidden (no dead button).
- When set, the menu shows **SUPPORT THE DEVELOPER** and opens the URL in a new tab
  (web) or the system browser (native).
- This is not a purchase, not required, and must not gate features.
- Itch.io project support pages are a good zero-backend option.

The game does not implement card payments or a web store.

---

## 7. Analytics for monetization

Current events:

- `rewarded_ad_requested` — player pressed the button (provider name only)
- `rewarded_ad_completed` — reward granted
- `rewarded_ad_failed` — dismissed/failed with a reason
- `revive_used` — gameplay-side confirmation, score/duration
- `interstitial_shown` — only when enabled
- `new_record`, `game_over`, `score_reached` — funnel context
- `combo_milestone`, `perfect_dodge`, `challenge_completed` — skill/replay signals

Daily challenges are local, free and score-only; they are not a purchasable product
and must never be sold as power.

No ad identifiers or personal data are logged. If a real analytics backend is added,
keep monetization events free of identifiers and disclose the provider in the privacy
policy.

---

## 8. Compliance checklist before enabling revenue

- [ ] Owner-approved ad network account and production IDs.
- [ ] Consent management (GDPR/UK GDPR/CCPA as applicable).
- [ ] Age rating / child-directed treatment decided.
- [ ] Privacy policy updated: ads, SDKs, data collection, retention, contact.
- [ ] App Store / Play data-safety disclosures updated.
- [ ] iOS ATT only if tracking/personalization is used.
- [ ] Ad content filters appropriate for the rating.
- [ ] No misleading “X” buttons, no ads disguised as game UI.
- [ ] No ads during gameplay, no forced full-screen ads on launch.
- [ ] Frequency caps tested.
- [ ] No-ad path always available.
- [ ] Real ads tested with test units before production.
- [ ] Revenue and refund flows monitored.
- [ ] Remove Ads and restore purchases tested on both stores.
- [ ] Analytics and crash reporting reviewed for PII.

Monetization is a product decision as much as a technical one. The current design
keeps it optional, transparent and removable so the launch can proceed without it.

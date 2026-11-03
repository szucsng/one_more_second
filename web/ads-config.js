/**
 * ONE MORE SECOND — web ad configuration.
 *
 * This file is copied verbatim into exports/web by tools/build_web.sh and is
 * public. Never put secrets here. AdSense publisher IDs are public identifiers.
 *
 * PRODUCTION REMAINS DISABLED until the owner approves the checklist in
 * docs/monetization.md. For local/test ad rendering:
 *   1. set enabled: true
 *   2. set adsenseClient to an approved AdSense client (or a test setup)
 *   3. set testMode: true while testing
 *   4. set consentGranted: true only after your CMP has obtained consent,
 *      or if your deployment does not require consent (verify with legal).
 *
 * The AdSense script is only injected when enabled is true and consent/host
 * checks pass. With the defaults below, no Google network request is made.
 */
window.OMS_ADS_CONFIG = {
  provider: "adsense_h5",

  // Master switch for the web bridge. Keep false in source control.
  enabled: false,

  // Your AdSense publisher ID, e.g. "ca-pub-1234567890123456".
  adsenseClient: "",

  // Use data-adbreak-test="on" with mock ads for QA. Never ship true.
  testMode: false,

  // Consent gate. Set consentGranted only after a certified CMP has resolved
  // the required consent (EEA/UK/CH) or after confirming it is not required.
  requireConsent: true,
  consentGranted: false,

  // Minimum average interval passed to the AdSense tag as a hint.
  frequencyHintSeconds: 120,

  // Interstitials stay disabled in v1.2 unless explicitly enabled and tested.
  interstitialEnabled: false,

  // Optional AdMob slots for an Android app WebView running this page. These
  // are NOT used by native Godot builds; those use the future native adapter.
  admobInterstitialSlot: "",
  admobRewardedSlot: "",

  // Refuse to load the ad script on non-HTTPS origins (except localhost).
  requireSecureContext: true,

  // Console diagnostics for QA; safe to leave false in production.
  debug: false,
};

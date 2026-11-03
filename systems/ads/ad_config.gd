class_name AdConfig
extends RefCounted
## Ad configuration and release safety switches.
##
## PRODUCTION ADS ARE DISABLED BY DEFAULT. Never enable this until the owner has
## supplied the provider account, IDs, consent handling and hosting approval.
##
## The web build uses Google AdSense H5 Games Ads (Ad Placement API) through the
## isolated bridge in web/ads-bridge.js. Native builds are prepared for a future
## AdMob adapter, but no native ad plugin is bundled.

## Master safety switch. Keep false until every production checklist item in
## docs/monetization.md is complete.
const PRODUCTION_ADS_ENABLED := false

## Development-only local simulation. Never shown in production web builds.
const MOCK_ADS_ENABLED := true
const ALLOW_MOCK_ON_WEB := false

## Formats controlled separately. Interstitials ship disabled by default.
const INTERSTITIAL_ENABLED := false
const BANNER_ENABLED := false
const INTERSTITIAL_MIN_RUNS := 3
const INTERSTITIAL_MIN_SECONDS := 150.0

## Timeouts keep a failed/blocked ad from trapping the player.
const REWARDED_READY_TIMEOUT := 6.0
const AD_CLOSE_TIMEOUT := 35.0
const INTERSTITIAL_TIMEOUT := 6.0

## Native AdMob placeholders. The adapter is not installed in v1.2.
## Native test mode must use Google's official sample units, never live units.
const NATIVE_TEST_MODE := true
const ADMOB_APP_ID := ""              # owner-supplied: ca-app-pub-...~...
const ADMOB_REWARDED_ID := ""         # owner-supplied: ca-app-pub-.../...
const ADMOB_INTERSTITIAL_ID := ""     # owner-supplied: ca-app-pub-.../...

const ADMOB_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const ADMOB_TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const ADMOB_TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const ADMOB_TEST_BANNER := "ca-app-pub-3940256099942544/6300978111"


static func is_production_enabled() -> bool:
	return PRODUCTION_ADS_ENABLED


static func native_app_id() -> String:
	if NATIVE_TEST_MODE or ADMOB_APP_ID.is_empty():
		return ADMOB_TEST_APP_ID
	return ADMOB_APP_ID


static func native_rewarded_id() -> String:
	if NATIVE_TEST_MODE or ADMOB_REWARDED_ID.is_empty():
		return ADMOB_TEST_REWARDED
	return ADMOB_REWARDED_ID


static func native_interstitial_id() -> String:
	if NATIVE_TEST_MODE or ADMOB_INTERSTITIAL_ID.is_empty():
		return ADMOB_TEST_INTERSTITIAL
	return ADMOB_INTERSTITIAL_ID


static func native_adapter_configured() -> bool:
	return not ADMOB_APP_ID.is_empty() \
		and not ADMOB_REWARDED_ID.is_empty() \
		and not ADMOB_INTERSTITIAL_ID.is_empty()

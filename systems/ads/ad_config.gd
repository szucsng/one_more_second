class_name AdConfig
extends RefCounted
## Ad configuration. The shipped v1 build only runs the clearly-labelled
## simulated provider: no network requests and no real ad units.
##
## Google's official TEST ids are listed here for the future AdMob adapter.
## They are safe to commit (they are not monetized) and MUST be replaced by the
## owner's production ids, together with the adapter, before release.

const USE_REAL_ADS := false
const TEST_MODE := true
## The web build ships without ads. Set this only for internal QA builds.
const ALLOW_TEST_ADS_ON_WEB := false
const INTERSTITIAL_ENABLED := false
const BANNER_ENABLED := false

const INTERSTITIAL_MIN_RUNS := 3
const INTERSTITIAL_MIN_SECONDS := 150.0

const ADMOB_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const ADMOB_TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const ADMOB_TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const ADMOB_TEST_BANNER := "ca-app-pub-3940256099942544/6300978111"

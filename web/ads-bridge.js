/**
 * ONE MORE SECOND — Google AdSense H5 Games Ads bridge.
 *
 * This file isolates all provider-specific JavaScript from the game. The Godot
 * provider talks only to `window.OMSAdsBridge`. All Google calls use the official
 * Ad Placement API (`adBreak`, `adConfig`) delivered by the AdSense tag.
 *
 * Production ads remain off until web/ads-config.js and the Godot master switch
 * are both enabled and the owner has completed the checklist in
 * docs/monetization.md.
 */
(function () {
  "use strict";

  const DEFAULTS = {
    provider: "adsense_h5",
    enabled: false,
    adsenseClient: "",
    testMode: false,
    requireConsent: true,
    consentGranted: false,
    frequencyHintSeconds: 120,
    interstitialEnabled: false,
    admobInterstitialSlot: "",
    admobRewardedSlot: "",
    requireSecureContext: true,
    debug: false,
  };

  const cfg = Object.assign({}, DEFAULTS, window.OMS_ADS_CONFIG || {});
  window.OMS_ADS_CONFIG = cfg;

  let godotCallback = null;
  let initialized = false;
  let adsenseRequested = false;
  let lastReason = "";

  let promptVisible = false;
  let pendingShowAd = null;
  let rewardedBusy = false;
  let rewardedShown = false;
  let rewardedEarned = false;
  let rewardedClosed = false;
  let rewardedTimer = null;
  let rewardedCloseTimer = null;
  let rewardedShowTimer = null;

  let interstitialBusy = false;
  let interstitialShown = false;
  let interstitialTimer = null;
  let interstitialCloseTimer = null;

  let soundOn = true;

  function log(...args) {
    if (cfg.debug) {
      console.log("[OMSAds]", ...args);
    }
  }

  function notify(type, data) {
    const payload = Object.assign({ type: type }, data || {});
    if (godotCallback) {
      try {
        godotCallback(JSON.stringify(payload));
      } catch (error) {
        console.error("[OMSAds] Godot callback failed:", error);
      }
    }
    log(type, payload);
  }

  function secureContext() {
    if (!cfg.requireSecureContext) {
      return true;
    }
    if (location.protocol === "https:") {
      return true;
    }
    return ["localhost", "127.0.0.1", "[::1]"].includes(location.hostname);
  }

  function eligibilityReason() {
    if (!cfg.enabled) return "ads_disabled";
    if (cfg.provider !== "adsense_h5") return "unsupported_provider";
    if (cfg.requireConsent && !cfg.consentGranted) return "consent_required";
    if (!cfg.adsenseClient) return "missing_adsense_client";
    if (!secureContext()) return "insecure_context";
    return "";
  }

  function getStatus() {
    const reason = eligibilityReason();
    return JSON.stringify({
      provider: cfg.provider,
      enabled: reason === "",
      configured: !!cfg.adsenseClient,
      consent: !cfg.requireConsent || !!cfg.consentGranted,
      test_mode: !!cfg.testMode,
      interstitial_supported: !!cfg.interstitialEnabled && reason === "",
      initialized: initialized,
      reason: reason || lastReason,
    });
  }

  function loadAdsense() {
    if (adsenseRequested) {
      return;
    }
    adsenseRequested = true;

    window.adsbygoogle = window.adsbygoogle || [];
    window.adBreak = window.adBreak || function (options) {
      window.adsbygoogle.push(options);
    };
    window.adConfig = window.adConfig || function (options) {
      window.adsbygoogle.push(options);
    };

    try {
      window.adConfig({
        preloadAdBreaks: "on",
        sound: soundOn ? "on" : "off",
        onReady: function () {
          notify("initialized", { success: true, reason: "api_ready" });
        },
      });
    } catch (error) {
      lastReason = "ad_config_exception";
      log("adConfig exception", error);
    }

    const script = document.createElement("script");
    script.async = true;
    script.crossOrigin = "anonymous";
    script.dataset.omsAdsense = "1";
    script.setAttribute("data-ad-client", cfg.adsenseClient);
    script.src = "https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=" +
      encodeURIComponent(cfg.adsenseClient);
    if (cfg.testMode) {
      script.setAttribute("data-adbreak-test", "on");
    }
    if (cfg.frequencyHintSeconds > 0) {
      script.setAttribute("data-ad-frequency-hint", String(cfg.frequencyHintSeconds) + "s");
    }
    if (cfg.admobInterstitialSlot) {
      script.setAttribute("data-admob-interstitial-slot", cfg.admobInterstitialSlot);
    }
    if (cfg.admobRewardedSlot) {
      script.setAttribute("data-admob-rewarded-slot", cfg.admobRewardedSlot);
    }
    script.onerror = function () {
      lastReason = "adsense_script_failed";
      notify("failed", { format: "rewarded", reason: "adsense_script_failed" });
    };
    document.head.appendChild(script);
  }

  function init() {
    const reason = eligibilityReason();
    if (reason) {
      lastReason = reason;
      notify("initialized", { success: false, reason: reason });
      return false;
    }
    if (initialized) {
      notify("initialized", { success: true, reason: "already_initialized" });
      return true;
    }
    loadAdsense();
    initialized = true;
    notify("initialized", { success: true, reason: "pending_api" });
    return true;
  }

  // ---- Reward prompt DOM -------------------------------------------------

  let promptBuilt = false;

  function buildPrompt() {
    if (promptBuilt) {
      return;
    }
    promptBuilt = true;

    const style = document.createElement("style");
    style.textContent = `
      #oms-reward-prompt {
        position: fixed;
        inset: 0;
        z-index: 9999;
        display: none;
        align-items: center;
        justify-content: center;
        padding: max(24px, env(safe-area-inset-top)) 24px max(24px, env(safe-area-inset-bottom));
        background: rgba(5, 5, 5, 0.82);
        font-family: "OMS Rajdhani", "Rajdhani", "Avenir Next", "Segoe UI", system-ui, sans-serif;
        color: #ffffff;
      }
      #oms-reward-prompt[data-visible="true"] { display: flex; }
      #oms-reward-card {
        width: min(520px, 86vw);
        box-sizing: border-box;
        padding: 32px;
        border: 1px solid rgba(0, 245, 255, 0.35);
        border-radius: 24px;
        background: #0c0c0c;
        box-shadow: 0 0 60px rgba(0, 245, 255, 0.12), 0 24px 80px rgba(0, 0, 0, 0.7);
        text-align: center;
      }
      #oms-reward-kicker {
        margin: 0 0 8px;
        color: #00f5ff;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.32em;
        text-transform: uppercase;
      }
      #oms-reward-title {
        margin: 0 0 8px;
        font-size: clamp(28px, 6vw, 42px);
        line-height: 1;
        font-weight: 800;
        letter-spacing: 0.06em;
        text-transform: uppercase;
      }
      #oms-reward-body {
        margin: 0 0 24px;
        color: #b9b9b9;
        font-size: 15px;
        line-height: 1.45;
      }
      #oms-reward-test {
        display: none;
        margin: 0 0 14px;
        color: #ffc857;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.24em;
        text-transform: uppercase;
      }
      #oms-reward-watch, #oms-reward-decline {
        display: block;
        width: 100%;
        box-sizing: border-box;
        border-radius: 12px;
        padding: 15px 18px;
        font: inherit;
        font-size: 14px;
        font-weight: 800;
        letter-spacing: 0.12em;
        text-transform: uppercase;
        cursor: pointer;
      }
      #oms-reward-watch {
        color: #050505;
        background: #00f5ff;
        border: 1px solid #00f5ff;
        box-shadow: 0 0 28px rgba(0, 245, 255, 0.35);
        margin-bottom: 10px;
      }
      #oms-reward-watch:hover { background: #7dfbff; }
      #oms-reward-decline {
        color: #858585;
        background: transparent;
        border: 1px solid rgba(255, 255, 255, 0.12);
      }
      #oms-reward-decline:hover { color: #ffffff; border-color: rgba(255, 255, 255, 0.35); }
      #oms-reward-watch:focus-visible, #oms-reward-decline:focus-visible {
        outline: 2px solid #00f5ff;
        outline-offset: 3px;
      }
    `;
    document.head.appendChild(style);

    const overlay = document.createElement("div");
    overlay.id = "oms-reward-prompt";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.setAttribute("aria-labelledby", "oms-reward-title");
    overlay.innerHTML = `
      <div id="oms-reward-card">
        <p id="oms-reward-kicker">OPTIONAL REWARDED AD</p>
        <p id="oms-reward-test">TEST AD — NO REAL AD IS SHOWN</p>
        <h2 id="oms-reward-title">CONTINUE THIS RUN?</h2>
        <p id="oms-reward-body">Watch a short ad to revive once. Your score and record are already saved. You can always restart without an ad.</p>
        <button id="oms-reward-watch" type="button">WATCH AD — CONTINUE</button>
        <button id="oms-reward-decline" type="button">NO THANKS</button>
      </div>
    `;
    document.body.appendChild(overlay);

    document.getElementById("oms-reward-watch").addEventListener("click", watchReward);
    document.getElementById("oms-reward-decline").addEventListener("click", declineReward);
    document.addEventListener("keydown", function (event) {
      if (!promptVisible) {
        return;
      }
      if (event.key === "Escape") {
        event.preventDefault();
        declineReward();
        return;
      }
      if (event.key === "Tab") {
        // Keep focus inside the modal while it is open.
        event.preventDefault();
        const watch = document.getElementById("oms-reward-watch");
        const decline = document.getElementById("oms-reward-decline");
        if (!watch || !decline) return;
        if (document.activeElement === watch) {
          decline.focus();
        } else {
          watch.focus();
        }
      }
    });
  }

  function showPrompt() {
    buildPrompt();
    const overlay = document.getElementById("oms-reward-prompt");
    const testLabel = document.getElementById("oms-reward-test");
    if (testLabel) {
      testLabel.style.display = cfg.testMode ? "block" : "none";
    }
    promptVisible = true;
    overlay.setAttribute("data-visible", "true");
    const watch = document.getElementById("oms-reward-watch");
    if (watch) {
      window.setTimeout(function () { watch.focus(); }, 20);
    }
  }

  function hidePrompt() {
    promptVisible = false;
    const overlay = document.getElementById("oms-reward-prompt");
    if (overlay) {
      overlay.setAttribute("data-visible", "false");
    }
  }

  // ---- Rewarded ads ------------------------------------------------------

  function clearRewardedTimers() {
    if (rewardedTimer) {
      clearTimeout(rewardedTimer);
      rewardedTimer = null;
    }
    if (rewardedShowTimer) {
      clearTimeout(rewardedShowTimer);
      rewardedShowTimer = null;
    }
    if (rewardedCloseTimer) {
      clearTimeout(rewardedCloseTimer);
      rewardedCloseTimer = null;
    }
  }

  function finishRewarded() {
    clearRewardedTimers();
    rewardedBusy = false;
    rewardedShown = false;
    rewardedEarned = false;
    rewardedClosed = false;
    pendingShowAd = null;
    hidePrompt();
  }

  function requestRewarded() {
    if (!initialized) {
      const started = init();
      if (!started) {
        notify("rewarded_ready", { available: false, reason: eligibilityReason() || "not_initialized" });
        return false;
      }
    }
    const reason = eligibilityReason();
    if (reason) {
      notify("rewarded_ready", { available: false, reason: reason });
      return false;
    }
    if (promptVisible) {
      notify("rewarded_ready", { available: true, reason: "prompt_already_open" });
      return true;
    }
    if (rewardedBusy) {
      notify("rewarded_ready", { available: false, reason: "busy" });
      return false;
    }

    rewardedBusy = true;
    rewardedShown = false;
    rewardedEarned = false;
    rewardedClosed = false;
    let promptArrived = false;
    let breakDone = false;

    rewardedTimer = window.setTimeout(function () {
      if (rewardedBusy && !promptArrived && !rewardedShown) {
        notify("rewarded_ready", { available: false, reason: "timeout" });
        notify("failed", { format: "rewarded", reason: "prompt_timeout" });
        finishRewarded();
      }
    }, 6000);

    try {
      window.adBreak({
        type: "reward",
        name: "continue_run",
        beforeReward: function (showAdFn) {
          if (!rewardedBusy || promptArrived) {
            return;
          }
          promptArrived = true;
          pendingShowAd = function () { showAdFn(); };
          showPrompt();
          notify("rewarded_ready", { available: true, reason: "prompt" });
        },
        beforeAd: function () {
          if (!rewardedBusy) return;
          hidePrompt();
          rewardedShown = true;
          notify("rewarded_shown");
          rewardedCloseTimer = window.setTimeout(function () {
            if (rewardedBusy && rewardedShown) {
              notify("rewarded_dismissed", { reason: "close_timeout" });
              notify("rewarded_closed");
              finishRewarded();
            }
          }, 36000);
        },
        adViewed: function () {
          if (!rewardedBusy) return;
          rewardedEarned = true;
          notify("reward_earned");
        },
        adDismissed: function () {
          if (!rewardedBusy) return;
          notify("rewarded_dismissed", { reason: "ad_dismissed" });
        },
        afterAd: function () {
          if (!rewardedBusy) return;
          if (!rewardedClosed) {
            rewardedClosed = true;
            notify("rewarded_closed");
          }
          finishRewarded();
        },
        adBreakDone: function (placementInfo) {
          breakDone = true;
          const status = placementInfo && placementInfo.breakStatus ? String(placementInfo.breakStatus) : "no_fill";
          log("rewarded adBreakDone", status);
          if (!promptArrived && !rewardedShown) {
            notify("rewarded_ready", { available: false, reason: "no_fill" });
            notify("failed", { format: "rewarded", reason: status });
            finishRewarded();
          }
        },
      });
    } catch (error) {
      log("rewarded adBreak exception", error);
      notify("rewarded_ready", { available: false, reason: "adbreak_exception" });
      notify("failed", { format: "rewarded", reason: "adbreak_exception" });
      finishRewarded();
      return false;
    }

    // Nothing to wait for if the API immediately reported no fill.
    if (breakDone && !rewardedBusy) {
      return false;
    }
    return true;
  }

  function watchReward() {
    if (!rewardedBusy) {
      return;
    }
    if (!pendingShowAd) {
      notify("failed", { format: "rewarded", reason: "show_not_ready" });
      notify("rewarded_closed");
      finishRewarded();
      return;
    }
    const showAd = pendingShowAd;
    pendingShowAd = null;
    hidePrompt();
    rewardedShowTimer = window.setTimeout(function () {
      if (rewardedBusy && !rewardedShown) {
        notify("rewarded_dismissed", { reason: "ad_did_not_start" });
        notify("rewarded_closed");
        finishRewarded();
      }
    }, 6000);
    try {
      showAd();
    } catch (error) {
      log("showAdFn exception", error);
      notify("failed", { format: "rewarded", reason: "show_exception" });
      notify("rewarded_closed");
      finishRewarded();
    }
  }

  function declineReward() {
    if (!rewardedBusy) {
      return;
    }
    hidePrompt();
    pendingShowAd = null;
    notify("rewarded_ready", { available: false, reason: "prompt_declined" });
    notify("rewarded_dismissed", { reason: "prompt_declined" });
    finishRewarded();
  }

  function cancelRewardedPrompt() {
    hidePrompt();
    pendingShowAd = null;
    if (rewardedBusy && !rewardedShown) {
      notify("rewarded_ready", { available: false, reason: "cancelled" });
      finishRewarded();
    }
  }

  function showRewarded() {
    if (!pendingShowAd) {
      notify("failed", { format: "rewarded", reason: "show_not_ready" });
      return false;
    }
    watchReward();
    return true;
  }

  // ---- Interstitials -----------------------------------------------------

  function clearInterstitialTimers() {
    if (interstitialTimer) {
      clearTimeout(interstitialTimer);
      interstitialTimer = null;
    }
    if (interstitialCloseTimer) {
      clearTimeout(interstitialCloseTimer);
      interstitialCloseTimer = null;
    }
  }

  function finishInterstitial(shown) {
    if (!interstitialBusy) {
      return;
    }
    interstitialBusy = false;
    interstitialShown = false;
    clearInterstitialTimers();
    notify("interstitial_closed", { shown: !!shown });
  }

  function showInterstitial() {
    if (!initialized) {
      init();
    }
    if (!initialized || eligibilityReason() || !cfg.interstitialEnabled) {
      notify("interstitial_closed", { shown: false });
      return false;
    }
    if (interstitialBusy || rewardedBusy) {
      notify("interstitial_closed", { shown: false });
      return false;
    }
    interstitialBusy = true;
    interstitialShown = false;
    let terminated = false;
    const done = function (shown) {
      if (terminated) return;
      terminated = true;
      finishInterstitial(shown);
    };

    interstitialTimer = window.setTimeout(function () {
      done(false);
    }, 6000);

    try {
      window.adBreak({
        type: "next",
        name: "between_runs",
        beforeAd: function () {
          if (terminated) return;
          interstitialShown = true;
          if (interstitialTimer) {
            clearTimeout(interstitialTimer);
            interstitialTimer = null;
          }
          notify("interstitial_shown");
          interstitialCloseTimer = window.setTimeout(function () {
            done(false);
          }, 36000);
        },
        afterAd: function () {
          done(true);
        },
        adBreakDone: function (placementInfo) {
          if (!interstitialShown) {
            log("interstitial adBreakDone", placementInfo);
            done(false);
          }
        },
      });
    } catch (error) {
      log("interstitial adBreak exception", error);
      notify("failed", { format: "interstitial", reason: "adbreak_exception" });
      done(false);
      return false;
    }
    return true;
  }

  // ---- Public bridge -----------------------------------------------------

  window.OMSAdsBridge = {
    setGodotCallback: function (callback) {
      godotCallback = callback;
      log("Godot callback registered");
    },
    init: init,
    getStatus: getStatus,
    requestRewarded: requestRewarded,
    showRewarded: showRewarded,
    cancelRewardedPrompt: cancelRewardedPrompt,
    showInterstitial: showInterstitial,
    setSound: function (enabled) {
      soundOn = !!enabled;
      if (initialized) {
        try {
          window.adConfig({ sound: soundOn ? "on" : "off" });
        } catch (error) {
          log("adConfig sound exception", error);
        }
      }
    },
    setConsent: function (granted) {
      cfg.consentGranted = !!granted;
      if (cfg.consentGranted && !initialized) {
        init();
      }
    },
    getConfig: function () {
      return JSON.stringify(cfg);
    },
  };

  log("bridge loaded", getStatus());
})();

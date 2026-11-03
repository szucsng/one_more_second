class_name AdPolicy
extends RefCounted
## Pure ad frequency policy, kept separate for deterministic testing.


static func can_show_interstitial(
	enabled: bool,
	runs_since_last: int,
	last_unix: float,
	now_unix: float,
	min_runs: int,
	min_seconds: float
) -> bool:
	if not enabled:
		return false
	if runs_since_last < maxi(0, min_runs):
		return false
	if last_unix > 0.0 and now_unix - last_unix < maxf(0.0, min_seconds):
		return false
	return true


static func seconds_until_interstitial(
	runs_since_last: int,
	last_unix: float,
	now_unix: float,
	min_runs: int,
	min_seconds: float
) -> float:
	var run_wait := maxi(0, min_runs) - runs_since_last
	if run_wait > 0:
		return float(run_wait)
	if last_unix <= 0.0:
		return 0.0
	return maxf(0.0, min_seconds - (now_unix - last_unix))

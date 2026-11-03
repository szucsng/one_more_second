extends Control
## Core gameplay state machine.
##
## States: RUNNING -> DYING -> GAME_OVER, plus PAUSED and AD (the simulated
## rewarded placement). The tree is never globally paused, which keeps audio,
## analytics and the test-ad overlay responsive on every platform.

enum State { RUNNING, PAUSED, DYING, GAME_OVER, AD }

const SWITCH_KEYS := [
	KEY_SPACE, KEY_W, KEY_UP, KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT,
]

@onready var backdrop: NeonBackdrop = %Backdrop
@onready var world: Node2D = %World
@onready var spawner: ObstacleSpawner = %Spawner
@onready var player: PlayerShip = %Player
@onready var effects: ParticleFX = %Effects
@onready var hud: GameHUD = %HUD
@onready var pause_panel: PausePanelScreen = %PausePanel
@onready var game_over: GameOverScreen = %GameOver

var state: State = State.RUNNING
var score: int = 0
var elapsed: float = 0.0
var revive_used: bool = false
var combo: int = 0
var max_combo: int = 0
var dodges: int = 0
var perfect_dodges: int = 0

var _shake: float = 0.0
var _run_finalized: bool = false
var _ad_pending: bool = false
var _next_milestone: int = 10
var _last_switch_msec: int = -1000
var _last_survival_second: int = -1
var _reduced_effects: bool = false


func _ready() -> void:
	hud.pause_pressed.connect(pause_game)
	player.died.connect(_on_player_died)
	player.lane_changed.connect(_on_lane_changed)
	spawner.obstacle_passed.connect(_on_obstacle_passed)
	pause_panel.resume_pressed.connect(resume_game)
	pause_panel.restart_pressed.connect(_restart_from_pause)
	pause_panel.menu_pressed.connect(_menu_from_pause)
	game_over.restart_pressed.connect(_restart_from_game_over)
	game_over.menu_pressed.connect(_menu_from_game_over)
	game_over.continue_pressed.connect(_request_continue)
	Ads.rewarded_granted.connect(_on_ad_rewarded)
	Ads.rewarded_dismissed.connect(_on_ad_dismissed)
	spawner.recovery_started.connect(_on_recovery_started)
	Challenges.challenge_completed.connect(_on_challenge_completed)
	_reduced_effects = bool(SaveManager.get_setting("reduced_effects"))
	_start_new_run()


func _start_new_run() -> void:
	Challenges.refresh_daily()
	state = State.RUNNING
	score = 0
	combo = 0
	max_combo = 0
	dodges = 0
	perfect_dodges = 0
	elapsed = 0.0
	revive_used = false
	_run_finalized = false
	_ad_pending = false
	_next_milestone = 10
	_last_survival_second = -1
	_shake = 0.0
	world.position = Vector2.ZERO
	spawner.start()
	player.reset_for_run()
	pause_panel.close()
	game_over.hide_result()
	hud.set_score(0, false)
	hud.set_best(SaveManager.get_best_score())
	hud.set_combo(0, 1, 0.0)
	hud.set_daily_progress(Challenges.get_completed_count(), Challenges.get_total_count())
	hud.set_pause_enabled(true)
	hud.play_intro()
	Analytics.track("game_started", {"revive": false})


func _process(delta: float) -> void:
	if state == State.RUNNING:
		elapsed += delta
		var whole_second := int(elapsed)
		if whole_second != _last_survival_second:
			_last_survival_second = whole_second
			Challenges.record_survival(elapsed)
	var target_scroll := 26.0
	if state == State.RUNNING:
		target_scroll = 34.0 + (spawner.speed - Difficulty.START_SPEED) * 0.13
	backdrop.scroll_speed = lerpf(backdrop.scroll_speed, target_scroll, clampf(delta * 3.0, 0.0, 1.0))

	if _shake > 0.12:
		_shake *= exp(-7.0 * delta)
		world.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		_shake = 0.0
		world.position = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_P:
			match state:
				State.RUNNING:
					pause_game()
				State.PAUSED:
					resume_game()
				State.GAME_OVER:
					_menu_from_game_over()
			get_viewport().set_input_as_handled()
			return
		if SWITCH_KEYS.has(key_event.keycode) and state == State.RUNNING:
			_switch_lane()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and state == State.RUNNING:
		_switch_lane()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and state == State.RUNNING:
			_switch_lane()
			get_viewport().set_input_as_handled()


func _add_shake(amount: float) -> void:
	if _reduced_effects:
		return
	_shake = maxf(_shake, amount)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if state == State.RUNNING:
				pause_game()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			match state:
				State.RUNNING:
					pause_game()
				State.PAUSED:
					resume_game()
				State.GAME_OVER:
					_menu_from_game_over()
		NOTIFICATION_WM_CLOSE_REQUEST:
			if not _run_finalized:
				_finalize_run(state != State.GAME_OVER)


func _switch_lane() -> void:
	# Touch emulation can also deliver a synthetic mouse click for the same tap.
	# A short debounce prevents a double lane switch without hurting real input.
	var now := Time.get_ticks_msec()
	if now - _last_switch_msec < 90:
		return
	_last_switch_msec = now
	var previous_lane := player.lane
	player.switch_lane()
	if player.lane == previous_lane:
		return
	AudioManager.play_switch()
	var skin := SkinManager.get_selected()
	effects.emit_sparks(player.global_position + Vector2(0, 44), skin.get("primary", Palette.CYAN), 5)
	_add_shake(2.0)
	Platform.vibrate(8)
	hud.hide_hint()
	_check_perfect_dodge(previous_lane)


func _on_lane_changed(_lane: int, _from_lane: int) -> void:
	hud.hide_hint()


func _on_obstacle_passed(obstacle: Obstacle) -> void:
	if state != State.RUNNING:
		return
	dodges += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	var multiplier := Scoring.multiplier_for(combo)
	score += Scoring.obstacle_points(combo)
	hud.set_score(score)
	hud.set_combo(combo, multiplier, Scoring.combo_progress(combo))

	var skin_color: Color = SkinManager.get_selected().get("primary", Palette.CYAN)
	effects.emit_sparks(Vector2(obstacle.position.x, Palette.PLAYER_Y - 20), skin_color, 6)
	_add_shake(1.6)
	if obstacle.perfect_pending and not obstacle.perfect_awarded:
		_award_perfect_dodge(obstacle)

	if Scoring.is_milestone(combo):
		AudioManager.play_sfx("combo_milestone", -4.0)
		hud.flash_combo_milestone(combo, multiplier)
		effects.emit_burst(player.global_position, Palette.GOLD, 18, 380.0, 0.55)
		effects.emit_ring(player.global_position, Palette.GOLD, 150.0, 0.5)
		_add_shake(4.5)
		Analytics.track("combo_milestone", {"combo": combo, "multiplier": multiplier})
	else:
		AudioManager.play_score()

	Challenges.record_dodge()
	Challenges.record_combo(combo)
	Challenges.record_score(score)

	while score >= _next_milestone:
		Analytics.track("score_reached", {"score": score})
		_next_milestone += 10


func _check_perfect_dodge(previous_lane: int) -> void:
	if state != State.RUNNING or previous_lane == player.lane or player.is_invulnerable():
		return
	var obstacles := spawner.get_active_obstacles()
	var candidate: Obstacle = null
	var best_time := INF
	for obstacle in obstacles:
		if obstacle.lane != previous_lane or obstacle.perfect_awarded:
			continue
		var distance := player.global_position.y - obstacle.global_position.y
		if distance < -55.0:
			continue
		var time_to_hit := distance / maxf(1.0, obstacle.speed)
		if time_to_hit < 0.0 or time_to_hit > Scoring.PERFECT_WINDOW:
			continue
		if time_to_hit < best_time:
			best_time = time_to_hit
			candidate = obstacle
	if candidate == null or best_time < Scoring.PERFECT_MIN_TIME:
		return

	# The new lane must actually be safe; do not reward a switch into another
	# imminent obstacle.
	for obstacle in obstacles:
		if obstacle.lane != player.lane:
			continue
		var distance := player.global_position.y - obstacle.global_position.y
		if distance < -55.0:
			continue
		var time_to_hit := distance / maxf(1.0, obstacle.speed)
		if time_to_hit <= Scoring.PERFECT_WINDOW + 0.08:
			return

	# Mark the narrowly avoided obstacle. The bonus is confirmed when it passes:
	# a late switch that ends in a collision never earns a perfect dodge.
	candidate.perfect_pending = true


func _award_perfect_dodge(obstacle: Obstacle) -> void:
	if obstacle.perfect_awarded or not obstacle.perfect_pending:
		return
	obstacle.perfect_awarded = true
	obstacle.perfect_pending = false
	perfect_dodges += 1
	score += Scoring.PERFECT_BONUS
	hud.set_score(score)
	hud.show_perfect_dodge(Scoring.PERFECT_BONUS)
	var skin_color: Color = SkinManager.get_selected().get("primary", Palette.CYAN)
	effects.emit_ring(player.global_position, Palette.CYAN, 190.0, 0.45)
	effects.emit_burst(player.global_position, skin_color, 14, 300.0, 0.45)
	_add_shake(3.0)
	AudioManager.play_sfx("perfect_dodge", -3.0)
	Platform.vibrate(12)
	Challenges.record_perfect()
	Challenges.record_score(score)
	Analytics.track("perfect_dodge", {
		"combo": combo,
		"score": score,
	})


func _on_recovery_started() -> void:
	if state == State.RUNNING:
		hud.show_recovery()


func _on_challenge_completed(challenge: Dictionary) -> void:
	var reward := maxi(0, int(challenge.get("reward", 0)))
	score += reward
	hud.set_score(score)
	hud.set_daily_progress(Challenges.get_completed_count(), Challenges.get_total_count())
	hud.show_challenge_complete(String(challenge.get("title", "DAILY")), reward)
	effects.emit_ring(player.global_position, Palette.GOLD, 210.0, 0.6)
	effects.emit_burst(player.global_position, Palette.GOLD, 18, 340.0, 0.6)
	_add_shake(4.0)
	AudioManager.play_sfx("challenge_complete", -3.0)
	Platform.vibrate(18)
	Analytics.track("challenge_completed", {
		"id": String(challenge.get("id", "")),
		"type": String(challenge.get("type", "")),
		"reward": reward,
	})


func _on_player_died() -> void:
	if state != State.RUNNING:
		return
	state = State.DYING
	spawner.stop()
	combo = 0
	hud.set_combo(0, 1, 0.0)
	hud.set_pause_enabled(false)
	hud.hide_hint()
	AudioManager.play_sfx("game_over", -3.0)
	Platform.vibrate(45)
	_add_shake(26.0)
	var burst_color: Color = SkinManager.get_selected().get("primary", Palette.CYAN)
	effects.emit_burst(player.global_position, burst_color, 34, 620.0, 0.9)
	effects.emit_burst(player.global_position, Palette.PINK, 16, 420.0, 0.8)
	effects.emit_ring(player.global_position, burst_color, 220.0, 0.7)
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	_show_game_over()


func _show_game_over() -> void:
	state = State.GAME_OVER
	var saved_best := SaveManager.get_best_score()
	var is_record := score > saved_best
	var best := maxi(saved_best, score)
	var can_continue := not revive_used and Ads.is_rewarded_available()
	game_over.show_result(
		score, best, is_record, elapsed, GameConfig.rank_for(score), can_continue,
		max_combo, perfect_dodges
	)
	hud.set_pause_enabled(false)


func _record_completed_run() -> void:
	_finalize_run(false)


func _finalize_run(abandoned: bool) -> void:
	if _run_finalized:
		return
	_run_finalized = true
	var previous_best := SaveManager.get_best_score()
	var is_record := score > previous_best
	SaveManager.record_run(score, elapsed, dodges, max_combo, perfect_dodges)
	Analytics.track("score_reached", {"score": score})
	Analytics.track("game_over", {
		"score": score,
		"duration": snappedf(elapsed, 0.1),
		"obstacles": dodges,
		"max_combo": max_combo,
		"perfect_dodges": perfect_dodges,
		"challenges_completed": Challenges.get_completed_count(),
		"abandoned": abandoned,
		"new_record": is_record,
		"revived": revive_used,
	})
	if is_record:
		Analytics.track("new_record", {"score": score})


func pause_game() -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	spawner.set_frozen(true)
	player.set_active(false)
	hud.set_pause_enabled(false)
	pause_panel.open(score)
	AudioManager.play_sfx("pause", -4.0)
	Platform.vibrate(10)


func resume_game() -> void:
	if state != State.PAUSED:
		return
	state = State.RUNNING
	spawner.set_frozen(false)
	player.set_active(true)
	pause_panel.close()
	hud.set_pause_enabled(true)


func _restart_from_pause() -> void:
	pause_panel.close()
	_finalize_run(true)
	_start_new_run()


func _menu_from_pause() -> void:
	pause_panel.close()
	_finalize_run(true)
	SceneRouter.go_menu()


func _restart_from_game_over() -> void:
	_record_completed_run()
	_start_new_run()


func _menu_from_game_over() -> void:
	_record_completed_run()
	SceneRouter.go_menu()


func _request_continue() -> void:
	if state != State.GAME_OVER or revive_used:
		return
	if not Ads.show_rewarded():
		return
	_ad_pending = true
	state = State.AD
	spawner.set_frozen(true)
	player.set_active(false)
	game_over.set_buttons_enabled(false)
	hud.set_pause_enabled(false)


func _on_ad_rewarded() -> void:
	if not _ad_pending:
		return
	_ad_pending = false
	revive_used = true
	state = State.RUNNING
	game_over.hide_result()
	player.revive()
	spawner.revive_cleanup(maxf(6.0, spawner.elapsed - 7.0))
	AudioManager.play_sfx("revive", -2.0)
	Platform.vibrate(28)
	effects.emit_ring(player.global_position, Palette.CYAN, 260.0, 0.8)
	effects.emit_burst(player.global_position, Palette.CYAN, 22, 420.0, 0.7)
	hud.set_pause_enabled(true)
	Analytics.track("revive_used", {"score": score, "duration": snappedf(elapsed, 0.1)})


func _on_ad_dismissed() -> void:
	if not _ad_pending:
		return
	_ad_pending = false
	state = State.GAME_OVER
	game_over.set_buttons_enabled(true)
	game_over.refresh_continue_visibility(not revive_used and Ads.is_rewarded_available())
	hud.set_pause_enabled(false)

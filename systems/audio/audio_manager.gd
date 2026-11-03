extends Node
## Audio routing, pooled SFX playback and the looping music bed.
##
## Buses are created at runtime so the project works without a hand-authored
## bus layout. All streams are procedurally generated (see tools/generate_audio.py).

const SFX_PATHS := {
	"tap": "res://assets/sounds/ui_tap.wav",
	"switch": "res://assets/sounds/lane_switch.wav",
	"score": "res://assets/sounds/score.wav",
	"game_over": "res://assets/sounds/game_over.wav",
	"record": "res://assets/sounds/new_record.wav",
	"revive": "res://assets/sounds/revive.wav",
	"pause": "res://assets/sounds/pause.wav",
	"heartbeat": "res://assets/sounds/heartbeat.wav",
}
const MUSIC_PATH := "res://assets/music/neon_drive.ogg"
const SFX_POOL_SIZE := 10

var _sfx_streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_stream: AudioStream
var _unlocked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music", "Master")
	_ensure_bus("SFX", "Master")
	for key: String in SFX_PATHS:
		if ResourceLoader.exists(SFX_PATHS[key]):
			_sfx_streams[key] = load(SFX_PATHS[key])
		else:
			push_warning("AudioManager: missing sound '%s'." % SFX_PATHS[key])

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	if ResourceLoader.exists(MUSIC_PATH):
		_music_stream = load(MUSIC_PATH)
		if _music_stream is AudioStreamOggVorbis:
			(_music_stream as AudioStreamOggVorbis).loop = true
		elif _music_stream is AudioStreamWAV:
			(_music_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_music_player.stream = _music_stream

	SaveManager.settings_changed.connect(_apply_settings)
	_apply_settings()
	if bool(SaveManager.get_setting("music")):
		_start_music()


func _ensure_bus(bus_name: String, send: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send)


func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey:
		_unlocked = true
		if bool(SaveManager.get_setting("music")) and not _music_player.playing:
			_start_music()


func _apply_settings() -> void:
	var volume := clampf(float(SaveManager.get_setting("volume")), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(music_bus, not bool(SaveManager.get_setting("music")))
	AudioServer.set_bus_mute(sfx_bus, not bool(SaveManager.get_setting("sfx")))
	AudioServer.set_bus_volume_db(music_bus, -5.0)
	if bool(SaveManager.get_setting("music")):
		if not _music_player.playing:
			_start_music()
	else:
		_music_player.stop()


func _start_music() -> void:
	if _music_player.stream == null:
		return
	_music_player.volume_db = -2.0
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func restart_music() -> void:
	_music_player.stop()
	if bool(SaveManager.get_setting("music")):
		_start_music()


func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not bool(SaveManager.get_setting("sfx")):
		return
	if not _sfx_streams.has(sfx_name):
		return
	var chosen: AudioStreamPlayer = null
	for player in _sfx_players:
		if not player.playing:
			chosen = player
			break
	if chosen == null:
		chosen = _sfx_players[0]
	chosen.stream = _sfx_streams[sfx_name]
	chosen.volume_db = volume_db
	chosen.pitch_scale = maxf(0.05, pitch * randf_range(0.97, 1.03))
	chosen.play()


func play_ui_tap() -> void:
	play_sfx("tap", -4.0)


func play_switch() -> void:
	play_sfx("switch", -6.0)


func play_score() -> void:
	play_sfx("score", -16.0)


func set_music_paused(paused: bool) -> void:
	if paused:
		_music_player.stream_paused = true
	else:
		_music_player.stream_paused = false

extends CanvasLayer
## Clearly-labelled simulated rewarded ad used while the real AdMob adapter is
## not installed. No network, no identifiers, no tracking. Always dismissible.

signal completed
signal dismissed

const DURATION := 5.0

@onready var progress: ProgressBar = %Progress
@onready var countdown_label: Label = %CountdownLabel
@onready var claim_button: Button = %ClaimButton
@onready var close_button: Button = %CloseButton

var _remaining: float = DURATION
var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	progress.max_value = DURATION
	progress.value = DURATION
	claim_button.disabled = true
	claim_button.pressed.connect(_on_claim)
	close_button.pressed.connect(_on_close)
	_update_labels()


func _process(delta: float) -> void:
	if _done:
		return
	_remaining = maxf(0.0, _remaining - delta)
	progress.value = _remaining
	_update_labels()
	if _remaining <= 0.0:
		claim_button.disabled = false
		set_process(false)


func _update_labels() -> void:
	if _remaining > 0.0:
		countdown_label.text = "REWARD IN %d" % int(ceil(_remaining))
		claim_button.text = "CLAIM REWARD"
	else:
		countdown_label.text = "REWARD READY"
		claim_button.text = "CLAIM REWARD"


func _on_claim() -> void:
	if _done or _remaining > 0.0:
		return
	_done = true
	completed.emit()


func _on_close() -> void:
	if _done:
		return
	_done = true
	dismissed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_on_close()
		get_viewport().set_input_as_handled()

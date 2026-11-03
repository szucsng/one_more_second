extends Control
## Application shell: hosts the active screen and applies platform settings.

@onready var screen_container: Control = $ScreenContainer


func _ready() -> void:
	DisplayServer.window_set_title(GameConfig.GAME_NAME)
	SceneRouter.attach(screen_container)
	Platform.apply_saved_display_settings()
	SceneRouter.change_screen(SceneRouter.MENU_SCENE, false)

extends Node
## Manual visual QA harness. Boots the real app, visits every screen and saves
## PNG screenshots under tests/artifacts/.
##   godot --path . --resolution 1080x1920 res://tests/VisualCheck.tscn

const OUT_DIR := "res://tests/artifacts"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore_file := FileAccess.open("%s/.gdignore" % OUT_DIR, FileAccess.WRITE)
	if ignore_file != null:
		ignore_file.close()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await _wait(1.2)
	await _shot("01_menu")

	SceneRouter.go_settings()
	await _wait(0.8)
	await _shot("02_settings")

	SceneRouter.go_menu()
	await _wait(0.6)
	SceneRouter.go_skins()
	await _wait(0.9)
	await _shot("03_skins")

	SceneRouter.go_menu()
	await _wait(0.6)
	SceneRouter.go_stats()
	await _wait(1.1)
	await _shot("04_statistics")
	var stats_screen := SceneRouter.get_current_screen()
	if stats_screen != null:
		var stats_grid := stats_screen.get_node_or_null("%Grid") as GridContainer
		if stats_grid != null:
			print("STATS GRID size=", stats_grid.size, " min=", stats_grid.get_combined_minimum_size(), " children=", stats_grid.get_child_count())
			for child in stats_grid.get_children():
				print("  ", child.position, " ", child.size, " min=", child.get_combined_minimum_size())

	SceneRouter.go_menu()
	await _wait(0.6)
	SceneRouter.go_gameplay()
	await _wait(2.2)
	await _shot("05_gameplay")

	var gameplay := SceneRouter.get_current_screen()
	if gameplay != null:
		gameplay.set("score", 12)
		var hud := gameplay.get_node_or_null("%HUD")
		if hud != null:
			hud.call("set_score", 12, false)
		gameplay.call("pause_game")
		await _wait(0.6)
		await _shot("06_pause")
		gameplay.call("resume_game")
		await _wait(1.4)

		var player := gameplay.get_node_or_null("%Player")
		if player != null:
			player.call("kill")
			await _wait(1.4)
			await _shot("07_game_over")

		var game_over := gameplay.get_node_or_null("%GameOver")
		if game_over != null:
			game_over.emit_signal("continue_pressed")
			await _wait(0.7)
			await _shot("08_test_ad")
			var overlay := _find_test_ad(get_tree().root)
			if overlay != null:
				overlay.call("_on_close")
			await _wait(0.4)

		gameplay.call("_restart_from_game_over")
		await _wait(0.4)
		gameplay.call("pause_game")
		await _wait(0.2)
		gameplay.call("_menu_from_pause")
		await _wait(0.8)

	print("Visual check complete.")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Screenshot failed: %s (%d)" % [path, error])
	else:
		print("screenshot ", path)


func _find_test_ad(node: Node) -> Node:
	if node.get_script() != null and String(node.get_script().resource_path).ends_with("test_ad_overlay.gd"):
		return node
	for child in node.get_children():
		var found := _find_test_ad(child)
		if found != null:
			return found
	return null

extends SceneTree
## Rasterizes the vector brand assets into every PNG size required by the web,
## Android and iOS exports. Run after editing the SVGs:
##   godot --headless --path . --script tools/build_icons.gd

const ICON_SVG := "res://assets/icons/icon.svg"
const FOREGROUND_SVG := "res://assets/icons/icon_foreground.svg"
const MONO_SVG := "res://assets/icons/icon_monochrome.svg"
const SPLASH_SVG := "res://assets/textures/splash.svg"


func _init() -> void:
	var full: Image = _load_svg(ICON_SVG)
	var foreground: Image = _load_svg(FOREGROUND_SVG)
	var monochrome: Image = _load_svg(MONO_SVG)
	var splash: Image = _load_svg(SPLASH_SVG)
	if full == null or foreground == null or splash == null:
		push_error("Icon generation failed: missing or invalid SVG.")
		quit(1)
		return

	_save(full, 512, "res://assets/icons/icon_512.png")
	_save(full, 1024, "res://assets/icons/icon_1024.png")
	_save(full, 192, "res://assets/icons/icon_192.png")
	_save(full, 180, "res://assets/icons/icon_180.png")
	_save(full, 64, "res://assets/icons/favicon_64.png")
	_save(splash, 1080, "res://assets/textures/splash.png")

	# Android adaptive icons.
	_save(full, 192, "res://assets/icons/android/launcher_192.png")
	_save(foreground, 432, "res://assets/icons/android/adaptive_foreground_432.png")
	_save(full, 512, "res://assets/icons/android/play_store_512.png")
	var background := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	background.fill(Color("#050505"))
	background.save_png(ProjectSettings.globalize_path("res://assets/icons/android/adaptive_background_432.png"))
	if monochrome != null:
		_save(monochrome, 432, "res://assets/icons/android/adaptive_monochrome_432.png")
		_save(monochrome, 96, "res://assets/icons/android/notification_96.png")

	# iOS icon set (Godot fills the remaining slots from the 1024 master if needed).
	var ios_sizes := {
		"icon_20.png": 20,
		"icon_29.png": 29,
		"icon_40.png": 40,
		"icon_58.png": 58,
		"icon_60.png": 60,
		"icon_76.png": 76,
		"icon_80.png": 80,
		"icon_87.png": 87,
		"icon_120.png": 120,
		"icon_152.png": 152,
		"icon_167.png": 167,
		"icon_180.png": 180,
		"icon_1024.png": 1024,
	}
	for file_name: String in ios_sizes:
		_save(full, int(ios_sizes[file_name]), "res://assets/icons/ios/%s" % file_name)

	print("Icon and splash assets generated.")
	quit()


func _load_svg(path: String) -> Image:
	if not FileAccess.file_exists(path):
		push_error("Missing SVG: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	var source := file.get_as_text()
	file.close()
	var image := Image.new()
	var error := image.load_svg_from_string(source, 1.0)
	if error != OK:
		push_error("Could not rasterize %s (%d)." % [path, error])
		return null
	return image


func _save(source: Image, target_width: int, path: String) -> void:
	var image := source.duplicate() as Image
	if image.get_width() != target_width:
		var target_height := int(round(float(image.get_height()) * target_width / float(image.get_width())))
		image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(absolute)
	if error != OK:
		push_error("Could not save %s (%d)." % [path, error])
	print("wrote ", path, " ", image.get_width(), "x", image.get_height())

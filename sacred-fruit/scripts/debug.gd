extends Node
class_name Debug

# Simple debug overlay + runtime map launcher.
# Toggle menu with F1.

const DEBUG_MENU_SCENE: PackedScene = preload("res://scenes/ui/debug_menu.tscn")
const RUNTIME_PLAY_SCENE_PATH := "res://scenes/runtime_map_play.tscn"
const PHOTO_MODE_SCENE_PATH := "res://scenes/photo_mode.tscn"

var pending_runtime_map_path: String = ""
var pending_photo_map_path: String = ""
var pending_force_spectator: bool = false

var _menu: Control


func _ready() -> void:
	# Create once and keep hidden.
	if DEBUG_MENU_SCENE:
		_menu = DEBUG_MENU_SCENE.instantiate() as Control
		if _menu:
			_menu.visible = false
			get_tree().root.call_deferred("add_child", _menu)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F3:
			_open_photo_mode_from_scene()
			get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	if _menu == null:
		return
	_menu.visible = not _menu.visible
	if _menu.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Let it refresh list when opened.
		if _menu.has_method("refresh"):
			_menu.call_deferred("refresh")
	else:
		# Don't force capture here (menus and gameplay handle their own cursor modes).
		pass


func request_play_runtime_map(map_path: String) -> void:
	pending_runtime_map_path = map_path
	if _menu:
		_menu.visible = false
	# This changes scenes; the runtime scene will read pending_runtime_map_path.
	if not RUNTIME_PLAY_SCENE_PATH.is_empty():
		get_tree().change_scene_to_file(RUNTIME_PLAY_SCENE_PATH)


func request_photo_mode(map_path: String) -> void:
	pending_photo_map_path = map_path
	if _menu:
		_menu.visible = false
	if not PHOTO_MODE_SCENE_PATH.is_empty():
		get_tree().change_scene_to_file(PHOTO_MODE_SCENE_PATH)


func _open_photo_mode_from_scene() -> void:
	var map_path := ""
	if not pending_photo_map_path.is_empty():
		map_path = pending_photo_map_path
	elif not pending_runtime_map_path.is_empty():
		map_path = pending_runtime_map_path
	else:
		var root := get_tree().current_scene
		if root:
			var maps := root.find_children("*", "FuncGodotMap", true, false)
			if maps.size() > 0:
				var map := maps[0]
				if "local_map_file" in map:
					map_path = String(map.local_map_file)
	request_photo_mode(map_path)

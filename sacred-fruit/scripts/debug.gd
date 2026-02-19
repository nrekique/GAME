extends Node
class_name Debug

# Simple debug overlay + runtime map launcher.
# Toggle menu with F1.

const DEBUG_MENU_SCENE: PackedScene = preload("res://scenes/ui/debug_menu.tscn")
const RUNTIME_PLAY_SCENE_PATH := "res://scenes/runtime_map_play.tscn"
const PHOTO_MODE_SCENE_PATH := "res://scenes/photo_mode.tscn"
const SMOKE_RUNNER_SCRIPT := preload("res://tools/smoke_runner.gd")

var pending_runtime_map_path: String = ""
var pending_photo_map_path: String = ""
var pending_photo_camera_position: Vector3 = Vector3.ZERO
var pending_photo_camera_rotation: Vector3 = Vector3.ZERO
var pending_photo_camera_fov: float = 70.0
var pending_photo_camera_valid: bool = false
var pending_force_spectator: bool = false

var _menu: Control
var _smoke_runner: RefCounted = SMOKE_RUNNER_SCRIPT.new()
var _smoke_in_progress: bool = false
var _smoke_checked: bool = false


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
			_open_photo_mode_from_scene(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F4:
			_open_photo_mode_from_scene(true)
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
	if not await _run_prelaunch_smoke_tests():
		return
	pending_runtime_map_path = map_path
	if _menu:
		_menu.visible = false
	# This changes scenes; the runtime scene will read pending_runtime_map_path.
	if not RUNTIME_PLAY_SCENE_PATH.is_empty():
		get_tree().change_scene_to_file(RUNTIME_PLAY_SCENE_PATH)


func request_photo_mode(map_path: String) -> void:
	if not await _run_prelaunch_smoke_tests():
		return
	pending_photo_camera_valid = false
	pending_photo_map_path = map_path
	if _menu:
		_menu.visible = false
	if not PHOTO_MODE_SCENE_PATH.is_empty():
		get_tree().change_scene_to_file(PHOTO_MODE_SCENE_PATH)


func request_photo_mode_with_view(map_path: String, cam_pos: Vector3, cam_rot_deg: Vector3, cam_fov: float) -> void:
	if not await _run_prelaunch_smoke_tests():
		return
	pending_photo_camera_position = cam_pos
	pending_photo_camera_rotation = cam_rot_deg
	pending_photo_camera_fov = cam_fov
	pending_photo_camera_valid = true
	pending_photo_map_path = map_path
	if _menu:
		_menu.visible = false
	if not PHOTO_MODE_SCENE_PATH.is_empty():
		get_tree().change_scene_to_file(PHOTO_MODE_SCENE_PATH)


func _open_photo_mode_from_scene(use_current_view: bool) -> void:
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

	if use_current_view:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null:
			request_photo_mode_with_view(map_path, cam.global_position, cam.rotation_degrees, cam.fov)
			return

	request_photo_mode(map_path)


func _run_prelaunch_smoke_tests() -> bool:
	if _smoke_checked:
		return true
	if _smoke_in_progress:
		return false
	if _smoke_runner == null:
		push_error("Smoke runner missing")
		return false
	_smoke_in_progress = true
	var smoke_method := "run_all"
	if not (OS.has_feature("headless") or OS.has_feature("server")):
		# In interactive runtime, avoid portal plugin state pollution; keep portal smoke for headless runs.
		smoke_method = "run_photo_mode_layout"
	var result_v: Variant = await _smoke_runner.call(smoke_method, self)
	_smoke_in_progress = false
	if not (result_v is Dictionary):
		push_error("Smoke tests failed: invalid result")
		return false
	var result: Dictionary = result_v as Dictionary
	var ok: bool = bool(result.get("ok", false))
	var test_name: String = String(result.get("name", "unknown"))
	var message: String = String(result.get("message", "unknown error"))
	if not ok:
		push_error("Smoke test failed (%s): %s" % [test_name, message])
		return false
	_smoke_checked = true
	return true

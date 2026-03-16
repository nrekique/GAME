class_name Debug
extends Node
const Util := preload("res://scripts/core/util.gd")
const Constants := preload("res://scripts/core/constants.gd")

# Simple debug overlay + runtime map launcher.
# Toggle menu with F1.

const MAP_BUILDER_SCENE: PackedScene = preload("res://scenes/ui/map_builder_menu.tscn")
const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/debug_overlay.tscn")
const RUNTIME_PLAY_SCENE_PATH := "res://scenes/runtime_map_play.tscn"
const PHOTO_MODE_SCENE_PATH := "res://scenes/photo_mode.tscn"
const SMOKE_RUNNER_SCRIPT := preload("res://tools/smoke_runner.gd")
const RUNTIME_DEBUG_SETTING := "sacred_fruit/debug/runtime_verbose"

var pending_runtime_map_path: String = ""
var pending_photo_map_path: String = ""
var pending_photo_camera_position: Vector3 = Vector3.ZERO
var pending_photo_camera_rotation: Vector3 = Vector3.ZERO
var pending_photo_camera_fov: float = Constants.PHOTO_DEFAULT_FOV
var pending_photo_camera_valid: bool = false
var pending_force_spectator: bool = false

var _menu: MapBuilderMenu
var _debug_overlay: DebugOverlay
var _smoke_runner: RefCounted = SMOKE_RUNNER_SCRIPT.new()
var _smoke_in_progress: bool = false
var _smoke_checked: bool = false


func _ready() -> void:
	if not ProjectSettings.has_setting(RUNTIME_DEBUG_SETTING):
		ProjectSettings.set_setting(RUNTIME_DEBUG_SETTING, false)
	# Create once and keep hidden.
	if MAP_BUILDER_SCENE:
		_menu = MAP_BUILDER_SCENE.instantiate() as MapBuilderMenu
		if _menu:
			_menu.visible = false
			get_tree().root.call_deferred("add_child", _menu)
	if DEBUG_OVERLAY_SCENE:
		_debug_overlay = DEBUG_OVERLAY_SCENE.instantiate() as DebugOverlay
		if _debug_overlay:
			_debug_overlay.visible = false
			get_tree().root.call_deferred("add_child", _debug_overlay)
	call_deferred("_handle_startup_run_args")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			_open_photo_mode_from_scene(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F3:
			toggle_debug_overlay()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F4:
			_open_photo_mode_from_scene(true)
			get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	if _menu == null:
		return
	if _menu.visible:
		_menu.visible = false
	else:
		_menu.open_menu()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func toggle_debug_overlay() -> void:
	if _debug_overlay == null:
		return
	_debug_overlay.toggle_visibility()


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
	if not (OS.has_feature("headless") or OS.has_feature("server")):
		return true
	if _smoke_checked:
		return true
	if _smoke_in_progress:
		return false
	if _smoke_runner == null:
		push_error("Smoke runner missing")
		return false
	_smoke_in_progress = true
	var smoke_method := "run_all"
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


func is_runtime_debug_enabled() -> bool:
	return bool(ProjectSettings.get_setting(RUNTIME_DEBUG_SETTING, false))


func _handle_startup_run_args() -> void:
	if Util.editor_hint():
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		return

	var map_arg: String = ""
	var launch_photo_mode: bool = false
	var force_spectator: bool = false

	var i: int = 0
	while i < args.size():
		var arg: String = String(args[i])
		if arg == "--tb-run-map":
			if i + 1 < args.size():
				map_arg = String(args[i + 1])
				i += 1
		elif arg.begins_with("--tb-run-map="):
			map_arg = arg.substr(String("--tb-run-map=").length())
		elif arg == "--tb-photo":
			launch_photo_mode = true
		elif arg == "--tb-spectator":
			force_spectator = true
		i += 1

	if map_arg.is_empty():
		return

	var map_path: String = _resolve_runtime_map_arg(map_arg)
	if map_path.is_empty():
		push_error("TrenchBroom run arg could not resolve map path: %s" % map_arg)
		return

	if launch_photo_mode:
		await request_photo_mode(map_path)
		return

	pending_force_spectator = force_spectator
	await request_play_runtime_map(map_path)


func _resolve_runtime_map_arg(raw_path: String) -> String:
	var p: String = raw_path.strip_edges()
	if p.begins_with("\"") and p.ends_with("\"") and p.length() >= 2:
		p = p.substr(1, p.length() - 2)
	p = p.replace("\\", "/")
	if p.is_empty():
		return ""
	if p.begins_with("res://"):
		return p
	if p.begins_with("tb/"):
		return "res://" + p
	if p.begins_with("/tb/"):
		return "res://" + p.substr(1)
	if p.begins_with("./tb/"):
		return "res://" + p.substr(2)
	if not p.is_absolute_path():
		var rel_candidate: String = "res://" + p
		if FileAccess.file_exists(rel_candidate):
			return rel_candidate
		var tb_maps_candidate: String = "res://tb/maps/" + p.get_file()
		if FileAccess.file_exists(tb_maps_candidate):
			return tb_maps_candidate
		var found := _find_map_in_dir("res://tb/maps/", p.get_file())
		if not found.is_empty():
			return found
		var tb_candidate: String = "res://tb/" + p.get_file()
		if FileAccess.file_exists(tb_candidate):
			return tb_candidate
		return ""

	var abs_path := p.simplify_path()
	var project_root: String = ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path()
	if abs_path.begins_with(project_root):
		var rel: String = abs_path.substr(project_root.length())
		if rel.begins_with("/"):
			rel = rel.substr(1)
		var res_path: String = "res://" + rel
		if FileAccess.file_exists(res_path):
			return res_path
	var tb_idx: int = abs_path.find("/tb/")
	if tb_idx >= 0:
		var rel_tb: String = abs_path.substr(tb_idx + 1)
		var tb_res_path: String = "res://" + rel_tb
		if FileAccess.file_exists(tb_res_path):
			return tb_res_path
	return ""


func _find_map_in_dir(dir_path: String, filename: String) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with("."):
			var found := _find_map_in_dir(dir_path + entry + "/", filename)
			if not found.is_empty():
				return found
		elif entry == filename:
			var candidate := dir_path + entry
			if FileAccess.file_exists(candidate):
				return candidate
		entry = dir.get_next()
	return ""

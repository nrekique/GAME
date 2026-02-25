extends Node3D
const Util := preload("res://scripts/core/util.gd")
const FuncGodotMap := preload("res://addons/func_godot/src/map/func_godot_map.gd")

# Builds a FuncGodot map at runtime and then spawns the player.
# Map path is provided by the DEBUG autoload (pending_runtime_map_path).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SPECTATOR_SCENE: PackedScene = preload("res://scenes/spectator.tscn")
const HOME_SETUP_SCRIPT := preload("res://scripts/core/home_setup.gd")
const SANDSTORM_CONTROLLER_SCRIPT := preload("res://scripts/env/sandstorm_controller.gd")
const RUNTIME_PERF_HUD_SCRIPT := preload("res://scripts/debug/runtime_perf_hud.gd")
const RUNTIME_AI_HUD_SCRIPT := preload("res://scripts/debug/runtime_ai_hud.gd")
const INFO_PLAYER_START_SCRIPT: Script = preload("res://entities/info_player_start.gd")

var _map: FuncGodotMap
var _player: Node3D
var _sandstorm: Node3D
var _perf_hud: CanvasLayer
var _ai_hud: CanvasLayer

@export var enable_sandstorm: bool = true
@export_range(0.0, 1.0, 0.01) var sandstorm_intensity: float = 0.85
@export var sandstorm_wind_direction: Vector2 = Vector2(1.0, 0.25)
@export_range(0.0, 4.0, 0.01) var sandstorm_wind_speed: float = 1.0


func _ready() -> void:
	if Util.editor_hint():
		return
	add_to_group("NO_HUD")

	# Minimal loading indicator.
	var status := _make_status_label("Building map…")
	add_child(status)
	_setup_perf_hud()
	_setup_ai_hud()

	var dbg := get_node_or_null("/root/DEBUG")
	var map_path := ""
	if dbg != null and "pending_runtime_map_path" in dbg:
		map_path = String(dbg.pending_runtime_map_path)
	if map_path.is_empty():
		(status as Label).text = "No map selected (open debug menu with F1)"
		return

	_map = FuncGodotMap.new()
	_map.name = "FuncGodotMap"
	_map.local_map_file = map_path
	add_child(_map)

	var ok := await _build_map(_map, status as Label)
	if not ok:
		return

	(status as Label).text = "Spawning player…"
	var force_spectator := false
	if dbg != null and "pending_force_spectator" in dbg:
		force_spectator = bool(dbg.pending_force_spectator)
		dbg.pending_force_spectator = false
	if force_spectator:
		(status as Label).text = "Spectator mode"
		_spawn_spectator()
		_ensure_fallback_light()
	else:
		var has_player := _spawn_player()
		var has_start := _position_player_at_start()
		if not has_player or not has_start:
			if _player:
				_player.queue_free()
				_player = null
			(status as Label).text = "No player start found — spectator mode"
			_spawn_spectator()
			_ensure_fallback_light()
		else:
			_ensure_player_camera()
			_ensure_fallback_light()

	# Run the existing fallback spawner AFTER build so we don't duplicate entities.
	var setup := Node3D.new()
	setup.name = "HomeSetup"
	setup.set_script(HOME_SETUP_SCRIPT)
	add_child(setup)
	# Configure it for manual run.
	if "auto_run" in setup:
		setup.auto_run = false
	# Runtime map play owns environment startup. Prevent HomeSetup from always
	# spawning SandstormController regardless of map-authored env entities.
	if "enable_sandstorm" in setup:
		setup.enable_sandstorm = false
	if setup.has_method("run_setup"):
		await setup.call("run_setup")

	_setup_sandstorm()

	(status as Label).queue_free()


func _setup_perf_hud() -> void:
	if RUNTIME_PERF_HUD_SCRIPT == null:
		return
	if _perf_hud != null and is_instance_valid(_perf_hud):
		return
	var hud := RUNTIME_PERF_HUD_SCRIPT.new()
	if hud is CanvasLayer:
		_perf_hud = hud as CanvasLayer
		add_child(_perf_hud)


func _setup_ai_hud() -> void:
	if RUNTIME_AI_HUD_SCRIPT == null:
		return
	if _ai_hud != null and is_instance_valid(_ai_hud):
		return
	var hud := RUNTIME_AI_HUD_SCRIPT.new()
	if hud is CanvasLayer:
		_ai_hud = hud as CanvasLayer
		add_child(_ai_hud)


func _make_status_label(text: String) -> Label:
	var l := Label.new()
	l.name = "RuntimeStatus"
	l.text = text
	l.position = Vector2(12, 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _build_map(map: FuncGodotMap, status: Label) -> bool:
	var done := [false]
	var success := [false]

	map.build_progress.connect(func(step, progress):
		if status:
			status.text = "Building %s (%d%%)" % [String(step), int(progress * 100.0)]
	)
	map.build_complete.connect(func():
		done[0] = true
		success[0] = true
	)
	map.build_failed.connect(func():
		done[0] = true
		success[0] = false
		if status:
			status.text = "Build failed (see output)"
	)

	map.verify_and_build()
	while not done[0]:
		await get_tree().process_frame
	return success[0]


func _spawn_player() -> bool:
	if PLAYER_SCENE == null:
		return false
	var p := PLAYER_SCENE.instantiate()
	add_child(p)
	if p is Node3D:
		_player = p as Node3D
		return true
	return false


func _position_player_at_start() -> bool:
	if _player == null:
		return false
	# Find an active info_player_start.
	var starts := find_children("*", "Marker3D", true, false)
	for s in starts:
		if s.get_script() == INFO_PLAYER_START_SCRIPT and Util.to_bool(s.get("active"), false):
			_player.global_position = s.global_position
			_player.rotation_degrees = s.get("angles")
			return true
	return false


func _ensure_player_camera() -> void:
	if _player == null:
		return
	var cam := _player.find_child("Camera", true, false) as Camera3D
	if cam:
		cam.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _spawn_spectator() -> void:
	if SPECTATOR_SCENE == null:
		return
	var spec := SPECTATOR_SCENE.instantiate()
	add_child(spec)
	if spec is Node3D:
		var spec_node := spec as Node3D
		var start_pos := Vector3(0, 2.0, 0)
		if _map:
			var meshes: Array = _map.find_children("*", "MeshInstance3D", true, false)
			if meshes.size() > 0:
				var mesh := meshes[0] as MeshInstance3D
				if mesh:
					start_pos = mesh.global_position + Vector3(0, 2.0, 0)
		spec_node.global_position = start_pos


func _ensure_fallback_light() -> void:
	# Only add a light if the map has none.
	var existing := find_children("*", "Light3D", true, false)
	if existing.size() > 0:
		return
	var light := DirectionalLight3D.new()
	light.name = "RuntimeFallbackLight"
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)


func _setup_sandstorm() -> void:
	if not enable_sandstorm:
		return
	if not _map_requests_sandstorm():
		return
	if SANDSTORM_CONTROLLER_SCRIPT == null:
		return
	if _sandstorm != null and is_instance_valid(_sandstorm):
		return
	var storm := SANDSTORM_CONTROLLER_SCRIPT.new() as Node3D
	if storm == null:
		return
	storm.name = "SandstormController"
	storm.set("enabled", true)
	storm.set("intensity", sandstorm_intensity)
	storm.set("wind_direction", sandstorm_wind_direction)
	storm.set("wind_speed", sandstorm_wind_speed)
	add_child(storm)
	_sandstorm = storm


func _map_requests_sandstorm() -> bool:
	if _map == null:
		return false
	var map_path := String(_map.local_map_file)
	if map_path.is_empty():
		map_path = String(_map.global_map_file)
	if map_path.is_empty() or not FileAccess.file_exists(map_path):
		return false

	var text := FileAccess.get_file_as_string(map_path)
	if text.is_empty():
		return false

	# Explicit map entity.
	if text.find("\"classname\" \"env_sandstorm\"") != -1:
		return true

	# Legacy / fallback worldspawn keys.
	if text.find("\"sandstorm_enabled\" \"1\"") != -1:
		return true
	if text.find("\"sandstorm_intensity\"") != -1:
		return true
	if text.find("\"sandstorm_wind_speed\"") != -1:
		return true
	if text.find("\"sandstorm_wind_direction\"") != -1:
		return true
	if text.find("\"sandstorm_fog_color\"") != -1:
		return true

	return false

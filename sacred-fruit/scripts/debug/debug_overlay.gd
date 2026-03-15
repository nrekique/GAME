extends Control
class_name DebugOverlay

## Minecraft-style F3 debug overlay
## Shows real-time game stats, toggleable with F3

@onready var fps_label: Label = $LeftPanel/FPS
@onready var frame_time_label: Label = $LeftPanel/FrameTime
@onready var position_label: Label = $LeftPanel/Position
@onready var rotation_label: Label = $LeftPanel/Rotation
@onready var velocity_label: Label = $LeftPanel/Velocity
@onready var scene_label: Label = $LeftPanel/Scene
@onready var map_label: Label = $LeftPanel/Map
@onready var memory_label: Label = $LeftPanel/Memory
@onready var node_count_label: Label = $LeftPanel/NodeCount
@onready var draw_calls_label: Label = $LeftPanel/DrawCalls
@onready var camera_label: Label = $LeftPanel/Camera

var _player: Node3D = null
var _camera: Camera3D = null
var _frame_times: Array[float] = []
var _frame_time_window := 30  # Average over 30 frames


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func toggle_visibility() -> void:
	visible = not visible
	set_process(visible)
	if visible:
		_refresh_references()


func _refresh_references() -> void:
	# Try to find player
	_player = _find_player()
	
	# Try to find active camera
	_camera = get_viewport().get_camera_3d()


func _find_player() -> Node3D:
	# Look for player in common locations
	var player := get_node_or_null("/root/GAME/Player")
	if player and player is Node3D:
		return player as Node3D
	
	# Fallback: search for node named "Player"
	var tree := get_tree()
	if tree:
		var root := tree.root
		var players := root.find_children("Player", "Node3D", true, false)
		if players.size() > 0:
			return players[0] as Node3D
	
	return null


func _process(_delta: float) -> void:
	_update_fps()
	_update_position()
	_update_rotation()
	_update_velocity()
	_update_scene_info()
	_update_performance()
	_update_camera()


func _update_fps() -> void:
	var fps := Engine.get_frames_per_second()
	var frame_time := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	
	# Track frame times for averaging
	_frame_times.append(frame_time)
	if _frame_times.size() > _frame_time_window:
		_frame_times.pop_front()
	
	var avg_frame_time := 0.0
	for ft in _frame_times:
		avg_frame_time += ft
	if _frame_times.size() > 0:
		avg_frame_time /= _frame_times.size()
	
	# Color code FPS (green > 55, yellow 30-55, red < 30)
	var fps_color := Color.WHITE
	if fps >= 55:
		fps_color = Color(0.4, 1.0, 0.4)  # Green
	elif fps >= 30:
		fps_color = Color(1.0, 1.0, 0.4)  # Yellow
	else:
		fps_color = Color(1.0, 0.4, 0.4)  # Red
	
	fps_label.text = "FPS: %d" % fps
	fps_label.add_theme_color_override("font_color", fps_color)
	
	frame_time_label.text = "Frame: %.1f ms" % avg_frame_time


func _update_position() -> void:
	if _player == null:
		_player = _find_player()
	
	if _player:
		var pos := _player.global_position
		position_label.text = "XYZ: %.1f / %.1f / %.1f" % [pos.x, pos.y, pos.z]
	else:
		position_label.text = "XYZ: No player found"


func _update_rotation() -> void:
	if _player == null:
		return
	
	var rot := _player.global_rotation_degrees
	var yaw := fmod(rot.y + 360.0, 360.0)
	
	# Determine facing direction
	var facing := ""
	if yaw >= 337.5 or yaw < 22.5:
		facing = "North"
	elif yaw >= 22.5 and yaw < 67.5:
		facing = "Northeast"
	elif yaw >= 67.5 and yaw < 112.5:
		facing = "East"
	elif yaw >= 112.5 and yaw < 157.5:
		facing = "Southeast"
	elif yaw >= 157.5 and yaw < 202.5:
		facing = "South"
	elif yaw >= 202.5 and yaw < 247.5:
		facing = "Southwest"
	elif yaw >= 247.5 and yaw < 292.5:
		facing = "West"
	else:
		facing = "Northwest"
	
	rotation_label.text = "Facing: %s (%.1f°)" % [facing, yaw]


func _update_velocity() -> void:
	if _player == null:
		return
	
	# Try to get velocity from CharacterBody3D
	if _player.has_method("get_velocity"):
		var vel: Vector3 = _player.call("get_velocity")
		var speed := vel.length()
		velocity_label.text = "Velocity: %.1f m/s" % speed
	elif _player.has_method("get_real_velocity"):
		var vel: Vector3 = _player.call("get_real_velocity")
		var speed := vel.length()
		velocity_label.text = "Velocity: %.1f m/s" % speed
	else:
		velocity_label.text = "Velocity: N/A"


func _update_scene_info() -> void:
	var tree := get_tree()
	if tree:
		var current_scene := tree.current_scene
		if current_scene:
			scene_label.text = "Scene: %s" % current_scene.name
		else:
			scene_label.text = "Scene: none"
	
	# Try to find map info
	var game_mgr := get_node_or_null("/root/GAME")
	if game_mgr and game_mgr.has_method("get_current_map_name"):
		var map_name: String = game_mgr.call("get_current_map_name")
		if not map_name.is_empty():
			map_label.text = "Map: %s" % map_name
		else:
			map_label.text = "Map: none"
	else:
		map_label.text = "Map: N/A"


func _update_performance() -> void:
	# Memory usage
	var static_mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	var dynamic_mem := _get_dynamic_memory_usage_mb()
	var total_mem := static_mem + dynamic_mem
	memory_label.text = "Memory: %.1f MB (Static: %.1f / Dynamic: %.1f)" % [total_mem, static_mem, dynamic_mem]
	
	# Node count
	var tree := get_tree()
	if tree:
		var node_count := tree.get_node_count()
		node_count_label.text = "Nodes: %d" % node_count
	
	# Draw calls
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	draw_calls_label.text = "Draw Calls: %d" % draw_calls


func _update_camera() -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
	
	if _camera:
		camera_label.text = "Camera FOV: %.1f°" % _camera.fov
	else:
		camera_label.text = "Camera: none"


func _get_dynamic_memory_usage_mb() -> float:
	return 0.0

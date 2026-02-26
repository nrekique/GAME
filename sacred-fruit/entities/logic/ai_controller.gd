@tool
class_name AIController
extends Node
const Util := preload("res://scripts/core/util.gd")

@export var enabled: bool = true
@export var route_id: String = "default"
@export_range(0.1, 20.0, 0.01) var patrol_speed: float = 2.0
@export_range(0.0, 30.0, 0.01) var alert_duration: float = 4.0
@export var reacts_to_alerts: bool = true

var _agent: Node3D = null
var _patrol_points: Array[Node3D] = []
var _patrol_index: int = 0
var _wait_until_sec: float = 0.0
var _alert_until_sec: float = 0.0
var _alert_target: Vector3 = Vector3.ZERO
var _state: String = "idle"
var _next_patrol_refresh_sec: float = 0.0
var _is_moving: bool = false

func setup(agent: Node3D, config: Dictionary = {}) -> void:
	_agent = agent
	if config.has("enabled"):
		enabled = Util.to_bool(config["enabled"], enabled)
	if config.has("route_id"):
		route_id = String(config["route_id"]).strip_edges()
	if config.has("patrol_speed"):
		patrol_speed = maxf(float(config["patrol_speed"]), 0.1)
	if config.has("alert_duration"):
		alert_duration = maxf(float(config["alert_duration"]), 0.0)
	if config.has("reacts_to_alerts"):
		reacts_to_alerts = Util.to_bool(config["reacts_to_alerts"], reacts_to_alerts)
	if route_id.is_empty():
		route_id = "default"
	_set_agent_move_state(false)

func _ready() -> void:
	if Util.editor_hint():
		return
	add_to_group("ai_controller")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not enabled:
		set_process(false)
		set_physics_process(false)
		return
	_refresh_patrol_points()
	var game := _get_game()
	if game != null and game.has_signal("ai_alerted"):
		var cb := Callable(self, "_on_ai_alerted")
		if not game.is_connected("ai_alerted", cb):
			game.connect("ai_alerted", cb)
	set_process(false)
	set_physics_process(true)

func _process(delta: float) -> void:
	# AI movement runs in physics for deterministic stepping.
	pass

func _physics_process(delta: float) -> void:
	_tick_ai(delta)

func _on_ai_alerted(position: Vector3, _source: Node = null) -> void:
	if not reacts_to_alerts:
		return
	if _agent == null or not is_instance_valid(_agent):
		return
	var game := _get_game()
	if game != null and game.has_method("is_ai_perception_blocked"):
		if bool(game.call("is_ai_perception_blocked", _agent.global_position, position)):
			return
	_alert_target = position
	_alert_until_sec = (Time.get_ticks_msec() / 1000.0) + alert_duration
	_state = "alert"

func _refresh_patrol_points() -> void:
	_patrol_points.clear()
	var game := _get_game()
	if game == null:
		return
	if game.has_method("get_ai_patrol_points"):
		var arr: Variant = game.call("get_ai_patrol_points", route_id)
		if arr is Array:
			for p in arr:
				if p is Node3D:
					_patrol_points.append(p as Node3D)
	if _patrol_points.is_empty():
		_patrol_index = 0
	elif _patrol_index >= _patrol_points.size():
		_patrol_index = 0

func _move_towards(target_pos: Vector3, delta: float) -> bool:
	var current := _agent.global_position
	var to_target := target_pos - current
	to_target.y = 0.0
	var dist := to_target.length()
	if dist <= 0.05:
		return true
	var dir := to_target / dist
	var step := patrol_speed * delta
	if step >= dist:
		if _agent is CharacterBody3D:
			var body := _agent as CharacterBody3D
			body.velocity = Vector3.ZERO
			body.move_and_slide()
			_agent.global_position = Vector3(target_pos.x, _agent.global_position.y, target_pos.z)
		else:
			_agent.global_position = Vector3(target_pos.x, _agent.global_position.y, target_pos.z)
		_look_horizontal(dir)
		return true
	if _agent is CharacterBody3D:
		var body := _agent as CharacterBody3D
		body.velocity.x = dir.x * patrol_speed
		body.velocity.z = dir.z * patrol_speed
		body.move_and_slide()
	else:
		_agent.global_position += Vector3(dir.x, 0.0, dir.z) * step
	_look_horizontal(dir)
	return false

func _look_horizontal(dir: Vector3) -> void:
	if dir.length_squared() <= 0.000001:
		return
	var yaw := atan2(dir.x, dir.z)
	var r := _agent.rotation
	r.y = yaw
	_agent.rotation = r


func get_debug_snapshot() -> Dictionary:
	var now: float = Time.get_ticks_msec() / 1000.0
	var alert_remaining: float = maxf(0.0, _alert_until_sec - now)
	return {
		"enabled": enabled,
		"state": _state,
		"route_id": route_id,
		"patrol_points": _patrol_points.size(),
		"patrol_index": _patrol_index,
		"alert_remaining": alert_remaining,
		"reacts_to_alerts": reacts_to_alerts,
		"has_agent": _agent != null and is_instance_valid(_agent),
		"is_moving": _is_moving
	}


func _tick_ai(delta: float) -> void:
	if not enabled:
		_set_agent_move_state(false)
		return
	if not _resolve_agent():
		_state = "idle"
		_set_agent_move_state(false)
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now >= _next_patrol_refresh_sec:
		_refresh_patrol_points()
		_next_patrol_refresh_sec = now + 1.0
	if _state == "alert":
		var alert_reached := _move_towards(_alert_target, delta)
		_set_agent_move_state(not alert_reached)
		if now >= _alert_until_sec:
			_state = "patrol" if not _patrol_points.is_empty() else "idle"
		return
	if _patrol_points.is_empty():
		_state = "idle"
		_set_agent_move_state(false)
		return
	_state = "patrol"
	if now < _wait_until_sec:
		_set_agent_move_state(false)
		return
	var point := _patrol_points[_patrol_index]
	var reached := _move_towards(point.global_position, delta)
	_set_agent_move_state(not reached)
	if reached:
		var wait_sec: float = 0.0
		if "wait" in point:
			wait_sec = maxf(float(point.get("wait")), 0.0)
		_wait_until_sec = now + wait_sec
		var linked_next := _find_linked_next_index(point)
		if linked_next >= 0:
			_patrol_index = linked_next
		else:
			_patrol_index = (_patrol_index + 1) % _patrol_points.size()


func _resolve_agent() -> bool:
	if _agent != null and is_instance_valid(_agent):
		return true
	var parent_node := get_parent()
	if parent_node is Node3D and is_instance_valid(parent_node):
		_agent = parent_node as Node3D
	return _agent != null and is_instance_valid(_agent)


func _get_game() -> Node:
	return get_node_or_null("/root/GAME")


func _find_linked_next_index(point: Node3D) -> int:
	var target_name := String(Util.get_node_prop(point, "target", "")).strip_edges()
	if target_name.is_empty():
		return -1
	for i in range(_patrol_points.size()):
		var candidate := _patrol_points[i]
		var candidate_targetname := String(Util.get_node_prop(candidate, "targetname", "")).strip_edges()
		if candidate_targetname == target_name:
			return i
	return -1


func _set_agent_move_state(moving: bool) -> void:
	if _is_moving == moving:
		return
	_is_moving = moving
	if _agent == null or not is_instance_valid(_agent):
		return
	if _agent.has_method("set_ai_move_state"):
		_agent.call("set_ai_move_state", moving)

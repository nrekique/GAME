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

func _ready() -> void:
	if Util.editor_hint():
		return
	if not enabled:
		set_process(false)
		return
	_refresh_patrol_points()
	if Engine.has_singleton("GAME") and GAME.has_signal("ai_alerted"):
		var cb := Callable(self, "_on_ai_alerted")
		if not GAME.is_connected("ai_alerted", cb):
			GAME.connect("ai_alerted", cb)
	set_process(true)

func _process(delta: float) -> void:
	if _agent == null or not is_instance_valid(_agent):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now >= _next_patrol_refresh_sec:
		_refresh_patrol_points()
		_next_patrol_refresh_sec = now + 1.0
	if _state == "alert":
		_move_towards(_alert_target, delta)
		if now >= _alert_until_sec:
			_state = "patrol" if not _patrol_points.is_empty() else "idle"
		return
	if _patrol_points.is_empty():
		_state = "idle"
		return
	_state = "patrol"
	if now < _wait_until_sec:
		return
	var point := _patrol_points[_patrol_index]
	var reached := _move_towards(point.global_position, delta)
	if reached:
		var wait_sec: float = 0.0
		if "wait" in point:
			wait_sec = maxf(float(point.get("wait")), 0.0)
		_wait_until_sec = now + wait_sec
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()

func _on_ai_alerted(position: Vector3, _source: Node = null) -> void:
	if not reacts_to_alerts:
		return
	if _agent == null or not is_instance_valid(_agent):
		return
	if Engine.has_singleton("GAME") and GAME.has_method("is_ai_perception_blocked"):
		if bool(GAME.call("is_ai_perception_blocked", _agent.global_position, position)):
			return
	_alert_target = position
	_alert_until_sec = (Time.get_ticks_msec() / 1000.0) + alert_duration
	_state = "alert"

func _refresh_patrol_points() -> void:
	_patrol_points.clear()
	if not Engine.has_singleton("GAME"):
		return
	if GAME.has_method("get_ai_patrol_points"):
		var arr: Variant = GAME.call("get_ai_patrol_points", route_id)
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
		_agent.global_position = Vector3(target_pos.x, _agent.global_position.y, target_pos.z)
		_look_horizontal(dir)
		return true
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

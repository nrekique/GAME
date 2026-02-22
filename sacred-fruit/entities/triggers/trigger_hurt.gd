@tool
class_name TriggerHurt
extends Area3D
const Util := preload("res://scripts/util.gd")

# Quake-ish defaults: "dmg" is damage per second, "wait" is tick interval.
@export var damage_per_second: float = 20.0
@export var interval: float = 0.25
@export var start_disabled: bool = false
@export var one_shot: bool = false
@export var targetname: String = ""

# Debug helper (can be toggled by properties)
@export var show_volume: bool = false

var _enabled: bool = true
var _bodies: Array[Node] = []
var _timer: Timer


func _func_godot_apply_properties(props: Dictionary) -> void:
	# Support common Quake key names.
	if props.has("dmg"):
		damage_per_second = float(props["dmg"])
	if props.has("damage"):
		damage_per_second = float(props["damage"])
	if props.has("wait"):
		interval = maxf(0.01, float(props["wait"]))
	if props.has("interval"):
		interval = maxf(0.01, float(props["interval"]))
	if props.has("start_disabled"):
		start_disabled = (str(props["start_disabled"]) == "1") or (props["start_disabled"] as bool)
	if props.has("one_shot"):
		one_shot = (str(props["one_shot"]) == "1") or (props["one_shot"] as bool)
	if props.has("show_volume"):
		show_volume = (str(props["show_volume"]) == "1") or (props["show_volume"] as bool)
	if props.has("targetname"):
		targetname = props["targetname"] as String


func _init() -> void:
	monitoring = true
	monitorable = false
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)


func _ready() -> void:
	if Util.editor_hint():
		return

	_enabled = not start_disabled

	if targetname != "":
		GAME.set_targetname(self, targetname)

	_timer = Timer.new()
	_timer.one_shot = false
	_timer.autostart = false
	_timer.wait_time = maxf(0.01, interval)
	add_child(_timer)
	_timer.timeout.connect(_on_tick)


func use() -> void:
	set_enabled(not _enabled)


func enable() -> void:
	set_enabled(true)


func disable() -> void:
	set_enabled(false)


func set_enabled(value: bool) -> void:
	_enabled = value
	if not _enabled:
		_stop_timer()
	else:
		_start_timer_if_needed()


func _on_body_entered(body: Node) -> void:
	if Util.editor_hint():
		return
	if not _enabled:
		return
	if body != null and body.is_in_group("PLAYER"):
		if not _bodies.has(body):
			_bodies.append(body)
			_start_timer_if_needed()


func _on_body_exited(body: Node) -> void:
	if Util.editor_hint():
		return
	if body != null:
		_bodies.erase(body)
		if _bodies.is_empty():
			_stop_timer()


func _start_timer_if_needed() -> void:
	if _timer == null:
		return
	_timer.wait_time = maxf(0.01, interval)
	if _enabled and not _bodies.is_empty() and _timer.is_stopped():
		_timer.start()


func _stop_timer() -> void:
	if _timer != null and not _timer.is_stopped():
		_timer.stop()


func _on_tick() -> void:
	if not _enabled:
		_stop_timer()
		return
	if _bodies.is_empty():
		_stop_timer()
		return

	var dmg := damage_per_second * maxf(0.01, interval)
	for b in _bodies.duplicate():
		if b == null or not is_instance_valid(b):
			_bodies.erase(b)
			continue
		_apply_damage(b, dmg)

	if one_shot:
		set_enabled(false)


func _apply_damage(body: Node, amount: float) -> void:
	var applied := false
	if body.has_method("apply_damage"):
		body.call("apply_damage", amount)
		applied = true
	elif body.has_method("get") and body.has_method("set"):
		var current = body.get("health")
		if typeof(current) in [TYPE_INT, TYPE_FLOAT]:
			body.set("health", float(current) - amount)
			applied = true

	if not applied and GAME and GAME.has_method("apply_damage"):
		GAME.call("apply_damage", amount)
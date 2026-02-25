@tool
class_name LogicTimer
extends Node3D
const Util := preload("res://scripts/core/util.gd")

@export var target: String = ""
@export var targetfunc: String = ""
@export var targetname: String = ""
@export var enabled: bool = true
@export var start_on_spawn: bool = false
@export var one_shot: bool = false
@export var wait: float = 1.0
@export var random_jitter: float = 0.0

var _running: bool = false
var _time_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = String(props["target"])
	if props.has("targetfunc"):
		targetfunc = String(props["targetfunc"])
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("start_on_spawn"):
		start_on_spawn = Util.to_bool(props["start_on_spawn"], start_on_spawn)
	if props.has("one_shot"):
		one_shot = Util.to_bool(props["one_shot"], one_shot)
	if props.has("wait"):
		wait = maxf(float(props["wait"]), 0.01)
	if props.has("random_jitter"):
		random_jitter = maxf(float(props["random_jitter"]), 0.0)


func _ready() -> void:
	if Util.editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)
	if enabled and start_on_spawn:
		start()


func _process(delta: float) -> void:
	if Util.editor_hint():
		return
	if not enabled or not _running:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	_fire_targets()
	if one_shot:
		_running = false
	else:
		_restart_timer()


func use() -> void:
	if _running:
		stop()
	else:
		start()


func start() -> void:
	if not enabled:
		return
	_running = true
	_restart_timer()


func stop() -> void:
	_running = false


func trigger_now() -> void:
	_fire_targets()


func _restart_timer() -> void:
	var jitter := 0.0
	if random_jitter > 0.0:
		jitter = _rng.randf_range(-random_jitter, random_jitter)
	_time_left = maxf(wait + jitter, 0.01)


func _fire_targets() -> void:
	var target_group := target.strip_edges()
	if target_group.is_empty():
		return
	GAME.use_targets(self, target_group)
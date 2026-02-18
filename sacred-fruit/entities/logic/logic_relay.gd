@tool
class_name LogicRelay
extends Node3D

@export var target: String = ""
@export var targetfunc: String = ""
@export var targetname: String = ""
@export var enabled: bool = true
@export var trigger_once: bool = false
@export var delay: float = 0.0

var _used: bool = false


static func _to_bool(value: Variant, default_value: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING:
			var s := String(value).strip_edges().to_lower()
			if s in ["1", "true", "yes", "on", "y"]:
				return true
			if s in ["0", "false", "no", "off", "n", ""]:
				return false
			return default_value
		_:
			return default_value


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = String(props["target"])
	if props.has("targetfunc"):
		targetfunc = String(props["targetfunc"])
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("enabled"):
		enabled = _to_bool(props["enabled"], enabled)
	if props.has("trigger_once"):
		trigger_once = _to_bool(props["trigger_once"], trigger_once)
	if props.has("delay"):
		delay = maxf(float(props["delay"]), 0.0)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)


func use() -> void:
	if not enabled:
		return
	if trigger_once and _used:
		return
	_used = true
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_fire_targets()
	if trigger_once:
		enabled = false


func toggle() -> void:
	enabled = not enabled


func enable() -> void:
	enabled = true


func disable() -> void:
	enabled = false


func _fire_targets() -> void:
	var target_group := target.strip_edges()
	if target_group.is_empty():
		return
	GAME.use_targets(self, target_group)

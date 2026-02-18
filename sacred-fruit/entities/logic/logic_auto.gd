@tool
class_name LogicAuto
extends Node3D

@export var target: String = ""
@export var targetfunc: String = ""
@export var targetname: String = ""
@export var master: String = ""
@export var killtarget: String = ""
@export var enabled: bool = true
@export var fire_once: bool = true
@export var delay: float = 0.0

var _fired: bool = false


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
	if props.has("master"):
		master = String(props["master"])
	if props.has("killtarget"):
		killtarget = String(props["killtarget"])
	if props.has("enabled"):
		enabled = _to_bool(props["enabled"], enabled)
	if props.has("fire_once"):
		fire_once = _to_bool(props["fire_once"], fire_once)
	if props.has("delay"):
		delay = maxf(float(props["delay"]), 0.0)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not targetname.is_empty():
		GAME.set_targetname(self, targetname)
	if enabled:
		call_deferred("_fire_auto")


func _fire_auto() -> void:
	_trigger()


func use() -> void:
	_trigger()


func trigger() -> void:
	_trigger()


func _trigger() -> void:
	if not enabled:
		return
	if fire_once and _fired:
		return
	_fired = true
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	GAME.use_targets(self, target)
	if fire_once:
		enabled = false

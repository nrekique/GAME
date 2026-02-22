@tool
class_name LogicAuto
extends Node3D
const Util := preload("res://scripts/util.gd")

@export var target: String = ""
@export var targetfunc: String = ""
@export var targetname: String = ""
@export var master: String = ""
@export var killtarget: String = ""
@export var enabled: bool = true
@export var fire_once: bool = true
@export var delay: float = 0.0

var _fired: bool = false


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
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("fire_once"):
		fire_once = Util.to_bool(props["fire_once"], fire_once)
	if props.has("delay"):
		delay = maxf(float(props["delay"]), 0.0)


func _ready() -> void:
	if Util.editor_hint():
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
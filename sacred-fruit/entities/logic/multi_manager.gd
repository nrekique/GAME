@tool
class_name MultiManager
extends Node3D
const Util := preload("res://scripts/util.gd")

@export var targetname: String = ""
@export var targetfunc: String = ""
@export var enabled: bool = true
@export var trigger_once: bool = false

@export var target1: String = ""
@export var target2: String = ""
@export var target3: String = ""
@export var target4: String = ""
@export var target5: String = ""
@export var target6: String = ""
@export var target7: String = ""
@export var target8: String = ""

@export var delay1: float = 0.0
@export var delay2: float = 0.0
@export var delay3: float = 0.0
@export var delay4: float = 0.0
@export var delay5: float = 0.0
@export var delay6: float = 0.0
@export var delay7: float = 0.0
@export var delay8: float = 0.0

var _used: bool = false


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("targetfunc"):
		targetfunc = String(props["targetfunc"])
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("trigger_once"):
		trigger_once = Util.to_bool(props["trigger_once"], trigger_once)

	for i in range(1, 9):
		var tk := "target%d" % i
		var dk := "delay%d" % i
		if props.has(tk):
			set(tk, String(props[tk]))
		if props.has(dk):
			set(dk, maxf(float(props[dk]), 0.0))


func _ready() -> void:
	if Util.editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)


func use() -> void:
	if not enabled:
		return
	if trigger_once and _used:
		return
	_used = true

	for item in _collect_events():
		var target_group := String(item["target"])
		var delay := float(item["delay"])
		if target_group.is_empty():
			continue
		if delay <= 0.0:
			_fire_group(target_group)
		else:
			call_deferred("_fire_group_after_delay", target_group, delay)

	if trigger_once:
		enabled = false


func _collect_events() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for i in range(1, 9):
		var t := String(get("target%d" % i)).strip_edges()
		var d := maxf(float(get("delay%d" % i)), 0.0)
		if t.is_empty():
			continue
		res.append({
			"target": t,
			"delay": d
		})
	return res


func _fire_group_after_delay(group_name: String, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_fire_group(group_name)


func _fire_group(group_name: String) -> void:
	if group_name.is_empty():
		return
	GAME.use_targets(self, group_name)
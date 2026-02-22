@tool
class_name MathCounter
extends Node3D
const Util := preload("res://scripts/util.gd")

@export var target: String = ""
@export var targetfunc: String = ""
@export var targetname: String = ""
@export var enabled: bool = true
@export var value: float = 0.0
@export var min_value: float = 0.0
@export var max_value: float = 10.0
@export var step: float = 1.0
@export var fire_on_limit_only: bool = true


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = String(props["target"])
	if props.has("targetfunc"):
		targetfunc = String(props["targetfunc"])
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("value"):
		value = float(props["value"])
	elif props.has("start_value"):
		value = float(props["start_value"])
	if props.has("min_value"):
		min_value = float(props["min_value"])
	if props.has("max_value"):
		max_value = float(props["max_value"])
	if props.has("step"):
		step = float(props["step"])
	if props.has("fire_on_limit_only"):
		fire_on_limit_only = Util.to_bool(props["fire_on_limit_only"], fire_on_limit_only)
	value = clampf(value, min_value, max_value)


func _ready() -> void:
	if Util.editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)


func use() -> void:
	add(step)


func add(amount: float) -> void:
	if not enabled:
		return
	var before := value
	value = clampf(value + amount, min_value, max_value)
	_maybe_fire(before, value)


func subtract(amount: float) -> void:
	add(-amount)


func set_value(v: float) -> void:
	if not enabled:
		return
	var before := value
	value = clampf(v, min_value, max_value)
	_maybe_fire(before, value)


func _maybe_fire(before: float, after: float) -> void:
	if is_equal_approx(before, after):
		return
	if fire_on_limit_only:
		var hit_max := before < max_value and is_equal_approx(after, max_value)
		var hit_min := before > min_value and is_equal_approx(after, min_value)
		if not hit_max and not hit_min:
			return
	_fire_targets()


func _fire_targets() -> void:
	var target_group := target.strip_edges()
	if target_group.is_empty():
		return
	GAME.use_targets(self, target_group)
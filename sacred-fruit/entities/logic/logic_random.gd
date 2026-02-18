@tool
class_name LogicRandom
extends Node3D

@export var targetname: String = ""
@export var targetfunc: String = ""
@export var enabled: bool = true
@export var target: String = ""
@export var target1: String = ""
@export var target2: String = ""
@export var target3: String = ""
@export var target4: String = ""
@export var target5: String = ""
@export var target6: String = ""
@export var target7: String = ""
@export var target8: String = ""

var _rng := RandomNumberGenerator.new()


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
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("targetfunc"):
		targetfunc = String(props["targetfunc"])
	if props.has("enabled"):
		enabled = _to_bool(props["enabled"], enabled)
	if props.has("target"):
		target = String(props["target"])
	if props.has("target1"):
		target1 = String(props["target1"])
	if props.has("target2"):
		target2 = String(props["target2"])
	if props.has("target3"):
		target3 = String(props["target3"])
	if props.has("target4"):
		target4 = String(props["target4"])
	if props.has("target5"):
		target5 = String(props["target5"])
	if props.has("target6"):
		target6 = String(props["target6"])
	if props.has("target7"):
		target7 = String(props["target7"])
	if props.has("target8"):
		target8 = String(props["target8"])


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)


func use() -> void:
	if not enabled:
		return
	var pool := _collect_targets()
	if pool.is_empty():
		return
	var pick := pool[_rng.randi_range(0, pool.size() - 1)]
	_fire_group(String(pick))


func _collect_targets() -> PackedStringArray:
	var result := PackedStringArray()
	var seen := {}
	var sources := [target1, target2, target3, target4, target5, target6, target7, target8]
	for s in sources:
		var key := String(s).strip_edges()
		if key.is_empty():
			continue
		if not seen.has(key):
			seen[key] = true
			result.append(key)
	for s in String(target).split(","):
		var key := String(s).strip_edges()
		if key.is_empty():
			continue
		if not seen.has(key):
			seen[key] = true
			result.append(key)
	return result


func _fire_group(group_name: String) -> void:
	if group_name.is_empty():
		return
	GAME.use_targets(self, group_name)

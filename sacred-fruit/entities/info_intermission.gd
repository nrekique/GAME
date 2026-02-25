@tool
class_name InfoIntermission
extends Camera3D
const Util := preload("res://scripts/core/util.gd")

@export var targetname: String = ""
@export var angles: Vector3 = Vector3.ZERO
@export var active: bool = false

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("targetname"):
		targetname = props["targetname"] as String
	if props.has("angles"):
		var a = props["angles"]
		if a is Vector3:
			angles = a
		elif a is String:
			var parts := (a as String).split(" ")
			if parts.size() >= 3:
				angles = Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	if props.has("active"):
		active = props["active"] as bool

func _ready() -> void:
	if Util.editor_hint():
		return
	rotation_degrees = angles
	if targetname != "":
		GAME.set_targetname(self, targetname)
	if active:
		current = true
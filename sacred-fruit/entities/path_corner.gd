@tool
class_name PathCorner
extends Marker3D

@export var target: String = ""
@export var targetname: String = ""
@export var wait: float = 0.0

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = props["target"] as String
	if props.has("targetname"):
		targetname = props["targetname"] as String
	if props.has("wait"):
		wait = props["wait"] as float

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)

@tool
class_name WorldspawnEntity
extends StaticBody3D
const Util := preload("res://scripts/util.gd")

@export var func_godot_properties: Dictionary = {}


func _func_godot_apply_properties(props: Dictionary) -> void:
	func_godot_properties = props.duplicate(true)


func _ready() -> void:
	if Util.editor_hint():
		return
	if GAME != null and GAME.has_method("apply_worldspawn_globals"):
		GAME.call_deferred("apply_worldspawn_globals", func_godot_properties, self)
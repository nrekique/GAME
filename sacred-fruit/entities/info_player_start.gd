@tool
class_name InfoPlayerStart
extends Marker3D
const Util := preload("res://scripts/core/util.gd")

@export var targetname: String = ""
@export var angles: Vector3 = Vector3.ZERO
@export var active: bool = true

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
	if targetname != "":
		GAME.set_targetname(self, targetname)
	if not active:
		return
	var player := _find_player()
	if player == null:
		return
	player.global_position = global_position
	player.rotation_degrees = angles

func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("PLAYER")
	for p in players:
		if p is Node3D:
			return p
	var current := get_tree().current_scene
	if current:
		var by_name := current.get_node_or_null("Player")
		if by_name is Node3D:
			return by_name
	return null
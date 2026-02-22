@tool
class_name TriggerChangeLevel
extends Area3D
const Util := preload("res://scripts/util.gd")

@export var map_path: String = ""
@export var delay: float = 0.0
@export var targetname: String = ""

var _used: bool = false

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("map"):
		map_path = props["map"] as String
	elif props.has("map_path"):
		map_path = props["map_path"] as String
	if props.has("delay"):
		delay = props["delay"] as float
	if props.has("targetname"):
		targetname = props["targetname"] as String

func _init() -> void:
	monitoring = true
	monitorable = false
	connect("body_entered", _on_body_entered)

func _ready() -> void:
	if Util.editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)

func _on_body_entered(body: Node) -> void:
	if Util.editor_hint() or _used:
		return
	if body != null and body.is_in_group("PLAYER"):
		_used = true
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		if map_path != "":
			get_tree().change_scene_to_file(map_path)
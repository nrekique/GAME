@tool
class_name TriggerOnce
extends Area3D
const Util := preload("res://scripts/util.gd")

@export var target: String = ""
@export var targetfunc: String = ""
@export var targetname: String = ""

var _used: bool = false

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = props["target"] as String
	if props.has("targetfunc"):
		targetfunc = props["targetfunc"] as String
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
		GAME.use_targets(self, target)
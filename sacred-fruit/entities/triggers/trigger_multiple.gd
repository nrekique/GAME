@tool
class_name TriggerMultiple
extends Area3D
const Util := preload("res://scripts/util.gd")

@export var target: String = ""
@export var targetfunc: String = ""
@export var targetname: String = ""
@export var wait: float = 1.0

var _ready_to_use: bool = true

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = props["target"] as String
	if props.has("targetfunc"):
		targetfunc = props["targetfunc"] as String
	if props.has("targetname"):
		targetname = props["targetname"] as String
	if props.has("wait"):
		wait = props["wait"] as float

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
	if Util.editor_hint() or not _ready_to_use:
		return
	if body != null and body.is_in_group("PLAYER"):
		_ready_to_use = false
		GAME.use_targets(self, target)
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		_ready_to_use = true
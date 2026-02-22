@tool
class_name FuncButton
extends Area3D
const Util := preload("res://scripts/util.gd")

@export var target: String = ""
@export var targetfunc: String = ""
@export var targetname: String = ""
@export var wait: float = 1.0
@export var once: bool = false
@export var touch_activates: bool = true
@export var interact_activates: bool = true

var _ready_to_use: bool = true


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = String(props["target"])
	if props.has("targetfunc"):
		targetfunc = String(props["targetfunc"])
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("wait"):
		wait = float(props["wait"])
	if props.has("once"):
		once = Util.to_bool(props["once"], once)
	if props.has("touch_activates"):
		touch_activates = Util.to_bool(props["touch_activates"], touch_activates)
	if props.has("interact_activates"):
		interact_activates = Util.to_bool(props["interact_activates"], interact_activates)

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
	if Util.editor_hint() or not _ready_to_use or not touch_activates:
		return
	if body != null and body.is_in_group("PLAYER"):
		_press(body)


func interact(activator: Node = null) -> bool:
	if not interact_activates:
		return false
	_press(activator)
	return true


func use() -> void:
	_press(null)


func trigger() -> void:
	_press(null)


func _press(activator: Node) -> void:
	if Util.editor_hint() or not _ready_to_use:
		return
	_ready_to_use = false
	GAME.use_targets(self, target, {"caller": activator if activator != null else self})
	if once:
		return
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	_ready_to_use = true
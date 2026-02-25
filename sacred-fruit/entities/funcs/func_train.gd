@tool
class_name FuncTrain
extends AnimatableBody3D
const Util := preload("res://scripts/core/util.gd")

@export var target: String = ""
@export var targetname: String = ""
@export var speed: float = 100.0

var _current_corner: PathCorner = null
var _waiting: bool = false

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = props["target"] as String
	if props.has("targetname"):
		targetname = props["targetname"] as String
	if props.has("speed"):
		speed = props["speed"] as float

func _ready() -> void:
	if Util.editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)
	if target != "":
		_current_corner = _find_corner(target)
		if _current_corner:
			global_position = _current_corner.global_position

func _physics_process(delta: float) -> void:
	if Util.editor_hint() or _waiting:
		return
	if _current_corner == null:
		return
	var speed_godot := speed * GameManager.INVERSE_SCALE
	var tgt := _get_next_corner_target()
	if tgt == null:
		return
	var dir := tgt.global_position - global_position
	var dist := dir.length()
	if dist <= 0.05:
		_current_corner = tgt
		if _current_corner.wait > 0.0:
			_wait_then_resume(_current_corner.wait)
		return
	global_position += dir.normalized() * speed_godot * delta

func _get_next_corner_target() -> PathCorner:
	if _current_corner == null:
		return _find_corner(target)
	if _current_corner.target == "":
		return null
	return _find_corner(_current_corner.target)

func _find_corner(target_name: String) -> PathCorner:
	if target_name == "":
		return null
	var nodes := get_tree().get_nodes_in_group(target_name)
	for n in nodes:
		if n is PathCorner:
			return n
	return null

func _wait_then_resume(wait_time: float) -> void:
	if _waiting:
		return
	_waiting = true
	await get_tree().create_timer(wait_time).timeout
	_waiting = false
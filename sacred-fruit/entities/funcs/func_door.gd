@tool
class_name FuncDoor
extends FuncMove

@export var target: String = ""
@export var wait: float = 3.0
@export var auto_close: bool = true
@export var lock_open: bool = false

var _is_open: bool = false
var _closing: bool = false

func _func_godot_apply_properties(props: Dictionary) -> void:
	super._func_godot_apply_properties(props)
	if props.has("target"):
		target = props["target"] as String
	if props.has("wait"):
		wait = props["wait"] as float
	if props.has("auto_close"):
		auto_close = props["auto_close"] as bool
	if props.has("lock_open"):
		lock_open = props["lock_open"] as bool

func use() -> void:
	if not _is_open:
		mv_forward()
		_is_open = true
		if target != "":
			GAME.use_targets(self, target)
			if auto_close and wait > 0.0:
				_schedule_close()
	else:
		if lock_open:
			return
		mv_reverse()
		_is_open = false

func _schedule_close() -> void:
	if _closing:
		return
	_closing = true
	await get_tree().create_timer(wait).timeout
	_closing = false
	if _is_open and auto_close:
		mv_reverse()
		_is_open = false

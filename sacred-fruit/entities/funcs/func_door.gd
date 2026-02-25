@tool
class_name FuncDoor
extends FuncMove

@export var target: String = ""
@export var wait: float = 3.0
@export var auto_close: bool = true
@export var lock_open: bool = false
@export var required_key: String = ""
@export var consume_required_key: bool = false

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
	if props.has("required_key"):
		required_key = String(props["required_key"])
	if props.has("consume_required_key"):
		consume_required_key = Util.to_bool(props["consume_required_key"], consume_required_key)


func can_interact(activator: Node = null) -> bool:
	if _is_open:
		return true
	var needed := required_key.strip_edges().to_lower()
	if needed.is_empty():
		return true
	var game := get_node_or_null("/root/GAME")
	if game == null or not game.has_method("has_key"):
		return false
	return bool(game.call("has_key", needed))


func interact(activator: Node = null) -> bool:
	if not can_interact(activator):
		return false
	if not _is_open and consume_required_key:
		var needed := required_key.strip_edges().to_lower()
		if not needed.is_empty():
			var game := get_node_or_null("/root/GAME")
			if game == null or not game.has_method("consume_key") or not bool(game.call("consume_key", needed)):
				return false
	use()
	return true

func use() -> void:
	if not _is_open:
		mv_forward()
		_is_open = true
		if target != "":
			var game := get_node_or_null("/root/GAME")
			if game != null and game.has_method("use_targets"):
				game.call("use_targets", self, target)
		if auto_close and wait > 0.0 and not lock_open:
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
	if _is_open and auto_close and not lock_open:
		mv_reverse()
		_is_open = false

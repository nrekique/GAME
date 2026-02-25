@tool
class_name Volume
extends Area3D
const Util := preload("res://scripts/core/util.gd")

# generic volume node that tracks overlapping bodies and forwards events
# to an overridable hook. Subclasses should implement `_process_body` with
# whatever logic is desired (damage, checkpoint, etc.).

@export var enabled: bool = true
@export var starts_enabled: bool = true
@export var one_shot: bool = false
@export var save_id: String = ""
@export var amount: float = 1.0  # payload (damage, etc.)
@export var tag: String = ""    # optional group tag for custom logic

var _overlapping: Array[Node] = []
var _fired_once: bool = false

func _ready() -> void:
	if Util.editor_hint():
		return
	_restore_runtime_state()
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not enabled:
		return
	if one_shot and _fired_once:
		return
	_overlapping.append(body)
	_process_body(body, true)
	if one_shot:
		_fired_once = true
		enabled = false
		_persist_runtime_state()

func _on_body_exited(body: Node) -> void:
	_overlapping.erase(body)
	_process_body(body, false)

# default hook; subclasses override.
func _process_body(body: Node, entered: bool) -> void:
	pass

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("starts_enabled"):
		starts_enabled = Util.to_bool(props["starts_enabled"], starts_enabled)
	if props.has("one_shot"):
		one_shot = Util.to_bool(props["one_shot"], one_shot)
	if props.has("save_id"):
		save_id = String(props["save_id"]).strip_edges()
	if props.has("amount"):
		amount = float(props["amount"])
	if props.has("tag"):
		tag = String(props["tag"])

func _restore_runtime_state() -> void:
	enabled = starts_enabled
	var game := get_node_or_null("/root/GAME")
	if game == null:
		return
	if save_id.is_empty():
		return
	if game.has_method("state_get_enabled"):
		enabled = Util.to_bool(game.call("state_get_enabled", save_id, enabled), enabled)
	if one_shot and game.has_method("state_has_fired") and bool(game.call("state_has_fired", save_id)):
		_fired_once = true
		enabled = false

func _persist_runtime_state() -> void:
	var game := get_node_or_null("/root/GAME")
	if game == null:
		return
	if save_id.is_empty():
		return
	if game.has_method("state_set_enabled"):
		game.call("state_set_enabled", save_id, enabled)
	if _fired_once and game.has_method("state_mark_fired"):
		game.call("state_mark_fired", save_id)

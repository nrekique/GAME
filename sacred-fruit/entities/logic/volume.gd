@tool
class_name Volume
extends Area3D

# generic volume node that tracks overlapping bodies and forwards events
# to an overridable hook.  Subclasses should implement `_process_body` with
# whatever logic is desired (damage, checkpoint, etc.).

signal body_entered(body: Node)
signal body_exited(body: Node)

@export var enabled: bool = true
@export var amount: float = 1.0  # payload (damage, etc.)
@export var tag: String = ""    # optional group tag for custom logic

var _overlapping: Array[Node] = []

func _ready() -> void:
	if Util.editor_hint():
		return
	monitoring = true
	connect("body_entered", callable(self, "_on_body_entered"))
	connect("body_exited", callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if not enabled:
		return
	_overlapping.append(body)
	emit_signal("body_entered", body)
	_process_body(body, true)

func _on_body_exited(body: Node) -> void:
	_overlapping.erase(body)
	emit_signal("body_exited", body)
	_process_body(body, false)

# default hook; subclasses override.
func _process_body(body: Node, entered: bool) -> void:
	pass

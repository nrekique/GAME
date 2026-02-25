@tool
class_name AIPatrolPoint
extends Marker3D
const Util := preload("res://scripts/core/util.gd")

@export var enabled: bool = true
@export var route_id: String = "default"
@export var order: int = 0
@export_range(0.0, 30.0, 0.01) var wait: float = 0.0

func _ready() -> void:
	if Util.editor_hint():
		return
	add_to_group("ai_patrol_point")
	add_to_group("ai_patrol_route_%s" % route_id.strip_edges().to_lower())

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("route_id"):
		route_id = String(props["route_id"]).strip_edges()
	if props.has("order"):
		order = int(props["order"])
	if props.has("wait"):
		wait = maxf(float(props["wait"]), 0.0)

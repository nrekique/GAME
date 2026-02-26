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
	_refresh_route_group()

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("route_id"):
		route_id = String(props["route_id"]).strip_edges()
	if props.has("order"):
		order = int(props["order"])
	if props.has("wait"):
		wait = maxf(float(props["wait"]), 0.0)
	_refresh_route_group()


func _refresh_route_group() -> void:
	if not is_inside_tree():
		return
	for group_name_v in get_groups():
		var group_name := String(group_name_v)
		if group_name.begins_with("ai_patrol_route_"):
			remove_from_group(group_name)
	var key := route_id.strip_edges().to_lower()
	if key.is_empty():
		key = "default"
	add_to_group("ai_patrol_route_%s" % key)

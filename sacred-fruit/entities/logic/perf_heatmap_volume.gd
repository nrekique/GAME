@tool
class_name PerfHeatmapVolume
extends Node3D
const Util := preload("res://scripts/core/util.gd")

@export var enabled: bool = true
@export_range(0.0, 200.0, 0.1) var cost: float = 6.0
@export var extents: Vector3 = Vector3(8.0, 4.0, 8.0)
@export var tag: String = ""
@export var budget_limit: float = -1.0


func _ready() -> void:
	if Util.editor_hint():
		return
	add_to_group("perf_heatmap_volume")
	var key := tag.strip_edges().to_lower()
	if not key.is_empty():
		add_to_group("perf_tag_%s" % key)


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("cost"):
		cost = maxf(float(props["cost"]), 0.0)
	if props.has("extents"):
		var e: Variant = props["extents"]
		if e is Vector3:
			extents = (e as Vector3).abs()
	if props.has("tag"):
		tag = String(props["tag"]).strip_edges()
	if props.has("budget_limit"):
		budget_limit = float(props["budget_limit"])


func contains_point(world_point: Vector3) -> bool:
	if not enabled:
		return false
	var local_point: Vector3 = global_transform.affine_inverse() * world_point
	return absf(local_point.x) <= extents.x \
		and absf(local_point.y) <= extents.y \
		and absf(local_point.z) <= extents.z


func estimate_cost_at_point(world_point: Vector3) -> float:
	if contains_point(world_point):
		return cost
	return 0.0

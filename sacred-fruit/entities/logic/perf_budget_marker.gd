@tool
class_name PerfBudgetMarker
extends Node3D
const Util := preload("res://scripts/core/util.gd")

@export var enabled: bool = true
@export_range(0.0, 200.0, 0.1) var cost: float = 4.0
@export_range(0.1, 4096.0, 0.1) var radius: float = 12.0
@export_range(0.1, 8.0, 0.1) var falloff_exponent: float = 1.5
@export var tag: String = ""
@export var budget_limit: float = -1.0


func _ready() -> void:
	if Util.editor_hint():
		return
	add_to_group("perf_budget_marker")
	var key := tag.strip_edges().to_lower()
	if not key.is_empty():
		add_to_group("perf_tag_%s" % key)


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("cost"):
		cost = maxf(float(props["cost"]), 0.0)
	if props.has("radius"):
		radius = maxf(float(props["radius"]), 0.1)
	if props.has("falloff_exponent"):
		falloff_exponent = clampf(float(props["falloff_exponent"]), 0.1, 8.0)
	if props.has("tag"):
		tag = String(props["tag"]).strip_edges()
	if props.has("budget_limit"):
		budget_limit = float(props["budget_limit"])


func estimate_cost_at_point(world_point: Vector3) -> float:
	if not enabled:
		return 0.0
	var d: float = global_position.distance_to(world_point)
	if d >= radius:
		return 0.0
	var t: float = clampf(1.0 - (d / radius), 0.0, 1.0)
	return cost * pow(t, falloff_exponent)

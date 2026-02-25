@tool
class_name AINavRegion
extends Node3D
const Util := preload("res://scripts/core/util.gd")

@export var enabled: bool = true
@export var region_id: String = ""
@export var nav_tag: String = ""
@export_range(0.1, 4096.0, 0.1) var radius: float = 12.0

func _ready() -> void:
	if Util.editor_hint():
		return
	add_to_group("ai_nav_region")
	if not nav_tag.strip_edges().is_empty():
		add_to_group("ai_nav_tag_%s" % nav_tag.strip_edges().to_lower())
	if not region_id.strip_edges().is_empty():
		add_to_group("ai_nav_region_%s" % region_id.strip_edges().to_lower())

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("region_id"):
		region_id = String(props["region_id"]).strip_edges()
	if props.has("nav_tag"):
		nav_tag = String(props["nav_tag"]).strip_edges()
	if props.has("radius"):
		radius = maxf(float(props["radius"]), 0.1)

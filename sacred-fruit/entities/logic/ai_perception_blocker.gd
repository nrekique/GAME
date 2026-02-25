@tool
class_name AIPerceptionBlocker
extends Node3D
const Util := preload("res://scripts/core/util.gd")

@export var enabled: bool = true
@export_range(0.1, 1024.0, 0.1) var radius: float = 4.0

func _ready() -> void:
	if Util.editor_hint():
		return
	add_to_group("ai_perception_blocker")

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("radius"):
		radius = maxf(float(props["radius"]), 0.1)

func blocks_line(start_pos: Vector3, end_pos: Vector3) -> bool:
	if not enabled:
		return false
	var seg := end_pos - start_pos
	var seg_len_sq := seg.length_squared()
	if seg_len_sq <= 0.000001:
		return start_pos.distance_to(global_position) <= radius
	var t := clampf((global_position - start_pos).dot(seg) / seg_len_sq, 0.0, 1.0)
	var closest := start_pos + seg * t
	return closest.distance_to(global_position) <= radius

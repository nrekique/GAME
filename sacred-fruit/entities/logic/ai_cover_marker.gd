@tool
class_name AICoverMarker
extends Marker3D
const Util := preload("res://scripts/util.gd")

@export var enabled: bool = true
@export var team: String = ""
@export_range(0.0, 1.0, 0.01) var exposure: float = 0.25
@export var crouch_only: bool = false

func _ready() -> void:
	if Util.editor_hint():
		return
	add_to_group("ai_cover_marker")
	if not team.strip_edges().is_empty():
		add_to_group("ai_cover_team_%s" % team.strip_edges().to_lower())

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("team"):
		team = String(props["team"]).strip_edges()
	if props.has("exposure"):
		exposure = clampf(float(props["exposure"]), 0.0, 1.0)
	if props.has("crouch_only"):
		crouch_only = Util.to_bool(props["crouch_only"], crouch_only)

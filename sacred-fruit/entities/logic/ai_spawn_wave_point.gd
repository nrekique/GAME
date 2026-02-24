@tool
class_name AISpawnWavePoint
extends Marker3D
const Util := preload("res://scripts/util.gd")

@export var enabled: bool = true
@export var wave_id: String = "default"
@export var squad_id: String = ""
@export var max_spawn_count: int = 1
@export_range(0.0, 60.0, 0.01) var cooldown: float = 0.0

func _ready() -> void:
	if Util.editor_hint():
		return
	add_to_group("ai_spawn_wave_point")
	add_to_group("ai_spawn_wave_%s" % wave_id.strip_edges().to_lower())
	if not squad_id.strip_edges().is_empty():
		add_to_group("ai_spawn_squad_%s" % squad_id.strip_edges().to_lower())

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("wave_id"):
		wave_id = String(props["wave_id"]).strip_edges()
	if props.has("squad_id"):
		squad_id = String(props["squad_id"]).strip_edges()
	if props.has("max_spawn_count"):
		max_spawn_count = maxi(1, int(props["max_spawn_count"]))
	if props.has("cooldown"):
		cooldown = maxf(float(props["cooldown"]), 0.0)

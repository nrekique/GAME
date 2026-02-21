@tool
class_name EnvAudioAmbience
extends Node3D

@export_file("*.ogg", "*.wav", "*.mp3", "*.res", "*.tres") var ambience_stream: String = ""
@export_range(-60.0, 12.0, 0.1) var ambience_volume_db: float = -10.0
@export var ambience_bus: String = "SFX"


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("ambience_stream"):
		ambience_stream = String(props["ambience_stream"]).strip_edges()
	if props.has("ambience_volume_db"):
		ambience_volume_db = clampf(float(props["ambience_volume_db"]), -60.0, 12.0)
	if props.has("ambience_bus"):
		ambience_bus = String(props["ambience_bus"]).strip_edges()

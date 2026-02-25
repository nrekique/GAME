@tool
extends GPUParticles3D
const Util := preload("res://scripts/core/util.gd")

@export var extra_lifetime: float = 0.2

func _ready() -> void:
	if Util.editor_hint():
		return
	var total := maxf(0.0, lifetime + extra_lifetime)
	await get_tree().create_timer(total).timeout
	queue_free()
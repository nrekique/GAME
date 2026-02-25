extends Node


func _ready() -> void:
	var gm := preload("res://game_manager.gd").new()
	add_child(gm)
	Engine.set_singleton("GAME", gm)
	await get_tree().process_frame

	var marker := preload("res://entities/logic/perf_budget_marker.gd").new()
	marker.cost = 10.0
	marker.radius = 10.0
	marker.falloff_exponent = 1.0
	marker.global_position = Vector3.ZERO
	add_child(marker)

	var vol := preload("res://entities/logic/perf_heatmap_volume.gd").new()
	vol.cost = 5.0
	vol.extents = Vector3(2.0, 2.0, 2.0)
	vol.global_position = Vector3(1.0, 0.0, 0.0)
	add_child(vol)
	await get_tree().process_frame

	var center := gm.get_perf_budget_at_point(Vector3.ZERO)
	assert(float(center.get("score", 0.0)) > 10.0)
	assert(String(center.get("status", "")) == "warn" or String(center.get("status", "")) == "critical")
	print("[TEST] Perf budget aggregation reports center score")

	var far := gm.get_perf_budget_at_point(Vector3(100.0, 0.0, 0.0))
	assert(float(far.get("score", -1.0)) == 0.0)
	assert(String(far.get("status", "")) == "ok")
	print("[TEST] Perf budget aggregation reports zero outside influence")

	get_tree().quit()

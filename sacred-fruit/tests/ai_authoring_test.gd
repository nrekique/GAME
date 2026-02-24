extends Node

var _ai_alert_called := false

func _ready() -> void:
	var gm := preload("res://game_manager.gd").new()
	add_child(gm)
	Engine.set_singleton("GAME", gm)
	await get_tree().process_frame

	gm.ai_alerted.connect(_on_ai_alerted)
	gm.alert_ai(Vector3(1, 2, 3), self)
	assert(_ai_alert_called)
	print("[TEST] GAME.ai_alerted signal emitted")

	var patrol_script := preload("res://entities/logic/ai_patrol_point.gd")
	var p0 := patrol_script.new()
	p0.route_id = "route_a"
	p0.order = 2
	add_child(p0)
	var p1 := patrol_script.new()
	p1.route_id = "route_a"
	p1.order = 0
	add_child(p1)
	var p2 := patrol_script.new()
	p2.route_id = "route_a"
	p2.order = 1
	add_child(p2)
	await get_tree().process_frame
	var patrol_points := gm.get_ai_patrol_points("route_a")
	assert(patrol_points.size() == 3)
	assert(int(patrol_points[0].order) == 0)
	assert(int(patrol_points[1].order) == 1)
	assert(int(patrol_points[2].order) == 2)
	print("[TEST] Patrol route points sorted by order")

	var cover_script := preload("res://entities/logic/ai_cover_marker.gd")
	var c0 := cover_script.new()
	c0.team = "red"
	add_child(c0)
	var c1 := cover_script.new()
	c1.team = "blue"
	add_child(c1)
	await get_tree().process_frame
	assert(gm.get_ai_cover_markers("red").size() == 1)
	assert(gm.get_ai_cover_markers("").size() >= 2)
	print("[TEST] Cover marker team filtering works")

	var block_script := preload("res://entities/logic/ai_perception_blocker.gd")
	var blocker := block_script.new()
	blocker.radius = 2.0
	blocker.global_position = Vector3.ZERO
	add_child(blocker)
	await get_tree().process_frame
	assert(gm.is_ai_perception_blocked(Vector3(-4, 0, 0), Vector3(4, 0, 0)))
	assert(not gm.is_ai_perception_blocked(Vector3(-4, 0, 5), Vector3(4, 0, 5)))
	print("[TEST] Perception blocker line test works")

	var wave_point_script := preload("res://entities/logic/ai_spawn_wave_point.gd")
	var wp_a := wave_point_script.new()
	wp_a.wave_id = "wave_a"
	wp_a.squad_id = "alpha"
	wp_a.max_spawn_count = 1
	wp_a.global_position = Vector3(3, 0, 0)
	add_child(wp_a)
	var wp_b := wave_point_script.new()
	wp_b.wave_id = "wave_a"
	wp_b.squad_id = "beta"
	wp_b.global_position = Vector3(5, 0, 0)
	add_child(wp_b)
	await get_tree().process_frame
	assert(gm.get_ai_spawn_wave_points("wave_a", "alpha").size() == 1)
	assert(gm.get_ai_spawn_wave_points("wave_a", "").size() >= 2)
	print("[TEST] Spawn wave point filtering works")

	var npc_anchor := preload("res://entities/actors/npc/npc_spawn_anchor.gd").new()
	npc_anchor.ai_enabled = true
	npc_anchor.ai_route_id = "route_a"
	npc_anchor.global_position = Vector3(-2, 0, 0)
	add_child(npc_anchor)
	await get_tree().process_frame
	var ctrl := npc_anchor.get_node_or_null("AIController")
	assert(ctrl != null)
	gm.alert_ai(Vector3(2, 0, 0), self)
	ctrl._process(0.05)
	assert(String(ctrl.get("_state")) == "alert")
	print("[TEST] NPC anchor attaches AIController when enabled")

	var spawner := preload("res://entities/logic/ai_wave_spawner.gd").new()
	spawner.wave_id = "wave_a"
	spawner.squad_id = "alpha"
	spawner.spawn_interval = 0.01
	spawner.total_spawn_limit = 1
	spawner.max_alive = 1
	spawner.spawn_on_ready = false
	var npc_stub := Node3D.new()
	var npc_packed := PackedScene.new()
	npc_packed.pack(npc_stub)
	spawner.npc_scene = npc_packed
	var child_count_before := get_child_count()
	add_child(spawner)
	spawner.trigger_wave()
	for i in range(10):
		spawner._process(0.02)
		await get_tree().process_frame
	assert(get_child_count() > child_count_before)
	print("[TEST] AI wave spawner spawned at least one NPC")

	var spawner_limit := preload("res://entities/logic/ai_wave_spawner.gd").new()
	spawner_limit.wave_id = "wave_a"
	spawner_limit.squad_id = "alpha"
	spawner_limit.spawn_interval = 0.01
	spawner_limit.total_spawn_limit = 4
	spawner_limit.max_alive = 4
	spawner_limit.spawn_on_ready = false
	spawner_limit.npc_scene = npc_packed
	add_child(spawner_limit)
	spawner_limit.trigger_wave()
	for i in range(20):
		spawner_limit._process(0.02)
		await get_tree().process_frame
	assert(int(spawner_limit.get("_spawned_total")) == 1)
	print("[TEST] Wave spawner respects point max_spawn_count")

	var spawner_path := preload("res://entities/logic/ai_wave_spawner.gd").new()
	spawner_path._func_godot_apply_properties({"npc_scene": "res://entities/actors/npc/npc.tscn"})
	var resolved := spawner_path.call("_resolve_npc_scene")
	assert(resolved is PackedScene)
	print("[TEST] Wave spawner accepts npc_scene path key")

	get_tree().quit()

func _on_ai_alerted(_pos: Vector3, _source: Node) -> void:
	_ai_alert_called = true

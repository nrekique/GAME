extends SceneTree
const FUNC_PORTAL_SCRIPT: Script = preload("res://entities/funcs/func_portal.gd")

const DEFAULT_PAIRS: int = 16
const DEFAULT_SAMPLE_SECONDS: float = 8.0
const DEFAULT_WARMUP_SECONDS: float = 2.0
const DEFAULT_RENDER_SCALE: float = 0.5
const DEFAULT_KEEP_HOT: bool = true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var config: Dictionary = _parse_args(OS.get_cmdline_user_args())
	print("Portal stress: config=", JSON.stringify(config))

	var root := Node3D.new()
	root.name = "PortalStressRoot"
	get_root().add_child(root)

	var cam := Camera3D.new()
	cam.name = "BenchCamera"
	cam.current = true
	cam.near = 0.01
	cam.far = 4000.0
	cam.fov = 75.0
	cam.position = Vector3(0.0, 1.4, -10.0)
	root.add_child(cam)

	_add_floor(root)
	_spawn_portal_pairs(root, int(config["pairs"]), float(config["render_scale"]), bool(config["keep_hot"]))

	await _wait_seconds(float(config["warmup_seconds"]))

	var frame_times_ms: PackedFloat32Array = PackedFloat32Array()
	var sample_begin_usec: int = Time.get_ticks_usec()
	var sample_end_usec: int = sample_begin_usec + int(config["sample_seconds"] * 1000000.0)
	var prev_usec: int = sample_begin_usec
	while Time.get_ticks_usec() < sample_end_usec:
		var now_usec: int = Time.get_ticks_usec()
		var dt_ms: float = float(now_usec - prev_usec) / 1000.0
		prev_usec = now_usec
		frame_times_ms.append(dt_ms)
		await process_frame

	if frame_times_ms.is_empty():
		push_error("Portal stress: no frame data collected")
		quit(1)
		return

	var stats := _compute_stats(frame_times_ms)
	var result := {
		"pairs": int(config["pairs"]),
		"portals": int(config["pairs"]) * 2,
		"render_scale": float(config["render_scale"]),
		"keep_hot": bool(config["keep_hot"]),
		"samples": frame_times_ms.size(),
		"avg_fps": stats["avg_fps"],
		"p95_ms": stats["p95_ms"],
		"p99_ms": stats["p99_ms"],
		"max_ms": stats["max_ms"],
	}
	print("Portal stress: result=", JSON.stringify(result))
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var cfg := {
		"pairs": DEFAULT_PAIRS,
		"sample_seconds": DEFAULT_SAMPLE_SECONDS,
		"warmup_seconds": DEFAULT_WARMUP_SECONDS,
		"render_scale": DEFAULT_RENDER_SCALE,
		"keep_hot": DEFAULT_KEEP_HOT,
	}
	for arg in args:
		var s: String = String(arg)
		if s.begins_with("--pairs="):
			cfg["pairs"] = maxi(1, int(s.substr(8)))
		elif s.begins_with("--seconds="):
			cfg["sample_seconds"] = maxf(1.0, float(s.substr(10)))
		elif s.begins_with("--warmup="):
			cfg["warmup_seconds"] = maxf(0.0, float(s.substr(9)))
		elif s.begins_with("--scale="):
			cfg["render_scale"] = clampf(float(s.substr(8)), 0.25, 1.0)
		elif s.begins_with("--keep-hot="):
			cfg["keep_hot"] = _parse_bool(s.substr(11), DEFAULT_KEEP_HOT)
	return cfg


func _parse_bool(raw: String, default_value: bool) -> bool:
	match raw.strip_edges().to_lower():
		"1", "true", "yes", "on", "y":
			return true
		"0", "false", "no", "off", "n":
			return false
		_:
			return default_value


func _wait_seconds(seconds: float) -> void:
	var end_usec := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < end_usec:
		await process_frame


func _add_floor(root: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(300.0, 300.0)
	floor.mesh = mesh
	floor.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	floor.position = Vector3(0.0, -1.0, 60.0)
	root.add_child(floor)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	root.add_child(light)


func _spawn_portal_pairs(root: Node3D, pairs: int, render_scale: float, keep_hot: bool) -> void:
	var cols: int = maxi(1, int(ceil(sqrt(float(pairs)))))
	var spacing_x: float = 5.0
	var spacing_y: float = 4.0
	var base_z: float = 20.0
	var exit_z_offset: float = 8.0

	for i in range(pairs):
		var row: int = i / cols
		var col: int = i % cols
		var x: float = (float(col) - float(cols - 1) * 0.5) * spacing_x
		var y: float = 1.4 + float(row) * spacing_y
		var portal_a := _make_portal(
			"PortalA_%d" % i,
			"portal_a_%d" % i,
			"portal_b_%d" % i,
			Vector3(x, y, base_z),
			Vector3(0.0, 0.0, -1.0),
			render_scale,
			keep_hot
		)
		var portal_b := _make_portal(
			"PortalB_%d" % i,
			"portal_b_%d" % i,
			"portal_a_%d" % i,
			Vector3(x, y, base_z + exit_z_offset),
			Vector3(0.0, 0.0, 1.0),
			render_scale,
			keep_hot
		)
		root.add_child(portal_a)
		root.add_child(portal_b)


func _make_portal(
		node_name: String,
		targetname: String,
		target: String,
		world_pos: Vector3,
		world_normal: Vector3,
		render_scale: float,
		keep_hot: bool
	) -> Node3D:
	var portal := FUNC_PORTAL_SCRIPT.new() as Node3D
	if portal == null:
		return Node3D.new()
	portal.name = node_name
	portal.targetname = targetname
	portal.target = target
	portal.portal_debug = false
	portal.use_portals_plugin = true
	portal.plugin_face_from_portal_texture = true
	portal.plugin_keep_viewports_hot = keep_hot
	portal.render_scale = render_scale
	portal.position = world_pos
	portal.set_meta("func_godot_mesh_data", {
		"normals": PackedVector3Array([world_normal.normalized()]),
		"positions": PackedVector3Array([world_pos]),
		"textures": PackedInt32Array([0]),
		"texture_names": ["portal_surface"]
	})
	return portal


func _compute_stats(samples_ms: PackedFloat32Array) -> Dictionary:
	var n: int = samples_ms.size()
	var total_ms: float = 0.0
	var max_ms: float = 0.0
	for v in samples_ms:
		total_ms += v
		max_ms = maxf(max_ms, v)
	var avg_ms: float = total_ms / float(n)
	var sorted: Array = []
	sorted.resize(n)
	for i in range(n):
		sorted[i] = float(samples_ms[i])
	sorted.sort()
	var p95_ms: float = float(sorted[min(n - 1, int(floor(float(n - 1) * 0.95)))])
	var p99_ms: float = float(sorted[min(n - 1, int(floor(float(n - 1) * 0.99)))])
	var avg_fps: float = 1000.0 / maxf(avg_ms, 0.0001)
	return {
		"avg_ms": avg_ms,
		"avg_fps": avg_fps,
		"p95_ms": p95_ms,
		"p99_ms": p99_ms,
		"max_ms": max_ms,
	}

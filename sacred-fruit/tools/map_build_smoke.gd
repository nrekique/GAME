extends SceneTree

const FuncGodotMap := preload("res://addons/func_godot/src/map/func_godot_map.gd")

const DEFAULT_TIMEOUT_SECONDS: float = 45.0
const DEFAULT_MAPS: PackedStringArray = PackedStringArray(["res://tb/maps/fgd test.map"])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cfg: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var timeout_seconds: float = float(cfg.get("timeout_seconds", DEFAULT_TIMEOUT_SECONDS))
	var map_args: PackedStringArray = cfg.get("maps", DEFAULT_MAPS)

	if map_args.is_empty():
		push_error("map_build_smoke: no maps provided")
		quit(2)
		return

	var failures: Array[String] = []
	var summaries: Array[Dictionary] = []

	for raw_map in map_args:
		var map_path: String = _resolve_map_arg(String(raw_map))
		if map_path.is_empty():
			failures.append("unresolvable map arg: %s" % String(raw_map))
			continue
		if not FileAccess.file_exists(map_path):
			failures.append("map does not exist: %s" % map_path)
			continue

		var result: Dictionary = await _build_single_map(map_path, timeout_seconds)
		summaries.append(result)
		print("MAP_SMOKE_RESULT=" + JSON.stringify(result))
		if not bool(result.get("ok", false)):
			failures.append(String(result.get("message", "build failed")))

	var summary := {
		"ok": failures.is_empty(),
		"maps": summaries.size(),
		"failed": failures.size(),
		"failures": failures,
	}
	print("MAP_SMOKE_SUMMARY=" + JSON.stringify(summary))

	if failures.is_empty():
		quit(0)
	else:
		quit(1)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var maps := PackedStringArray()
	var timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS

	for arg_v in args:
		var arg: String = String(arg_v)
		if arg.begins_with("--map="):
			var map_arg := arg.substr("--map=".length()).strip_edges()
			if not map_arg.is_empty():
				maps.append(map_arg)
		elif arg.begins_with("--timeout="):
			timeout_seconds = maxf(1.0, float(arg.substr("--timeout=".length())))

	if maps.is_empty():
		maps = DEFAULT_MAPS

	return {
		"maps": maps,
		"timeout_seconds": timeout_seconds,
	}


func _resolve_map_arg(raw_path: String) -> String:
	var p: String = raw_path.strip_edges()
	if p.begins_with("\"") and p.ends_with("\"") and p.length() >= 2:
		p = p.substr(1, p.length() - 2)
	p = p.replace("\\", "/")
	if p.is_empty():
		return ""

	if p.begins_with("res://"):
		return p
	if p.begins_with("tb/"):
		return "res://" + p
	if p.begins_with("/tb/"):
		return "res://" + p.substr(1)
	if p.begins_with("./tb/"):
		return "res://" + p.substr(2)

	if p.is_absolute_path():
		var project_root: String = ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path()
		var abs_path: String = p.simplify_path()
		if abs_path.begins_with(project_root):
			var rel: String = abs_path.substr(project_root.length())
			if rel.begins_with("/"):
				rel = rel.substr(1)
			return "res://" + rel
		return ""

	var rel_candidate: String = "res://" + p
	if FileAccess.file_exists(rel_candidate):
		return rel_candidate
	var tb_maps_candidate: String = "res://tb/maps/" + p.get_file()
	if FileAccess.file_exists(tb_maps_candidate):
		return tb_maps_candidate
	var tb_candidate: String = "res://tb/" + p.get_file()
	if FileAccess.file_exists(tb_candidate):
		return tb_candidate
	return ""


func _build_single_map(map_path: String, timeout_seconds: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "MapBuildSmokeRoot"
	get_root().add_child(root)

	var map := FuncGodotMap.new()
	map.name = "FuncGodotMapSmoke"
	map.local_map_file = map_path
	map.global_map_file = map_path
	root.add_child(map)

	var done := false
	var ok := false
	var failure_message := ""

	map.build_complete.connect(func() -> void:
		done = true
		ok = true
	)
	map.build_failed.connect(func() -> void:
		done = true
		ok = false
		failure_message = "FuncGodotMap build_failed signal emitted"
	)

	var started_usec: int = Time.get_ticks_usec()
	map.verify_and_build()

	var deadline_usec: int = started_usec + int(timeout_seconds * 1000000.0)
	while not done and Time.get_ticks_usec() < deadline_usec:
		await process_frame

	if not done:
		ok = false
		done = true
		failure_message = "map build timed out after %.1fs" % timeout_seconds

	var elapsed_ms: float = float(Time.get_ticks_usec() - started_usec) / 1000.0
	var mesh_count: int = root.find_children("*", "MeshInstance3D", true, false).size()
	var collider_count: int = root.find_children("*", "CollisionShape3D", true, false).size()

	root.queue_free()
	await process_frame

	return {
		"ok": ok,
		"map": map_path,
		"elapsed_ms": elapsed_ms,
		"mesh_count": mesh_count,
		"collider_count": collider_count,
		"message": "PASS" if ok else failure_message,
	}

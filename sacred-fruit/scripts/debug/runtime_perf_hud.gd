extends CanvasLayer

const PORTAL_MANAGER_PATH := "/root/PortalRuntimeManager"
const MIRROR_MANAGER_PATH := "/root/MirrorRuntimeManager"

@export var enabled: bool = true
@export_range(0.05, 1.0, 0.01) var refresh_seconds: float = 0.2
@export var toggle_action: StringName = &"debug_toggle_perf_hud"
@export var csv_logging_enabled: bool = false
@export var csv_toggle_action: StringName = &"debug_toggle_perf_csv"
@export var show_budget_summary: bool = true

var _label: Label
var _accum: float = 0.0
var _visible: bool = true
var _csv_file: FileAccess = null
var _csv_path: String = ""


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(toggle_action):
		InputMap.add_action(toggle_action)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F8
		InputMap.action_add_event(toggle_action, ev)
	if not InputMap.has_action(csv_toggle_action):
		InputMap.add_action(csv_toggle_action)
		var ev_csv := InputEventKey.new()
		ev_csv.physical_keycode = KEY_F9
		InputMap.action_add_event(csv_toggle_action, ev_csv)
	_label = Label.new()
	_label.name = "PerfLabel"
	_label.position = Vector2(12.0, 40.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	_update_text()


func _process(delta: float) -> void:
	if InputMap.has_action(toggle_action) and Input.is_action_just_pressed(toggle_action):
		_visible = not _visible
		visible = _visible
		return
	if InputMap.has_action(csv_toggle_action) and Input.is_action_just_pressed(csv_toggle_action):
		csv_logging_enabled = not csv_logging_enabled
		if not csv_logging_enabled:
			_close_csv_log()
		else:
			_open_csv_log()
		_update_text()
		return
	if not enabled or not _visible:
		return
	_accum += delta
	if _accum < refresh_seconds:
		return
	_accum = 0.0
	_update_text()


func _update_text() -> void:
	if _label == null:
		return
	var fps: float = Engine.get_frames_per_second()
	var frame_ms: float = (1000.0 / fps) if fps > 0.0 else 0.0
	var process_ms: float = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var physics_ms: float = float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	var portal_total: int = get_tree().get_nodes_in_group("func_portal").size()
	var portal_active: int = portal_total
	var portal_mgr: Node = get_node_or_null(PORTAL_MANAGER_PATH)
	if portal_mgr != null:
		if portal_mgr.has_method("get_total_count"):
			portal_total = int(portal_mgr.call("get_total_count"))
		if portal_mgr.has_method("get_active_count"):
			portal_active = int(portal_mgr.call("get_active_count"))

	var mirror_total: int = get_tree().get_nodes_in_group("func_mirror").size()
	var mirror_active: int = mirror_total
	var mirror_mgr: Node = get_node_or_null(MIRROR_MANAGER_PATH)
	if mirror_mgr != null:
		if mirror_mgr.has_method("get_total_count"):
			mirror_total = int(mirror_mgr.call("get_total_count"))
		if mirror_mgr.has_method("get_active_count"):
			mirror_active = int(mirror_mgr.call("get_active_count"))

	if csv_logging_enabled:
		_append_csv_sample(fps, frame_ms, process_ms, physics_ms, draw_calls, portal_active, portal_total, mirror_active, mirror_total)

	var csv_state: String = "ON" if csv_logging_enabled else "OFF"
	var budget_line: String = ""
	if show_budget_summary:
		var game := get_node_or_null("/root/GAME")
		var cam := get_viewport().get_camera_3d()
		if game != null and cam != null and game.has_method("get_perf_budget_at_point"):
			var budget: Dictionary = game.call("get_perf_budget_at_point", cam.global_position, "")
			var score: float = float(budget.get("score", 0.0))
			var status: String = String(budget.get("status", "ok"))
			var markers: int = int(budget.get("marker_hits", 0))
			var volumes: int = int(budget.get("volume_hits", 0))
			var budget_limit: float = float(budget.get("budget_limit", -1.0))
			if budget_limit > 0.0:
				budget_line = "\nBudget %.1f/%.1f (%s) [m:%d v:%d]" % [score, budget_limit, status, markers, volumes]
			else:
				var warn_th: float = float(budget.get("warning_threshold", 0.0))
				var crit_th: float = float(budget.get("critical_threshold", 0.0))
				budget_line = "\nBudget %.1f (warn %.1f / crit %.1f) (%s) [m:%d v:%d]" % [score, warn_th, crit_th, status, markers, volumes]
	_label.text = "PERF HUD (F8)\nCSV LOG (F9): %s\nFPS %.1f  Frame %.2f ms\nProcess %.2f ms  Physics %.2f ms\nDraw Calls %d\nPortals %d/%d active\nMirrors %d/%d active%s" % [
		csv_state,
		fps,
		frame_ms,
		process_ms,
		physics_ms,
		draw_calls,
		portal_active,
		portal_total,
		mirror_active,
		mirror_total,
		budget_line
	]


func _open_csv_log() -> void:
	if _csv_file != null:
		return
	var logs_dir: String = "user://logs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(logs_dir))
	var ts: int = int(Time.get_unix_time_from_system())
	_csv_path = "%s/perf_%d.csv" % [logs_dir, ts]
	_csv_file = FileAccess.open(_csv_path, FileAccess.WRITE)
	if _csv_file == null:
		csv_logging_enabled = false
		return
	_csv_file.store_line("unix_time,fps,frame_ms,process_ms,physics_ms,draw_calls,portals_active,portals_total,mirrors_active,mirrors_total")


func _append_csv_sample(fps: float, frame_ms: float, process_ms: float, physics_ms: float,
		draw_calls: int, portal_active: int, portal_total: int, mirror_active: int, mirror_total: int) -> void:
	if _csv_file == null:
		_open_csv_log()
		if _csv_file == null:
			return
	var unix_time: float = Time.get_unix_time_from_system()
	_csv_file.store_line("%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%d,%d" % [
		unix_time,
		fps,
		frame_ms,
		process_ms,
		physics_ms,
		draw_calls,
		portal_active,
		portal_total,
		mirror_active,
		mirror_total
	])
	_csv_file.flush()


func _close_csv_log() -> void:
	if _csv_file == null:
		return
	_csv_file.flush()
	_csv_file.close()
	_csv_file = null


func _exit_tree() -> void:
	_close_csv_log()

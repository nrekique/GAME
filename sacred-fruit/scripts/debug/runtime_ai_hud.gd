extends CanvasLayer

@export var enabled: bool = true
@export_range(0.05, 1.0, 0.01) var refresh_seconds: float = 0.25
@export var toggle_action: StringName = &"debug_toggle_ai_hud"

var _label: Label
var _accum: float = 0.0
var _visible: bool = true


func _ready() -> void:
	layer = 121
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(toggle_action):
		InputMap.add_action(toggle_action)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F7
		InputMap.action_add_event(toggle_action, ev)
	_label = Label.new()
	_label.name = "AIHudLabel"
	_label.position = Vector2(12.0, 170.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
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
	var game := get_node_or_null("/root/GAME")
	var nav_count := 0
	var patrol_default_count := 0
	var patrol_active_route_count := 0
	var cover_count := 0
	var wave_point_count := 0
	var controller_count := get_tree().get_nodes_in_group("ai_controller").size()
	var active_route := "default"
	for ctrl in get_tree().get_nodes_in_group("ai_controller"):
		if ctrl == null or not is_instance_valid(ctrl):
			continue
		if "route_id" in ctrl:
			active_route = String(ctrl.get("route_id")).strip_edges()
			if active_route.is_empty():
				active_route = "default"
			break
	if game != null:
		if game.has_method("get_ai_nav_regions"):
			nav_count = (game.call("get_ai_nav_regions", "") as Array).size()
		if game.has_method("get_ai_patrol_points"):
			patrol_default_count = (game.call("get_ai_patrol_points", "default") as Array).size()
			patrol_active_route_count = (game.call("get_ai_patrol_points", active_route) as Array).size()
		if game.has_method("get_ai_cover_markers"):
			cover_count = (game.call("get_ai_cover_markers", "") as Array).size()
		if game.has_method("get_ai_spawn_wave_points"):
			wave_point_count = (game.call("get_ai_spawn_wave_points", "default", "") as Array).size()

	var state_counts: Dictionary = {}
	var samples: Array[String] = []
	for ctrl in get_tree().get_nodes_in_group("ai_controller"):
		if ctrl == null or not is_instance_valid(ctrl):
			continue
		var snap: Dictionary = {}
		if ctrl.has_method("get_debug_snapshot"):
			snap = ctrl.call("get_debug_snapshot")
		var state: String = String(snap.get("state", "unknown"))
		state_counts[state] = int(state_counts.get(state, 0)) + 1
		if samples.size() < 3:
			var route: String = String(snap.get("route_id", ""))
			var points: int = int(snap.get("patrol_points", 0))
			var has_agent: bool = bool(snap.get("has_agent", false))
			var moving: bool = bool(snap.get("is_moving", false))
			samples.append("%s(route=%s points=%d agent=%s moving=%s)" % [state, route, points, str(has_agent), str(moving)])

	var state_line := "none"
	if not state_counts.is_empty():
		var parts: Array[String] = []
		for key in state_counts.keys():
			parts.append("%s:%d" % [String(key), int(state_counts[key])])
		parts.sort()
		state_line = ", ".join(parts)
	var sample_line := "n/a" if samples.is_empty() else " | ".join(samples)

	_label.text = "AI HUD (F7)\nControllers %d  States [%s]\nNav %d  Patrol(default) %d  Patrol(%s) %d  Cover %d  WavePoints(default) %d\nSample %s" % [
		controller_count,
		state_line,
		nav_count,
		patrol_default_count,
		active_route,
		patrol_active_route_count,
		cover_count,
		wave_point_count,
		sample_line
	]

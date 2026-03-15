class_name GameManager
extends Node
const Util := preload("res://scripts/core/util.gd")

# Common inverse scale. Calculated as 1.0 / Inverse Scale Factor. 
# Used to help translate properties using Quake Units into Godot Units.
const INVERSE_SCALE: float = 0.03125

signal objective_text_changed(text: String)
signal collectible_count_changed(collected: int, required: int)
signal exit_unlocked()
signal player_health_changed(current: int, max_health: int, max_overhealth: int)
signal player_died()
signal io_event_dispatched(event: Dictionary)
signal ai_alerted(position: Vector3, source: Node)
signal keys_changed(keys: PackedStringArray)

enum {
	WORLD_LAYER = (1 << 0),
	ACTOR_LAYER = (1 << 1),
	TRIGGER_LAYER = (1 << 2)
}

@export var required_collectibles: int = 3

# PS1 shader configuration has been refactored into a dedicated manager.
const PS1ShaderManager := preload("res://scripts/env/ps1_shader_manager.gd")
var ps1_mgr: PS1ShaderManager = PS1ShaderManager.new()
const INFO_PLAYER_START_SCRIPT: Script = preload("res://entities/info_player_start.gd")
const ENV_ZONE_SCRIPT: Script = preload("res://entities/logic/env_zone.gd")

@export var io_debug_logging: bool = false
@export_range(16, 1024, 1) var io_trace_capacity: int = 256
@export_range(0.0, 500.0, 0.1) var perf_budget_warning_score: float = 12.0
@export_range(0.0, 500.0, 0.1) var perf_budget_critical_score: float = 20.0

# runtime configuration ----------------------------------------------------
# value read from project settings by `scripts/build_profile.sh`.
@export var build_profile: String = ""  # populated during _ready()

# convenience helpers for conditional logic based on profile
func is_profile(name: String) -> bool:
	return build_profile == name

func is_shipping() -> bool:
	return is_profile("shipping")

func is_playtest() -> bool:
	return is_profile("playtest")

func is_fast_iteration() -> bool:
	return is_profile("fast-iteration")


var collected_collectibles: int = 0
var _keys: Dictionary = {}
var _hud: CanvasLayer = null
var _exit_unlocked_emitted: bool = false
var _has_won: bool = false

var _player: Node = null
var player_health: int = 0
var player_max_health: int = 0
var player_max_overhealth: int = 0
const NO_HUD_GROUP := "NO_HUD"

var _last_worldspawn_id: int = -1

# worldspawn collision optimisation threshold
const WORLDSPAWN_COLLIDER_THRESHOLD: int = 250
const RUNTIME_STATE_PATH := "user://runtime_state.cfg"
const RUNTIME_STATE_BACKUP_PATH := RUNTIME_STATE_PATH + ".bak"
const ZONE_LIGHTING_UPDATE_INTERVAL := 0.10

var _runtime_entity_enabled: Dictionary = {}
var _runtime_fired_once: Dictionary = {}
var _runtime_checkpoints: Dictionary = {}
var _runtime_active_checkpoint_id: String = ""

var _zone_lighting_elapsed: float = 0.0
var _zone_light_base_masks: Dictionary = {}
var _zone_probe_base_masks: Dictionary = {}
var _zone_probe_base_intensity: Dictionary = {}
var _zone_last_hash: int = 0


func _get_node_prop(node: Node, key: String, default_value: Variant = null) -> Variant:
	if node == null or key.is_empty():
		return default_value
	if key in node:
		return node.get(key)
	if "func_godot_properties" in node:
		var props_var: Variant = node.func_godot_properties
		if props_var is Dictionary:
			var props := props_var as Dictionary
			if props.has(key):
				return props[key]
	if node.has_meta("func_godot_properties"):
		var meta_props_var: Variant = node.get_meta("func_godot_properties")
		if meta_props_var is Dictionary:
			var meta_props := meta_props_var as Dictionary
			if meta_props.has(key):
				return meta_props[key]
	return default_value


func _worldspawn_has_source_prop(worldspawn: Node, key: String) -> bool:
	if worldspawn == null or key.is_empty():
		return false
	if not worldspawn.has_meta("func_godot_source_properties"):
		return false
	var src_var: Variant = worldspawn.get_meta("func_godot_source_properties")
	if not (src_var is Dictionary):
		return false
	return (src_var as Dictionary).has(key)


func _is_script_instance(node: Node, script_res: Script) -> bool:
	if node == null or script_res == null:
		return false
	return node.get_script() == script_res




# --- IO manager facade methods ------------------------------------------------

const IOManager := preload("res://scripts/core/io_manager.gd")
var io_mgr: IOManager = IOManager.new()

func use_targets(activator: Node, target: String, overrides: Dictionary = {}) -> void:
	io_mgr.use_targets(activator, target, overrides)

func io_fire_output(activator: Node, output_value: String, source_output: String = "", default_input: String = "use") -> void:
	io_mgr.io_fire_output(activator, output_value, source_output, default_input)

func fire_output(activator: Node, output_key: String, fallback_target: String = "", default_input: String = "use") -> void:
	io_mgr.fire_output(activator, output_key, fallback_target, default_input)

func set_targetname(node: Node, targetname: String) -> void:
	io_mgr.set_targetname(node, targetname)

func io_get_trace() -> Array[Dictionary]:
	return io_mgr.io_get_trace()

# Converts Quake 1 axis to Godot axis
static func id_vec_to_godot_vec(vec: Variant)->Vector3:
	var org: Vector3 = Vector3.ZERO
	if vec is Vector3:
		org = vec
	elif vec is String:
		var arr: PackedFloat64Array = (vec as String).split_floats(" ")
		for i in min(arr.size(), 3):
			org[i] = float(arr[i])
	return Vector3(org.y, org.z, org.x)


func _ready() -> void:
	if Util.editor_hint():
		return

	# load build profile from project settings (fallback keeps old behaviour)
	build_profile = ProjectSettings.get_setting("application/build_profile", "fast-iteration")
	if io_debug_logging:
		Util.debug_print("[GameManager] build_profile=" + build_profile)

	_load_runtime_state()
	set_process(true)
	_reset_objective_state()
	# initialize PS1 manager (previously _setup_ps1_shader)
	ps1_mgr._setup_ps1_shader()
	# set up io manager
	add_child(io_mgr)
	io_mgr.io_debug_logging = io_debug_logging
	io_mgr.io_trace_capacity = io_trace_capacity
	io_mgr.connect("io_event_dispatched", Callable(self, "_on_io_event_dispatched"))
	var tree := get_tree()
	var on_added := Callable(self, "_on_tree_node_added")
	if tree != null and not tree.is_connected("node_added", on_added):
		tree.connect("node_added", on_added)
	if tree != null:
		tree.root.child_entered_tree.connect(_on_root_child_entered_tree)
	call_deferred("_handle_scene_change")
	call_deferred("_optimize_worldspawn_collisions")
	call_deferred("_try_register_existing_player")

func _process(delta: float) -> void:
	if Util.editor_hint():
		return
	_zone_lighting_elapsed += delta
	if _zone_lighting_elapsed < ZONE_LIGHTING_UPDATE_INTERVAL:
		return
	_zone_lighting_elapsed = 0.0
	_update_zone_lighting_overrides()

# ---------------------------------------------------------------
# spawn blocker helpers
# ---------------------------------------------------------------

# checks every SpawnBlockerVolume in the scene; returns true if the
# provided position falls inside any of them.
func is_spawn_blocked(point: Vector3) -> bool:
	if Util.editor_hint():
		return false
	for vol in get_tree().get_nodes_in_group("spawn_blocker"):
		if vol and vol.has_method("blocks_point") and vol.blocks_point(point):
			return true
	return false


func _on_root_child_entered_tree(_node: Node) -> void:
	# When the scene root changes, update HUD visibility.
	call_deferred("_handle_scene_change")

func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return
	if node.is_in_group("PLAYER"):
		call_deferred("_try_register_existing_player")

func _on_io_event_dispatched(event: Dictionary) -> void:
	emit_signal("io_event_dispatched", event)

func alert_ai(position: Vector3, source: Node = null) -> void:
	emit_signal("ai_alerted", position, source)

func get_ai_nav_regions(nav_tag: String = "") -> Array[Node3D]:
	var key := nav_tag.strip_edges().to_lower()
	var nodes: Array = []
	if key.is_empty():
		nodes = get_tree().get_nodes_in_group("ai_nav_region")
	else:
		nodes = get_tree().get_nodes_in_group("ai_nav_tag_%s" % key)
	var out: Array[Node3D] = []
	for n in nodes:
		if n is Node3D and Util.to_bool(_get_node_prop(n, "enabled", true), true):
			out.append(n as Node3D)
	return out

func get_ai_patrol_points(route_id: String = "default") -> Array[Node3D]:
	var key := route_id.strip_edges().to_lower()
	if key.is_empty():
		key = "default"
	var nodes := get_tree().get_nodes_in_group("ai_patrol_route_%s" % key)
	# Fallback: some point entities may miss dynamic route groups at runtime.
	# Scan all ai_patrol_point nodes and filter by route_id from node/meta properties.
	if nodes.is_empty():
		var fallback_nodes := get_tree().get_nodes_in_group("ai_patrol_point")
		for n in fallback_nodes:
			var route_val := String(_get_node_prop(n, "route_id", "default")).strip_edges().to_lower()
			if route_val.is_empty():
				route_val = "default"
			if route_val == key:
				nodes.append(n)
	var out: Array[Node3D] = []
	for n in nodes:
		if n is Node3D and Util.to_bool(_get_node_prop(n, "enabled", true), true):
			out.append(n as Node3D)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return int(_get_node_prop(a, "order", 0)) < int(_get_node_prop(b, "order", 0))
	)
	return out

func get_ai_cover_markers(team: String = "") -> Array[Node3D]:
	var key := team.strip_edges().to_lower()
	var nodes: Array = []
	if key.is_empty():
		nodes = get_tree().get_nodes_in_group("ai_cover_marker")
	else:
		nodes = get_tree().get_nodes_in_group("ai_cover_team_%s" % key)
	var out: Array[Node3D] = []
	for n in nodes:
		if n is Node3D and Util.to_bool(_get_node_prop(n, "enabled", true), true):
			out.append(n as Node3D)
	return out

func is_ai_perception_blocked(start_pos: Vector3, end_pos: Vector3) -> bool:
	for n in get_tree().get_nodes_in_group("ai_perception_blocker"):
		if n == null or not is_instance_valid(n):
			continue
		if n.has_method("blocks_line") and bool(n.call("blocks_line", start_pos, end_pos)):
			return true
	return false

func get_ai_spawn_wave_points(wave_id: String = "default", squad_id: String = "") -> Array[Node3D]:
	var wave_key := wave_id.strip_edges().to_lower()
	if wave_key.is_empty():
		wave_key = "default"
	var nodes: Array = get_tree().get_nodes_in_group("ai_spawn_wave_%s" % wave_key)
	var squad_key := squad_id.strip_edges().to_lower()
	var out: Array[Node3D] = []
	for n in nodes:
		if not (n is Node3D):
			continue
		if not Util.to_bool(_get_node_prop(n, "enabled", true), true):
			continue
		if not squad_key.is_empty():
			var node_squad := String(_get_node_prop(n, "squad_id", "")).strip_edges().to_lower()
			if node_squad != squad_key:
				continue
		out.append(n as Node3D)
	return out


func get_perf_budget_markers(tag: String = "") -> Array[Node3D]:
	var key := tag.strip_edges().to_lower()
	var nodes: Array = []
	if key.is_empty():
		nodes = get_tree().get_nodes_in_group("perf_budget_marker")
	else:
		nodes = get_tree().get_nodes_in_group("perf_tag_%s" % key)
	var out: Array[Node3D] = []
	for n in nodes:
		if n is Node3D and Util.to_bool(_get_node_prop(n, "enabled", true), true):
			if n.is_in_group("perf_budget_marker"):
				out.append(n as Node3D)
	return out


func get_perf_heatmap_volumes(tag: String = "") -> Array[Node3D]:
	var key := tag.strip_edges().to_lower()
	var nodes: Array = []
	if key.is_empty():
		nodes = get_tree().get_nodes_in_group("perf_heatmap_volume")
	else:
		nodes = get_tree().get_nodes_in_group("perf_tag_%s" % key)
	var out: Array[Node3D] = []
	for n in nodes:
		if n is Node3D and Util.to_bool(_get_node_prop(n, "enabled", true), true):
			if n.is_in_group("perf_heatmap_volume"):
				out.append(n as Node3D)
	return out


func get_perf_budget_at_point(point: Vector3, tag: String = "") -> Dictionary:
	var score: float = 0.0
	var marker_hits: int = 0
	var volume_hits: int = 0
	var min_budget_limit: float = -1.0

	for marker in get_perf_budget_markers(tag):
		var m_cost: float = 0.0
		if marker.has_method("estimate_cost_at_point"):
			m_cost = maxf(float(marker.call("estimate_cost_at_point", point)), 0.0)
		else:
			var radius: float = maxf(float(_get_node_prop(marker, "radius", 0.0)), 0.0)
			var base_cost: float = maxf(float(_get_node_prop(marker, "cost", 0.0)), 0.0)
			if radius > 0.0:
				var d: float = marker.global_position.distance_to(point)
				if d < radius:
					m_cost = base_cost * (1.0 - d / radius)
		if m_cost > 0.0:
			score += m_cost
			marker_hits += 1
		var marker_limit: float = float(_get_node_prop(marker, "budget_limit", -1.0))
		if marker_limit > 0.0 and (min_budget_limit < 0.0 or marker_limit < min_budget_limit):
			min_budget_limit = marker_limit

	for volume in get_perf_heatmap_volumes(tag):
		var v_cost: float = 0.0
		if volume.has_method("estimate_cost_at_point"):
			v_cost = maxf(float(volume.call("estimate_cost_at_point", point)), 0.0)
		else:
			var ext: Vector3 = _get_node_prop(volume, "extents", Vector3.ZERO)
			if ext != Vector3.ZERO:
				var lp: Vector3 = volume.global_transform.affine_inverse() * point
				if absf(lp.x) <= ext.x and absf(lp.y) <= ext.y and absf(lp.z) <= ext.z:
					v_cost = maxf(float(_get_node_prop(volume, "cost", 0.0)), 0.0)
		if v_cost > 0.0:
			score += v_cost
			volume_hits += 1
			var volume_limit: float = float(_get_node_prop(volume, "budget_limit", -1.0))
			if volume_limit > 0.0 and (min_budget_limit < 0.0 or volume_limit < min_budget_limit):
				min_budget_limit = volume_limit

	var warning_threshold: float = perf_budget_warning_score
	var critical_threshold: float = perf_budget_critical_score
	var status: String = "ok"
	if min_budget_limit > 0.0:
		if score >= min_budget_limit:
			status = "critical"
		elif score >= min_budget_limit * 0.8:
			status = "warn"
	else:
		if score >= critical_threshold:
			status = "critical"
		elif score >= warning_threshold:
			status = "warn"

	return {
		"score": score,
		"status": status,
		"marker_hits": marker_hits,
		"volume_hits": volume_hits,
		"warning_threshold": warning_threshold,
		"critical_threshold": critical_threshold,
		"budget_limit": min_budget_limit
	}


func _handle_scene_change() -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	_last_worldspawn_id = -1
	_zone_last_hash = 0
	_zone_light_base_masks.clear()
	_zone_probe_base_masks.clear()
	_zone_probe_base_intensity.clear()
	var in_ui := current is Control
	if in_ui:
		if _hud != null:
			_hud.visible = false
		return
	if current.is_in_group(NO_HUD_GROUP):
		if _hud != null:
			_hud.visible = false
		return

	_spawn_hud_if_missing()
	if _hud != null:
		_hud.visible = true
	if ps1_mgr.is_ps1_shader_enabled():
		ps1_mgr._ensure_ps1_tracking_for_scene(current)
		ps1_mgr.apply_scene(current)
	call_deferred("_apply_worldspawn_globals_from_scene")


func _try_register_existing_player() -> void:
	var players := get_tree().get_nodes_in_group("PLAYER")
	if players.size() > 0:
		register_player(players[0])


func register_player(player: Node) -> void:
	if player == null:
		return
	var cb := Callable(self, "_on_player_health_changed")
	if _player != null and is_instance_valid(_player) and _player.is_connected("health_changed", cb):
		_player.disconnect("health_changed", cb)
	_player = player
	if _player.has_signal("health_changed"):
		_player.connect("health_changed", cb)
	# Prime health state.
	_update_health_cache_from_player()
	_emit_player_health_changed()


func add_health(amount: int, allow_overheal: bool = false, overheal_cap: int = 0) -> void:
	if _player == null or not is_instance_valid(_player):
		_try_register_existing_player()
	if _player != null and is_instance_valid(_player) and _player.has_method("add_health"):
		_player.call("add_health", amount, allow_overheal, overheal_cap)
		_update_health_cache_from_player()
		_emit_player_health_changed()


func apply_damage(amount: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_try_register_existing_player()
	if _player != null and is_instance_valid(_player) and _player.has_method("apply_damage"):
		_player.call("apply_damage", amount)
		_update_health_cache_from_player()
		_emit_player_health_changed()


func _on_player_health_changed(current: int, max_h: int, max_over: int) -> void:
	player_health = current
	player_max_health = max_h
	player_max_overhealth = max_over
	emit_signal("player_health_changed", player_health, player_max_health, player_max_overhealth)


func _update_health_cache_from_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_method("get"):
		var h = _player.get("health")
		var mh = _player.get("max_health")
		var mo = _player.get("max_overhealth")
		if typeof(h) in [TYPE_INT, TYPE_FLOAT]:
			player_health = int(h)
		if typeof(mh) in [TYPE_INT, TYPE_FLOAT]:
			player_max_health = int(mh)
		if typeof(mo) in [TYPE_INT, TYPE_FLOAT]:
			player_max_overhealth = int(mo)


func _emit_player_health_changed() -> void:
	emit_signal("player_health_changed", player_health, player_max_health, player_max_overhealth)


func handle_player_death(player: Node, delay: float = 1.0) -> void:
	emit_signal("player_died")
	_set_objective_text("You died")
	await get_tree().create_timer(maxf(0.0, delay)).timeout
	respawn_player(player)


func respawn_player(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	if _try_respawn_at_checkpoint(player):
		return
	# Find an active info_player_start in the current scene.
	var current := get_tree().current_scene
	if current == null:
		return
	var starts := current.find_children("*", "Marker3D", true, false)
	for s in starts:
		if _is_script_instance(s, INFO_PLAYER_START_SCRIPT) and Util.to_bool(s.get("active"), false):
			if player is Node3D:
				(player as Node3D).global_position = s.global_position
				(player as Node3D).rotation_degrees = s.get("angles")
			# Restore health if supported.
			if player.has_method("reset_health"):
				player.call("reset_health")
			register_player(player)
			_set_objective_text(_default_objective_text())
			return


func register_checkpoint(checkpoint_id: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var key := checkpoint_id.strip_edges()
	if key.is_empty():
		return
	_runtime_checkpoints[key] = {
		"position": [pos.x, pos.y, pos.z],
		"rotation_degrees": [rot_deg.x, rot_deg.y, rot_deg.z]
	}
	_runtime_active_checkpoint_id = key
	_save_runtime_state()


func set_active_checkpoint(checkpoint_id: String) -> void:
	var key := checkpoint_id.strip_edges()
	if key.is_empty():
		return
	if not _runtime_checkpoints.has(key):
		return
	_runtime_active_checkpoint_id = key
	_save_runtime_state()


func get_active_checkpoint() -> String:
	return _runtime_active_checkpoint_id


func state_get_enabled(save_id: String, default_enabled: bool = true) -> bool:
	var key := save_id.strip_edges()
	if key.is_empty():
		return default_enabled
	if _runtime_entity_enabled.has(key):
		return Util.to_bool(_runtime_entity_enabled[key], default_enabled)
	return default_enabled


func state_set_enabled(save_id: String, enabled: bool) -> void:
	var key := save_id.strip_edges()
	if key.is_empty():
		return
	_runtime_entity_enabled[key] = enabled
	_save_runtime_state()


func state_has_fired(save_id: String) -> bool:
	var key := save_id.strip_edges()
	if key.is_empty():
		return false
	if not _runtime_fired_once.has(key):
		return false
	return Util.to_bool(_runtime_fired_once[key], false)


func state_mark_fired(save_id: String) -> void:
	var key := save_id.strip_edges()
	if key.is_empty():
		return
	_runtime_fired_once[key] = true
	_save_runtime_state()


func _try_respawn_at_checkpoint(player: Node) -> bool:
	if _runtime_active_checkpoint_id.is_empty():
		return false
	if not _runtime_checkpoints.has(_runtime_active_checkpoint_id):
		return false
	var cp_var: Variant = _runtime_checkpoints[_runtime_active_checkpoint_id]
	if not (cp_var is Dictionary):
		return false
	var cp := cp_var as Dictionary
	var pos := _vec3_from_data(cp.get("position", []), Vector3.ZERO)
	var rot := _vec3_from_data(cp.get("rotation_degrees", []), Vector3.ZERO)
	if player is Node3D:
		(player as Node3D).global_position = pos
		(player as Node3D).global_rotation_degrees = rot
	if player.has_method("reset_health"):
		player.call("reset_health")
	register_player(player)
	_set_objective_text(_default_objective_text())
	return true


func _vec3_from_data(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array:
		var arr := value as Array
		if arr.size() >= 3:
			return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return fallback


func _save_runtime_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("entity", "enabled", _runtime_entity_enabled)
	cfg.set_value("entity", "fired_once", _runtime_fired_once)
	cfg.set_value("checkpoint", "data", _runtime_checkpoints)
	cfg.set_value("checkpoint", "active_id", _runtime_active_checkpoint_id)
	_save_config_atomic(cfg, RUNTIME_STATE_PATH, RUNTIME_STATE_BACKUP_PATH, "runtime_state")


func _save_config_atomic(cfg: ConfigFile, target_path: String, backup_path: String, label: String) -> bool:
	var tmp_path := target_path + ".tmp"
	var tmp_save_err := cfg.save(tmp_path)
	if tmp_save_err != OK:
		push_warning("GAME %s save failed (tmp): %s" % [label, str(tmp_save_err)])
		return false

	var abs_target := ProjectSettings.globalize_path(target_path)
	var abs_backup := ProjectSettings.globalize_path(backup_path)
	var abs_tmp := ProjectSettings.globalize_path(tmp_path)

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(abs_backup)
	if FileAccess.file_exists(target_path):
		var backup_err := DirAccess.rename_absolute(abs_target, abs_backup)
		if backup_err != OK:
			push_warning("GAME %s save failed (backup rotate): %s" % [label, str(backup_err)])
			DirAccess.remove_absolute(abs_tmp)
			return false

	var promote_err := DirAccess.rename_absolute(abs_tmp, abs_target)
	if promote_err != OK:
		push_warning("GAME %s save failed (promote tmp): %s" % [label, str(promote_err)])
		# Attempt rollback if we already moved the previous file to backup.
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(target_path):
			DirAccess.rename_absolute(abs_backup, abs_target)
		return false

	return true


func _load_runtime_state() -> void:
	_runtime_entity_enabled.clear()
	_runtime_fired_once.clear()
	_runtime_checkpoints.clear()
	_runtime_active_checkpoint_id = ""
	var cfg := ConfigFile.new()
	var load_err := cfg.load(RUNTIME_STATE_PATH)
	if load_err != OK:
		var backup_err := cfg.load(RUNTIME_STATE_BACKUP_PATH)
		if backup_err != OK:
			return
		push_warning("GAME runtime_state load fallback to backup due to primary read failure: %s" % str(load_err))
	var enabled_var: Variant = cfg.get_value("entity", "enabled", {})
	if enabled_var is Dictionary:
		_runtime_entity_enabled = enabled_var
	var fired_var: Variant = cfg.get_value("entity", "fired_once", {})
	if fired_var is Dictionary:
		_runtime_fired_once = fired_var
	var checkpoints_var: Variant = cfg.get_value("checkpoint", "data", {})
	if checkpoints_var is Dictionary:
		_runtime_checkpoints = checkpoints_var
	_runtime_active_checkpoint_id = String(cfg.get_value("checkpoint", "active_id", ""))


func _reset_objective_state() -> void:
	collected_collectibles = 0
	_keys.clear()
	_exit_unlocked_emitted = false
	_has_won = false
	emit_signal("collectible_count_changed", collected_collectibles, required_collectibles)
	emit_signal("keys_changed", get_keys())
	_set_objective_text(_default_objective_text())


func _default_objective_text() -> String:
	if required_collectibles <= 0:
		return "Explore"
	return "Collect %d sacred fruit" % required_collectibles


func _set_objective_text(text: String) -> void:
	emit_signal("objective_text_changed", text)


func add_collectibles_required(delta_required: int) -> void:
	required_collectibles = max(0, required_collectibles + delta_required)
	emit_signal("collectible_count_changed", collected_collectibles, required_collectibles)
	if can_exit():
		_emit_exit_unlocked_once()


func collect(value: int = 1) -> void:
	collected_collectibles = maxi(0, collected_collectibles + value)
	emit_signal("collectible_count_changed", collected_collectibles, required_collectibles)
	if can_exit():
		_emit_exit_unlocked_once()
		_set_objective_text("Exit unlocked")
	else:
		var remaining := required_collectibles - collected_collectibles
		_set_objective_text("Collect %d more" % remaining)


func has_key(key_id: String) -> bool:
	var id := key_id.strip_edges().to_lower()
	if id.is_empty():
		return true
	return _keys.has(id)


func give_key(key_id: String) -> bool:
	var id := key_id.strip_edges().to_lower()
	if id.is_empty():
		return false
	if _keys.has(id):
		return false
	_keys[id] = true
	emit_signal("keys_changed", get_keys())
	return true


func consume_key(key_id: String) -> bool:
	var id := key_id.strip_edges().to_lower()
	if id.is_empty():
		return false
	if not _keys.has(id):
		return false
	_keys.erase(id)
	emit_signal("keys_changed", get_keys())
	return true


func get_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _keys.keys():
		out.append(String(id))
	out.sort()
	return out


func can_exit() -> bool:
	return required_collectibles <= 0 or collected_collectibles >= required_collectibles


func try_exit() -> bool:
	if _has_won:
		return true
	if not can_exit():
		var remaining := required_collectibles - collected_collectibles
		_set_objective_text("Need %d more" % remaining)
		return false
	win()
	return true


func win() -> void:
	if _has_won:
		return
	_has_won = true
	# Placeholder win state: print + unlock objective text. You can swap this to a
	# scene change or end screen later.
	print("WIN: Collected ", collected_collectibles, "/", required_collectibles)
	_set_objective_text("You win")


func _emit_exit_unlocked_once() -> void:
	if _exit_unlocked_emitted:
		return
	_exit_unlocked_emitted = true
	emit_signal("exit_unlocked")


func _spawn_hud_if_missing() -> void:
	if _hud != null:
		return
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	if hud_scene == null:
		return
	_hud = hud_scene.instantiate() as CanvasLayer
	if _hud != null:
		get_tree().root.add_child(_hud)

func _update_zone_lighting_overrides() -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var zone := _get_strongest_env_zone(current, cam.global_position)
	var zone_hash := _compute_zone_hash(zone)
	if zone_hash == _zone_last_hash:
		return
	_zone_last_hash = zone_hash
	_apply_zone_lighting(current, zone)

func _get_strongest_env_zone(root: Node, camera_pos: Vector3) -> Node3D:
	var zones: Array = root.find_children("*", "Node3D", true, false)
	var best: Node3D = null
	var best_weight := 0.0
	for z in zones:
		if not _is_script_instance(z, ENV_ZONE_SCRIPT):
			continue
		var zone := z as Node3D
		if zone == null:
			continue
		if not Util.to_bool(zone.get("enabled"), true):
			continue
		var zone_radius := maxf(float(zone.get("radius")) * INVERSE_SCALE, 0.01)
		var dist := camera_pos.distance_to(zone.global_position)
		if dist > zone_radius:
			continue
		var weight := 1.0 - clampf(dist / zone_radius, 0.0, 1.0)
		if weight > best_weight:
			best_weight = weight
			best = zone
	return best

func _compute_zone_hash(zone: Node3D) -> int:
	if zone == null:
		return 0
	return hash([
		zone.get_instance_id(),
		int(zone.get("light_cull_mask")),
		int(zone.get("reflection_cull_mask")),
		float(zone.get("reflection_intensity_scale"))
	])

func _apply_zone_lighting(root: Node, zone: Node3D) -> void:
	var lights: Array = root.find_children("*", "Light3D", true, false)
	for light_node in lights:
		if not (light_node is Light3D):
			continue
		var light := light_node as Light3D
		var lid := light.get_instance_id()
		if not _zone_light_base_masks.has(lid):
			_zone_light_base_masks[lid] = light.light_cull_mask
		var zone_light_mask: int = -1
		if zone != null:
			zone_light_mask = int(zone.get("light_cull_mask"))
		if zone_light_mask >= 0:
			light.light_cull_mask = zone_light_mask
		else:
			light.light_cull_mask = int(_zone_light_base_masks[lid])

	var probes: Array = root.find_children("*", "ReflectionProbe", true, false)
	for probe_node in probes:
		if not (probe_node is ReflectionProbe):
			continue
		var probe := probe_node as ReflectionProbe
		var pid := probe.get_instance_id()
		if not _zone_probe_base_masks.has(pid):
			_zone_probe_base_masks[pid] = probe.cull_mask
		if not _zone_probe_base_intensity.has(pid):
			_zone_probe_base_intensity[pid] = probe.intensity
		var zone_probe_mask: int = -1
		var zone_probe_intensity_scale: float = -1.0
		if zone != null:
			zone_probe_mask = int(zone.get("reflection_cull_mask"))
			zone_probe_intensity_scale = float(zone.get("reflection_intensity_scale"))
		if zone_probe_mask >= 0:
			probe.cull_mask = zone_probe_mask
		else:
			probe.cull_mask = int(_zone_probe_base_masks[pid])
		if zone_probe_intensity_scale >= 0.0:
			probe.intensity = float(_zone_probe_base_intensity[pid]) * zone_probe_intensity_scale
		else:
			probe.intensity = float(_zone_probe_base_intensity[pid])


func apply_worldspawn_globals(props: Dictionary, worldspawn: Node = null) -> void:
	if props == null:
		return

	if _worldspawn_has_source_prop(worldspawn, "sf_required_collectibles"):
		var required := int(props.get("sf_required_collectibles", -1))
		if required >= 0:
			required_collectibles = required
			emit_signal("collectible_count_changed", collected_collectibles, required_collectibles)
			_set_objective_text(_default_objective_text())

	if _worldspawn_has_source_prop(worldspawn, "sf_objective_text"):
		var objective := String(props.get("sf_objective_text", "")).strip_edges()
		if not objective.is_empty():
			_set_objective_text(objective)

	if _worldspawn_has_source_prop(worldspawn, "sf_ps1_shader"):
		ps1_mgr.set_ps1_shader_enabled(Util.to_bool(props.get("sf_ps1_shader", ps1_mgr.enable_ps1_geometry_shader), ps1_mgr.enable_ps1_geometry_shader))

	if _worldspawn_has_source_prop(worldspawn, "sf_ps1_dither_strength"):
		var dither_strength := float(props.get("sf_ps1_dither_strength", -1.0))
		if dither_strength >= 0.0:
			ps1_mgr.dither_strength = dither_strength
			ps1_mgr._sync_all_ps1_material_params()

	var current := get_tree().current_scene
	if current == null:
		return

	if _worldspawn_has_source_prop(worldspawn, "sf_sun_energy"):
		var sun_energy := float(props.get("sf_sun_energy", -1.0))
		if sun_energy >= 0.0:
			var suns := current.find_children("*", "DirectionalLight3D", true, false)
			if suns.size() > 0 and suns[0] is DirectionalLight3D:
				(suns[0] as DirectionalLight3D).light_energy = sun_energy

	var world_env_nodes := current.find_children("*", "WorldEnvironment", true, false)
	if world_env_nodes.is_empty():
		return
	var world_env := world_env_nodes[0] as WorldEnvironment
	if world_env == null or world_env.environment == null:
		return
	var env := world_env.environment

	if _worldspawn_has_source_prop(worldspawn, "sf_fog_enabled"):
		var fog_enabled := Util.to_bool(props.get("sf_fog_enabled", false), false)
		if "fog_enabled" in env:
			env.set("fog_enabled", fog_enabled)
		if "volumetric_fog_enabled" in env:
			env.set("volumetric_fog_enabled", fog_enabled)

	if _worldspawn_has_source_prop(worldspawn, "sf_fog_density"):
		var fog_density := float(props.get("sf_fog_density", -1.0))
		if fog_density >= 0.0 and "fog_density" in env:
			env.set("fog_density", fog_density)

	if _worldspawn_has_source_prop(worldspawn, "sf_fog_color"):
		var fog_color_var: Variant = props.get("sf_fog_color", Color(0, 0, 0, 1))
		var fog_color := Color(0, 0, 0, 1)
		if fog_color_var is Color:
			fog_color = fog_color_var as Color
		elif fog_color_var is String:
			fog_color = Color.from_string(String(fog_color_var), fog_color)
		if "fog_light_color" in env:
			env.set("fog_light_color", fog_color)
		if "volumetric_fog_albedo" in env:
			env.set("volumetric_fog_albedo", fog_color)


func _apply_worldspawn_globals_from_scene() -> void:
	if Util.editor_hint():
		return
	var root := get_tree().current_scene
	if root == null:
		return

	var candidates: Array[Node] = root.find_children("*worldspawn*", "StaticBody3D", true, false)
	for n in candidates:
		var ws := n as StaticBody3D
		if ws == null:
			continue
		var ws_id := ws.get_instance_id()
		if ws_id == _last_worldspawn_id:
			return
		_last_worldspawn_id = ws_id

		if not ws.has_meta("func_godot_properties"):
			continue
		var props_var: Variant = ws.get_meta("func_godot_properties")
		if not (props_var is Dictionary):
			continue
		apply_worldspawn_globals(props_var as Dictionary, ws)
		return


func _optimize_worldspawn_collisions() -> void:
	if Util.editor_hint():
		return
	var root := get_tree().current_scene
	if root == null:
		return

	var candidates: Array[Node] = root.find_children("*worldspawn*", "StaticBody3D", true, false)
	for n in candidates:
		var ws := n as StaticBody3D
		if ws == null:
			continue
		_optimize_single_worldspawn(ws)


func _optimize_single_worldspawn(worldspawn: StaticBody3D) -> void:
	# Find a mesh to build collision from.
	var mi := worldspawn.find_child("*mesh_instance*", true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return

	# If we don't have a lot of brush colliders, leave it alone.
	var shapes: Array[Node] = worldspawn.find_children("*collision_shape*", "CollisionShape3D", true, false)
	if shapes.size() < WORLDSPAWN_COLLIDER_THRESHOLD:
		return

	var trimesh: Shape3D = mi.mesh.create_trimesh_shape()
	if trimesh == null:
		return

	# Remove existing brush shapes.
	for s in shapes:
		(s as Node).queue_free()

	var cs := CollisionShape3D.new()
	cs.name = "worldspawn_trimesh_collision"
	cs.shape = trimesh
	worldspawn.add_child(cs)

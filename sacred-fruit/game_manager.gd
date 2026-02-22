class_name GameManager
extends Node
const Util := preload("res://scripts/util.gd")

# Common inverse scale. Calculated as 1.0 / Inverse Scale Factor. 
# Used to help translate properties using Quake Units into Godot Units.
const INVERSE_SCALE: float = 0.03125

signal objective_text_changed(text: String)
signal collectible_count_changed(collected: int, required: int)
signal exit_unlocked()
signal player_health_changed(current: int, max_health: int, max_overhealth: int)
signal player_died()
signal io_event_dispatched(event: Dictionary)

enum {
	WORLD_LAYER = (1 << 0),
	ACTOR_LAYER = (1 << 1),
	TRIGGER_LAYER = (1 << 2)
}

@export var required_collectibles: int = 3

# PS1 shader configuration has been refactored into a dedicated manager.
const PS1ShaderManager := preload("res://scripts/ps1_shader_manager.gd")
var ps1_mgr: PS1ShaderManager = PS1ShaderManager.new()

@export var io_debug_logging: bool = false
@export_range(16, 1024, 1) var io_trace_capacity: int = 256

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




# --- IO manager facade methods ------------------------------------------------

const IOManager := preload("res://scripts/io_manager.gd")
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

	_reset_objective_state()

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
	# initialize PS1 manager (previously _setup_ps1_shader)
	ps1_mgr._setup_ps1_shader()
	# set up io manager
	add_child(io_mgr)
	io_mgr.io_debug_logging = io_debug_logging
	io_mgr.io_trace_capacity = io_trace_capacity
	# use Callable constructor to satisfy strict connect signature
	io_mgr.connect("io_event_dispatched", Callable(self, "_on_io_event_dispatched"))
	var tree := get_tree()
	var on_added := Callable(self, "_on_tree_node_added")
	if tree != null and not tree.is_connected("node_added", on_added):
		tree.connect("node_added", on_added)
	# Spawn HUD only in gameplay scenes (not in menus). It will be shown/hidden
	# automatically when scenes change.
	tree.root.child_entered_tree.connect(_on_root_child_entered_tree)
	call_deferred("_handle_scene_change")
	# For huge baked func_godot scenes (like HOME.tscn), this can reduce node count
	# and speed up physics broadphase by replacing thousands of brush colliders with
	# a single trimesh collider derived from the visual mesh.
	call_deferred("_optimize_worldspawn_collisions")
	# In case player registers before GAME is ready, try to find one.
	call_deferred("_try_register_existing_player")


func _on_root_child_entered_tree(_node: Node) -> void:
	# When the scene root changes, update HUD visibility.
	call_deferred("_handle_scene_change")


func _handle_scene_change() -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	_last_worldspawn_id = -1
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
	# Find an active info_player_start in the current scene.
	var current := get_tree().current_scene
	if current == null:
		return
	var starts := current.find_children("*", "Marker3D", true, false)
	for s in starts:
		if s is InfoPlayerStart and (s as InfoPlayerStart).active:
			var start := s as InfoPlayerStart
			if player is Node3D:
				(player as Node3D).global_position = start.global_position
				(player as Node3D).rotation_degrees = start.angles
			# Restore health if supported.
			if player.has_method("reset_health"):
				player.call("reset_health")
			register_player(player)
			_set_objective_text(_default_objective_text())
			return


func _reset_objective_state() -> void:
	collected_collectibles = 0
	_exit_unlocked_emitted = false
	_has_won = false
	emit_signal("collectible_count_changed", collected_collectibles, required_collectibles)
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

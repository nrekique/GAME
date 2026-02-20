class_name GameManager
extends Node

# Common inverse scale. Calculated as 1.0 / Inverse Scale Factor. 
# Used to help translate properties using Quake Units into Godot Units.
const INVERSE_SCALE: float = 0.03125

signal objective_text_changed(text: String)
signal collectible_count_changed(collected: int, required: int)
signal exit_unlocked()
signal player_health_changed(current: int, max_health: int, max_overhealth: int)
signal player_died()

enum {
	WORLD_LAYER = (1 << 0),
	ACTOR_LAYER = (1 << 1),
	TRIGGER_LAYER = (1 << 2)
}

@export var required_collectibles: int = 3
@export var enable_ps1_geometry_shader: bool = true
@export_range(32.0, 1024.0, 1.0) var ps1_vertex_snap: float = 320.0
@export_range(2.0, 64.0, 1.0) var ps1_color_steps: float = 32.0
@export_range(0.0, 1.0, 0.01) var ps1_posterize_strength: float = 0.35
@export_range(0.0, 1.0, 0.01) var ps1_affine_warp: float = 0.08
@export_range(0.0, 0.02, 0.0001) var ps1_uv_jitter: float = 0.0006
@export var ps1_jitter_depth_independent: bool = true
@export var ps1_jitter_z_coordinate: bool = false
@export var ps1_affine_texture_mapping: bool = false
@export_range(0.0, 1.0, 0.01) var ps1_affine_mapping_strength: float = 0.0
@export_range(0.0, 1.0, 0.01) var ps1_alpha_scissor_threshold: float = 0.0
@export var ps1_dithering_enabled: bool = true
@export_range(0.0, 2.0, 0.01) var ps1_dither_strength: float = 1.2
@export_range(1, 8, 1) var ps1_dither_resolution_scale: int = 2
@export var ps1_light_dither_enabled: bool = true
@export var ps1_light_dither_texture: Texture2D
@export_range(0.1, 16.0, 0.1) var ps1_light_dither_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var ps1_light_dither_strength: float = 0.2
@export_range(1.0, 16.0, 1.0) var ps1_light_dither_levels: float = 5.0

var collected_collectibles: int = 0
var _hud: CanvasLayer = null
var _exit_unlocked_emitted: bool = false
var _has_won: bool = false

var _player: Node = null
var player_health: int = 0
var player_max_health: int = 0
var player_max_overhealth: int = 0
const NO_HUD_GROUP := "NO_HUD"
const PS1_SHADER_PATH := "res://shaders/ps1_geometry.gdshader"

var _ps1_shader: Shader = null
var _ps1_material_cache: Dictionary = {}
var _ps1_cached_materials: Array[ShaderMaterial] = []
var _ps1_mesh_ids: Dictionary = {}
var _ps1_original_materials: Dictionary = {}
var _ps1_scene_id: int = -1
var _ps1_default_dither_texture: Texture2D = null
var _last_worldspawn_id: int = -1


static func _to_bool(value: Variant, default_value: bool = false) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING:
			var s := String(value).strip_edges().to_lower()
			if s in ["1", "true", "yes", "on", "y"]:
				return true
			if s in ["0", "false", "no", "off", "n", ""]:
				return false
			return default_value
		_:
			return default_value


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


func _is_master_unlocked(master_node: Node) -> bool:
	if master_node == null:
		return false
	if master_node.has_method("is_unlocked"):
		return _to_bool(master_node.call("is_unlocked"), false)
	for method_name in ["is_active", "is_enabled", "is_open", "is_on"]:
		if master_node.has_method(method_name):
			return _to_bool(master_node.call(method_name), false)
	for property_name in ["unlocked", "active", "enabled", "open", "on", "button_pressed"]:
		var value: Variant = _get_node_prop(master_node, property_name, null)
		if value != null:
			return _to_bool(value, false)
	# If no explicit lock state exists, treat this master as unlocked.
	return true


func _master_allows(activator: Node) -> bool:
	var master_name := String(_get_node_prop(activator, "master", "")).strip_edges()
	if master_name.is_empty():
		return true
	var masters := get_tree().get_nodes_in_group(master_name)
	if masters.is_empty():
		return false
	for m in masters:
		if m is Node and _is_master_unlocked(m as Node):
			return true
	return false


func _apply_killtarget(activator: Node) -> void:
	var killtarget_raw := String(_get_node_prop(activator, "killtarget", ""))
	if killtarget_raw.is_empty():
		return
	var killed := {}
	for chunk in killtarget_raw.split(","):
		var group_name := String(chunk).strip_edges()
		if group_name.is_empty():
			continue
		for target_node in get_tree().get_nodes_in_group(group_name):
			var node := target_node as Node
			if node == null:
				continue
			var node_id := node.get_instance_id()
			if killed.has(node_id):
				continue
			killed[node_id] = true
			node.queue_free()

func use_targets(activator: Node, target: String) -> void:
	if activator != null and not _master_allows(activator):
		return
	var f := String(_get_node_prop(activator, "targetfunc", "")).strip_edges()
	if f.is_empty():
		f = "use"
	var seen_groups := {}
	for chunk in target.split(","):
		var group_name := String(chunk).strip_edges()
		if group_name.is_empty() or seen_groups.has(group_name):
			continue
		seen_groups[group_name] = true
		# Targetnames are really Godot Groups, so we can have multiple entities
		# share a common "targetname" in Trenchbroom.
		var target_list: Array[Node] = get_tree().get_nodes_in_group(group_name)
		for targ in target_list:
			if targ != null and targ.has_method(f):
				targ.call(f)
	if activator != null:
		_apply_killtarget(activator)

func set_targetname(node: Node, targetname: String) -> void:
	if node == null:
		return
	if targetname.is_empty():
		return
	# Allow comma-delimited targetnames (Quake convention).
	for t in targetname.split(","):
		var name := String(t).strip_edges()
		if not name.is_empty():
			node.add_to_group(name)

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
	if Engine.is_editor_hint():
		return

	_reset_objective_state()
	_setup_ps1_shader()
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
	if enable_ps1_geometry_shader:
		_ensure_ps1_tracking_for_scene(current)
		call_deferred("_apply_ps1_to_scene", current)
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
		set_ps1_shader_enabled(_to_bool(props.get("sf_ps1_shader", enable_ps1_geometry_shader), enable_ps1_geometry_shader))

	if _worldspawn_has_source_prop(worldspawn, "sf_ps1_dither_strength"):
		var dither_strength := float(props.get("sf_ps1_dither_strength", -1.0))
		if dither_strength >= 0.0:
			ps1_dither_strength = dither_strength
			_sync_all_ps1_material_params()

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
		var fog_enabled := _to_bool(props.get("sf_fog_enabled", false), false)
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
	if Engine.is_editor_hint():
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
	if Engine.is_editor_hint():
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
	if shapes.size() < 250:
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


func _setup_ps1_shader() -> void:
	_ps1_material_cache.clear()
	_ps1_cached_materials.clear()
	_ps1_mesh_ids.clear()
	_sync_ps1_global_shader_params()
	if not enable_ps1_geometry_shader:
		_ps1_shader = null
		return
	_ps1_shader = load(PS1_SHADER_PATH) as Shader
	if _ps1_shader == null:
		push_warning("PS1 shader missing at %s" % PS1_SHADER_PATH)
		return


func is_ps1_shader_enabled() -> bool:
	return enable_ps1_geometry_shader


func set_ps1_shader_enabled(enabled: bool) -> void:
	if enable_ps1_geometry_shader == enabled:
		_sync_ps1_global_shader_params()
		if enabled:
			_sync_all_ps1_material_params()
			var current_scene := get_tree().current_scene
			if current_scene != null:
				_ensure_ps1_tracking_for_scene(current_scene)
				_apply_ps1_to_scene(current_scene)
		return
	enable_ps1_geometry_shader = enabled
	if enabled:
		_setup_ps1_shader()
		var current := get_tree().current_scene
		if current != null:
			_ensure_ps1_tracking_for_scene(current)
			_apply_ps1_to_scene(current)
	else:
		_restore_ps1_materials()
		_ps1_shader = null
		_ps1_material_cache.clear()
		_ps1_cached_materials.clear()
		_ps1_mesh_ids.clear()
		_ps1_scene_id = -1
	_sync_ps1_global_shader_params()


func _sync_all_ps1_material_params() -> void:
	_sync_ps1_global_shader_params()
	for mat in _ps1_cached_materials:
		if mat is ShaderMaterial:
			_sync_ps1_material_params(mat as ShaderMaterial)


func _sync_ps1_global_shader_params() -> void:
	if not _has_ps1_global_shader_globals():
		return
	var dither_texture := ps1_light_dither_texture
	if dither_texture == null:
		dither_texture = _get_default_ps1_light_dither_texture()
	var light_strength := ps1_light_dither_strength
	if not enable_ps1_geometry_shader or not ps1_light_dither_enabled:
		light_strength = 0.0
	RenderingServer.global_shader_parameter_set("dither_texture", dither_texture)
	RenderingServer.global_shader_parameter_set("dither_scale", maxf(ps1_light_dither_scale, 0.001))
	RenderingServer.global_shader_parameter_set("dither_strength", clampf(light_strength, 0.0, 1.0))
	RenderingServer.global_shader_parameter_set("dither_levels", maxf(ps1_light_dither_levels, 1.0))


var _ps1_globals_checked: bool = false
var _ps1_globals_available: bool = false
var _ps1_globals_warned: bool = false


func _has_ps1_global_shader_globals() -> bool:
	if _ps1_globals_checked:
		return _ps1_globals_available
	_ps1_globals_checked = true
	var keys := [
		"rendering/global_shader_parameters/dither_texture",
		"rendering/global_shader_parameters/dither_scale",
		"rendering/global_shader_parameters/dither_strength",
		"rendering/global_shader_parameters/dither_levels"
	]
	for key in keys:
		if not ProjectSettings.has_setting(key):
			_ps1_globals_available = false
			if not _ps1_globals_warned:
				_ps1_globals_warned = true
			return false
	_ps1_globals_available = true
	return true


func _get_default_ps1_light_dither_texture() -> Texture2D:
	if _ps1_default_dither_texture != null:
		return _ps1_default_dither_texture
	var matrix := PackedFloat32Array([
		0.0 / 16.0, 8.0 / 16.0, 2.0 / 16.0, 10.0 / 16.0,
		12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0, 6.0 / 16.0,
		3.0 / 16.0, 11.0 / 16.0, 1.0 / 16.0, 9.0 / 16.0,
		15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0, 5.0 / 16.0
	])
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y in range(4):
		for x in range(4):
			var v := matrix[y * 4 + x]
			image.set_pixel(x, y, Color(v, v, v, 1.0))
	_ps1_default_dither_texture = ImageTexture.create_from_image(image)
	return _ps1_default_dither_texture


func _ensure_ps1_tracking_for_scene(root: Node) -> void:
	if root == null:
		return
	var scene_id := root.get_instance_id()
	if _ps1_scene_id == scene_id:
		return
	_ps1_scene_id = scene_id
	_ps1_mesh_ids.clear()
	_ps1_original_materials.clear()


func _store_ps1_original_materials(mesh: MeshInstance3D) -> void:
	if mesh == null:
		return
	var mesh_id := mesh.get_instance_id()
	if _ps1_original_materials.has(mesh_id):
		return
	var surface_overrides: Array = []
	if mesh.mesh != null:
		var count := mesh.mesh.get_surface_count()
		surface_overrides.resize(count)
		for i in range(count):
			surface_overrides[i] = mesh.get_surface_override_material(i)
	_ps1_original_materials[mesh_id] = {
		"override": mesh.material_override,
		"surface_overrides": surface_overrides
	}


func _restore_ps1_materials() -> void:
	for mesh_key in _ps1_original_materials.keys():
		var mesh_id := int(mesh_key)
		var obj := instance_from_id(mesh_id)
		if not (obj is MeshInstance3D):
			continue
		var mesh := obj as MeshInstance3D
		var entry_var: Variant = _ps1_original_materials[mesh_key]
		if not (entry_var is Dictionary):
			continue
		var entry := entry_var as Dictionary
		mesh.material_override = entry.get("override", null)
		var overrides_var: Variant = entry.get("surface_overrides", [])
		if overrides_var is Array and mesh.mesh != null:
			var overrides := overrides_var as Array
			var count := mesh.mesh.get_surface_count()
			for i in range(count):
				var mat: Material = null
				if i < overrides.size() and overrides[i] is Material:
					mat = overrides[i] as Material
				mesh.set_surface_override_material(i, mat)
	_ps1_original_materials.clear()


func _on_tree_node_added(node: Node) -> void:
	if node is StaticBody3D and String(node.name).find("worldspawn") != -1:
		call_deferred("_apply_worldspawn_globals_from_scene")
	if not enable_ps1_geometry_shader:
		return
	if _ps1_shader == null:
		return
	if node is MeshInstance3D:
		call_deferred("_apply_ps1_to_mesh_deferred", node)


func _apply_ps1_to_mesh_deferred(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_ps1_to_mesh(node as MeshInstance3D)


func _apply_ps1_to_scene(root: Node) -> void:
	if not enable_ps1_geometry_shader:
		return
	if root == null:
		return
	if _ps1_shader == null:
		_setup_ps1_shader()
		if _ps1_shader == null:
			return
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		if m is MeshInstance3D:
			_apply_ps1_to_mesh(m as MeshInstance3D)


func _apply_ps1_to_mesh(mesh: MeshInstance3D) -> void:
	if mesh == null:
		return
	if not is_instance_valid(mesh):
		return
	if _ps1_shader == null:
		return
	var mesh_id := mesh.get_instance_id()
	if _ps1_mesh_ids.has(mesh_id):
		return

	_store_ps1_original_materials(mesh)

	if mesh.material_override != null:
		var converted_override := _convert_to_ps1_material(mesh.material_override)
		if converted_override != null:
			mesh.material_override = converted_override
		_ps1_mesh_ids[mesh_id] = true
		return

	if mesh.mesh == null:
		return
	var surface_count := mesh.mesh.get_surface_count()
	var converted_any := false
	for i in range(surface_count):
		var source := mesh.get_active_material(i)
		if source == null:
			source = mesh.mesh.surface_get_material(i)
		var converted := _convert_to_ps1_material(source)
		if converted != null:
			mesh.set_surface_override_material(i, converted)
			converted_any = true
	if converted_any:
		_ps1_mesh_ids[mesh_id] = true


func _convert_to_ps1_material(source: Material) -> ShaderMaterial:
	if _ps1_shader == null:
		return null
	if source == null:
		return null
	if source is ShaderMaterial:
		var shader_source := source as ShaderMaterial
		if shader_source.shader == _ps1_shader:
			_sync_ps1_material_params(shader_source)
			return shader_source

	var key := "__null__"
	if source != null:
		if not source.resource_path.is_empty():
			key = "path:" + source.resource_path
		else:
			key = "id:%d" % source.get_instance_id()

	if _ps1_material_cache.has(key):
		var cached: Variant = _ps1_material_cache[key]
		if cached is ShaderMaterial:
			var cached_material := cached as ShaderMaterial
			_sync_ps1_material_params(cached_material)
			return cached_material

	var result := ShaderMaterial.new()
	result.shader = _ps1_shader
	result.resource_local_to_scene = true
	result.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
	result.set_shader_parameter("use_texture", false)
	result.set_shader_parameter("metallic", 0.0)
	result.set_shader_parameter("roughness", 1.0)
	result.set_shader_parameter("uv_scale", Vector2.ONE)
	result.set_shader_parameter("uv_offset", Vector2.ZERO)
	result.set_shader_parameter("jitter_depth_independent", ps1_jitter_depth_independent)
	result.set_shader_parameter("jitter_z_coordinate", ps1_jitter_z_coordinate)
	result.set_shader_parameter("affine_texture_mapping", ps1_affine_texture_mapping)
	result.set_shader_parameter("affine_mapping_strength", ps1_affine_mapping_strength)
	result.set_shader_parameter("alpha_scissor_threshold", ps1_alpha_scissor_threshold)

	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		# Triplanar materials rely on world-space projection; keep original.
		if base.uv1_triplanar:
			return null
		result.set_shader_parameter("albedo_color", base.albedo_color)
		# Keep lighting stable for the PS1 look by avoiding imported PBR shininess.
		result.set_shader_parameter("metallic", 0.0)
		result.set_shader_parameter("roughness", 1.0)
		var uv_scale := Vector2(base.uv1_scale.x, base.uv1_scale.y)
		var uv_offset := Vector2(base.uv1_offset.x, base.uv1_offset.y)
		if is_zero_approx(uv_scale.x):
			uv_scale.x = 1.0
		if is_zero_approx(uv_scale.y):
			uv_scale.y = 1.0
		result.set_shader_parameter("uv_scale", uv_scale)
		result.set_shader_parameter("uv_offset", uv_offset)
		if base.albedo_texture != null:
			result.set_shader_parameter("use_texture", true)
			result.set_shader_parameter("albedo_tex", base.albedo_texture)
	elif source is ShaderMaterial:
		var shader_source2 := source as ShaderMaterial
		var tex := _extract_texture_from_shader(shader_source2)
		if tex == null:
			# Unknown custom shader material: keep original to avoid broken textures.
			return null
		result.set_shader_parameter("use_texture", true)
		result.set_shader_parameter("albedo_tex", tex)

	_sync_ps1_material_params(result)
	_ps1_material_cache[key] = result
	_ps1_cached_materials.append(result)
	return result


func _extract_texture_from_shader(material: ShaderMaterial) -> Texture2D:
	if material == null:
		return null
	var candidate_names := ["albedo_texture", "texture_albedo", "albedo_tex", "base_texture", "texture"]
	for n in candidate_names:
		var value: Variant = material.get_shader_parameter(n)
		if value is Texture2D:
			return value as Texture2D
	return null


func _sync_ps1_material_params(material: ShaderMaterial) -> void:
	if material == null:
		return
	material.set_shader_parameter("vertex_snap", ps1_vertex_snap)
	material.set_shader_parameter("color_steps", ps1_color_steps)
	material.set_shader_parameter("posterize_strength", ps1_posterize_strength)
	material.set_shader_parameter("affine_warp_strength", ps1_affine_warp)
	material.set_shader_parameter("uv_jitter", ps1_uv_jitter)
	material.set_shader_parameter("jitter_depth_independent", ps1_jitter_depth_independent)
	material.set_shader_parameter("jitter_z_coordinate", ps1_jitter_z_coordinate)
	material.set_shader_parameter("affine_texture_mapping", ps1_affine_texture_mapping)
	material.set_shader_parameter("affine_mapping_strength", ps1_affine_mapping_strength)
	material.set_shader_parameter("alpha_scissor_threshold", ps1_alpha_scissor_threshold)
	material.set_shader_parameter("dithering_enabled", ps1_dithering_enabled)
	material.set_shader_parameter("color_dither_strength", ps1_dither_strength)
	material.set_shader_parameter("dither_resolution_scale", ps1_dither_resolution_scale)

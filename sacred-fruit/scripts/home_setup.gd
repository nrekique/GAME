extends Node3D

@export var spawn_collectibles: bool = false
@export var spawn_exit: bool = false

# If false, this script will not auto-run in _ready(). Call run_setup() manually.
@export var auto_run: bool = true

var _has_run: bool = false

# If map-authored collectibles are missing (e.g. scene wasn't rebuilt after map edits),
# this will parse the .map file and spawn them at runtime as a fallback.
@export var fallback_spawn_collectibles_from_map: bool = true

# If a map-authored trigger_exit brush entity is missing (or wasn't rebuilt into the scene),
# parse the .map file and spawn an Area3D with a BoxShape3D that matches the brush bounds.
@export var fallback_spawn_exit_from_map: bool = true
@export var fallback_spawn_hurt_from_map: bool = true
@export var collectible_radius: float = 2.0
@export var collectible_height: float = 0.6
@export var exit_offset: Vector3 = Vector3(0, 0, -6)

@export var collectible_collision_radius: float = 0.35
@export var exit_box_size: Vector3 = Vector3(1.5, 2.0, 1.5)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not auto_run:
		return
	await run_setup()


func run_setup() -> void:
	if _has_run:
		return
	_has_run = true
	# Let the instanced HOME scene enter the tree first.
	if not is_inside_tree():
		await tree_entered
	if get_tree() == null:
		return
	await get_tree().process_frame

	var player := _find_player()
	if player == null:
		push_warning("HOME setup: couldn't find PLAYER")
		return

	var game := get_node_or_null("/root/GAME")
	if game == null:
		push_warning("HOME setup: couldn't find /root/GAME")
		return

	if spawn_collectibles:
		_spawn_collectibles_around(player.global_position, game.required_collectibles)
	elif fallback_spawn_collectibles_from_map:
		_try_spawn_collectibles_from_map()
	if spawn_exit:
		_spawn_exit_at(player.global_position + exit_offset)
	elif fallback_spawn_exit_from_map:
		_try_spawn_exit_from_map()
	if fallback_spawn_hurt_from_map:
		_try_spawn_hurt_from_map()


func _try_spawn_collectibles_from_map() -> void:
	# If collectibles already exist (built into HOME.tscn), don't spawn duplicates.
	var existing := get_tree().current_scene.find_children("*", "Collectible", true, false)
	if existing != null and existing.size() > 0:
		return

	# Find the FuncGodotMap node to locate the map file + scale.
	var map_node := _find_func_godot_map()
	if map_node == null:
		return
	var map_path: String = map_node.local_map_file if map_node.local_map_file != "" else map_node.global_map_file
	if map_path == "":
		return
	var scale_factor: float = 0.03125
	if map_node.map_settings != null:
		scale_factor = map_node.map_settings.scale_factor

	var origins := _parse_map_entity_origins(map_path, "item_collectible")
	if origins.is_empty():
		return

	var collectible_scene: PackedScene = load("res://entities/items/collectible/collectible.tscn")
	if collectible_scene == null:
		push_warning("HOME setup: couldn't load collectible scene")
		return

	for i in range(origins.size()):
		var origin_map: Vector3 = origins[i]
		var origin_godot := Vector3(origin_map.y, origin_map.z, origin_map.x) * scale_factor
		var c := collectible_scene.instantiate()
		c.name = "Collectible_map_%02d" % i
		add_child(c)
		if c is Node3D:
			(c as Node3D).global_position = origin_godot


func _try_spawn_exit_from_map() -> void:
	# If an exit trigger already exists (built into HOME.tscn), don't spawn duplicates.
	var existing := get_tree().current_scene.find_children("*", "TriggerExit", true, false)
	if existing != null and existing.size() > 0:
		return

	var map_node := _find_func_godot_map()
	if map_node == null:
		return
	var map_path: String = map_node.local_map_file if map_node.local_map_file != "" else map_node.global_map_file
	if map_path == "":
		return
	var scale_factor: float = 0.03125
	if map_node.map_settings != null:
		scale_factor = map_node.map_settings.scale_factor

	var ents := _parse_map_brush_entities(map_path, "trigger_exit", scale_factor)
	if ents.is_empty():
		return

	for i in range(ents.size()):
		var ent := ents[i]
		var aabb: AABB = ent.get("aabb", AABB()) as AABB
		if aabb.size == Vector3.ZERO:
			continue
		var e := TriggerExit.new()
		e.name = "ExitTrigger_map_%02d" % i
		add_child(e)
		var props: Dictionary = ent.get("props", {}) as Dictionary
		if not props.is_empty() and e.has_method("_func_godot_apply_properties"):
			e.call("_func_godot_apply_properties", props)
		# Spawn at AABB center, collision shape centered on the node.
		e.global_position = aabb.position + aabb.size * 0.5
		e.show_volume = true

		var shape := BoxShape3D.new()
		shape.size = aabb.size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		e.add_child(cs)

		# Ensure the area detects the player (default player layer is usually 1)
		e.collision_layer = 0
		e.collision_mask = 1


func _try_spawn_hurt_from_map() -> void:
	# If trigger_hurt already exists (built into the baked scene), don't spawn duplicates.
	var existing := get_tree().current_scene.find_children("*", "TriggerHurt", true, false)
	if existing != null and existing.size() > 0:
		return

	var map_node := _find_func_godot_map()
	if map_node == null:
		return
	var map_path: String = map_node.local_map_file if map_node.local_map_file != "" else map_node.global_map_file
	if map_path == "":
		return
	var scale_factor: float = 0.03125
	if map_node.map_settings != null:
		scale_factor = map_node.map_settings.scale_factor

	var ents := _parse_map_brush_entities(map_path, "trigger_hurt", scale_factor)
	if ents.is_empty():
		return

	for i in range(ents.size()):
		var ent := ents[i]
		var aabb: AABB = ent.get("aabb", AABB()) as AABB
		if aabb.size == Vector3.ZERO:
			continue
		var t := TriggerHurt.new()
		t.name = "TriggerHurt_map_%02d" % i
		add_child(t)
		var props: Dictionary = ent.get("props", {}) as Dictionary
		if not props.is_empty() and t.has_method("_func_godot_apply_properties"):
			t.call("_func_godot_apply_properties", props)
		# Spawn at AABB center, collision shape centered on the node.
		t.global_position = aabb.position + aabb.size * 0.5
		t.show_volume = false

		var shape := BoxShape3D.new()
		shape.size = aabb.size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		t.add_child(cs)

		# Ensure the area detects the player (default player layer is usually 1)
		t.collision_layer = 0
		t.collision_mask = 1


func _find_func_godot_map() -> Node:
	# In HOME_play, the map lives under the instanced HOME scene.
	var current := get_tree().current_scene
	if current == null:
		return null
	var found := current.find_child("FuncGodotMap", true, false)
	return found


func _parse_map_entity_origins(map_path: String, classname: String) -> Array[Vector3]:
	var results: Array[Vector3] = []
	var f := FileAccess.open(map_path, FileAccess.READ)
	if f == null:
		push_warning("HOME setup: couldn't open map file: %s" % map_path)
		return results

	# Track brace depth so brush braces don't confuse entity parsing.
	var depth := 0
	var is_target := false
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "{":
			depth += 1
			# Entering a new entity (top-level).
			if depth == 1:
				is_target = false
			continue
		if line == "}":
			# Leaving scope; if we're closing an entity, reset.
			if depth == 1:
				is_target = false
			depth = maxi(0, depth - 1)
			continue
		# Only parse keyvalues at entity scope depth.
		if depth != 1:
			continue

		# Very small, permissive parsing: look for the quoted key/value pairs.
		if line.begins_with('"classname"'):
			# Example: "classname" "item_collectible"
			is_target = (line.find('"%s"' % classname) != -1)
			continue

		if is_target and line.begins_with('"origin"'):
			# Example: "origin" "116 82 36"
			var parts := line.split('"')
			# parts: [ , origin,  , 116 82 36, ] (varies, but value is usually at index 3)
			var value := ""
			if parts.size() >= 4:
				value = parts[3]
			else:
				continue
			var comps := value.split_floats(" ")
			if comps.size() >= 3:
				results.append(Vector3(comps[0], comps[1], comps[2]))
			# Keep scanning; an entity should only have one origin.

	f.close()
	return results



func _parse_map_brush_entities(map_path: String, classname: String, scale_factor: float) -> Array[Dictionary]:
	# Parses Quake .map brush entities and returns dictionaries containing:
	#   - aabb: AABB (in Godot space)
	#   - props: Dictionary of keyvalues (strings)
	# Bounds are computed from the face plane points.
	var results: Array[Dictionary] = []
	var f := FileAccess.open(map_path, FileAccess.READ)
	if f == null:
		push_warning("HOME setup: couldn't open map file: %s" % map_path)
		return results

	var depth := 0
	var in_target_entity := false
	var props: Dictionary = {}
	var any_points := false
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO

	while not f.eof_reached():
		var raw := f.get_line()
		var line := raw.strip_edges()
		if line == "{":
			depth += 1
			if depth == 1:
				# Entering a new entity.
				in_target_entity = false
				props = {}
				any_points = false
				min_v = Vector3.ZERO
				max_v = Vector3.ZERO
			continue
		if line == "}":
			# Closing a scope. If we're closing the entity, finalize.
			if depth == 1 and in_target_entity and any_points:
				# Convert AABB from map-space to Godot space.
				var aabb_min := Vector3(min_v.y, min_v.z, min_v.x) * scale_factor
				var aabb_max := Vector3(max_v.y, max_v.z, max_v.x) * scale_factor
				var aabb_pos := Vector3(
					minf(aabb_min.x, aabb_max.x),
					minf(aabb_min.y, aabb_max.y),
					minf(aabb_min.z, aabb_max.z)
				)
				var aabb_size := Vector3(
					absf(aabb_max.x - aabb_min.x),
					absf(aabb_max.y - aabb_min.y),
					absf(aabb_max.z - aabb_min.z)
				)
				results.append({
					"aabb": AABB(aabb_pos, aabb_size),
					"props": props.duplicate(true)
				})
			depth = maxi(0, depth - 1)
			continue

		# Entity keyvalues live at depth 1.
		if depth == 1:
			if line.begins_with('"'):
				# Generic key/value capture: "key" "value"
				var parts := line.split('"')
				if parts.size() >= 4:
					var k := parts[1]
					var v := parts[3]
					props[k] = v
					if k == "classname":
						in_target_entity = (v == classname)
			continue

		# Brush face lines live at depth >= 2 and start with '(' in standard .map.
		if not in_target_entity:
			continue
		if depth < 2:
			continue
		if not line.begins_with("("):
			continue

		var pts := _extract_map_face_points(line)
		for p in pts:
			if not any_points:
				min_v = p
				max_v = p
				any_points = true
			else:
				min_v.x = minf(min_v.x, p.x)
				min_v.y = minf(min_v.y, p.y)
				min_v.z = minf(min_v.z, p.z)
				max_v.x = maxf(max_v.x, p.x)
				max_v.y = maxf(max_v.y, p.y)
				max_v.z = maxf(max_v.z, p.z)

	f.close()
	return results


func _extract_map_face_points(line: String) -> Array[Vector3]:
	# Extracts all (x y z) point triplets from a Quake .map face line.
	var pts: Array[Vector3] = []
	var idx := 0
	while true:
		var a := line.find("(", idx)
		if a == -1:
			break
		var b := line.find(")", a + 1)
		if b == -1:
			break
		var inside := line.substr(a + 1, b - a - 1).strip_edges()
		var comps := inside.split_floats(" ")
		if comps.size() >= 3:
			pts.append(Vector3(comps[0], comps[1], comps[2]))
		idx = b + 1
	return pts


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("PLAYER")
	for p in players:
		if p is Node3D:
			return p
	# Fallback: common name
	var current := get_tree().current_scene
	if current:
		var by_name := current.get_node_or_null("Player")
		if by_name is Node3D:
			return by_name
	return null


func _spawn_collectibles_around(center: Vector3, count: int) -> void:
	count = maxi(0, count)
	if count == 0:
		return

	for i in count:
		var angle := TAU * float(i) / float(count)
		var pos := center + Vector3(cos(angle), 0.0, sin(angle)) * collectible_radius
		pos.y = center.y + collectible_height

		var c := Collectible.new()
		c.name = "Collectible_%02d" % i
		c.value = 1
		c.auto_free = true
		add_child(c)
		c.global_position = pos

		# Collision
		var shape := SphereShape3D.new()
		shape.radius = collectible_collision_radius
		var cs := CollisionShape3D.new()
		cs.shape = shape
		c.add_child(cs)

		# Visible mesh
		var mi := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.25
		mesh.height = 0.5
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.2, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.1, 0.2)
		mi.material_override = mat
		c.add_child(mi)

		# Ensure the area detects the player (default player layer is usually 1)
		c.collision_layer = 0
		c.collision_mask = 1


func _spawn_exit_at(pos: Vector3) -> void:
	var e := TriggerExit.new()
	e.name = "ExitTrigger"
	add_child(e)
	e.global_position = pos

	var shape := BoxShape3D.new()
	shape.size = exit_box_size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	e.add_child(cs)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = exit_box_size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.9, 0.35, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.3)
	mi.material_override = mat
	e.add_child(mi)

	e.collision_layer = 0
	e.collision_mask = 1

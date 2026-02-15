extends Node3D

@export var spawn_collectibles: bool = false
@export var spawn_exit: bool = false
@export var collectible_radius: float = 2.0
@export var collectible_height: float = 0.6
@export var exit_offset: Vector3 = Vector3(0, 0, -6)

@export var collectible_collision_radius: float = 0.35
@export var exit_box_size: Vector3 = Vector3(1.5, 2.0, 1.5)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Let the instanced HOME scene enter the tree first.
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
	if spawn_exit:
		_spawn_exit_at(player.global_position + exit_offset)


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

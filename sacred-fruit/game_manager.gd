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

var collected_collectibles: int = 0
var _hud: CanvasLayer = null
var _exit_unlocked_emitted: bool = false
var _has_won: bool = false

var _player: Node = null
var player_health: int = 0
var player_max_health: int = 0
var player_max_overhealth: int = 0

func use_targets(activator: Node, target: String) -> void:
	# Targetnames are really Godot Groups, so we can have multiple entities 
	# share a common "targetname" in Trenchbroom.
	var target_list: Array[Node] = get_tree().get_nodes_in_group(target)
	for targ in target_list:
		var f: String
		# Be careful when specifying a function since we can't pass arguments 
		# to it (without hackarounds of course)
		if 'targetfunc' in activator:
			f = activator.targetfunc
		if f.is_empty():
			f = "use"
		if targ.has_method(f):
			targ.call(f)

func set_targetname(node: Node, targetname: String) -> void:
	if node != null and not targetname.is_empty():
		node.add_to_group(targetname)

# Converts Quake 1 axis to Godot axis
static func id_vec_to_godot_vec(vec: Variant)->Vector3:
	var org: Vector3 = Vector3.ZERO
	if vec is Vector3:
		org = vec
	elif vec is String:
		var arr: PackedFloat64Array = (vec as String).split_floats(" ")
		for i in max(arr.size(), 3):
			org[i] = arr[i]
	return Vector3(org.y, org.z, org.x)


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_reset_objective_state()
	_spawn_hud_if_missing()
	# For huge baked func_godot scenes (like HOME.tscn), this can reduce node count
	# and speed up physics broadphase by replacing thousands of brush colliders with
	# a single trimesh collider derived from the visual mesh.
	call_deferred("_optimize_worldspawn_collisions")
	# In case player registers before GAME is ready, try to find one.
	call_deferred("_try_register_existing_player")


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

@tool
class_name PhysicsBall
extends RigidBody3D

@export var targetname: String = ""
@export var tumbleweed_enabled: bool = true
@export_range(0.1, 4.0, 0.01) var radius: float = 0.35
@export_range(0.1, 100.0, 0.1) var mass_kg: float = 2.0
@export_range(0.0, 20.0, 0.01) var wind_response: float = 6.0
@export_range(0.0, 20.0, 0.01) var rolling_torque: float = 1.8
@export_range(0.0, 40.0, 0.1) var max_speed: float = 10.0
@export_range(0.0, 5.0, 0.01) var linear_damp_custom: float = 0.35
@export_range(0.0, 5.0, 0.01) var angular_damp_custom: float = 0.2
@export_range(0.0, 3.0, 0.01) var gust_strength: float = 0.45
@export_range(0.0, 8.0, 0.01) var gust_frequency: float = 1.3
@export var shell_color: Color = Color(0.57, 0.42, 0.24, 1.0)
@export var interact_pickup_enabled: bool = true

var _wind_direction: Vector2 = Vector2(1.0, 0.25)
var _wind_speed: float = 0.0
var _wind_intensity: float = 1.0
var _wind_poll_timer: float = 0.0
var _source_cache: Node = null
var _holder: Node3D = null
var _held_target_position: Vector3 = Vector3.ZERO
var _held_target_valid: bool = false


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("tumbleweed_enabled"):
		tumbleweed_enabled = _to_bool(props["tumbleweed_enabled"], tumbleweed_enabled)
	if props.has("radius"):
		radius = maxf(float(props["radius"]), 0.1)
	if props.has("mass_kg"):
		mass_kg = maxf(float(props["mass_kg"]), 0.1)
	if props.has("wind_response"):
		wind_response = maxf(float(props["wind_response"]), 0.0)
	if props.has("rolling_torque"):
		rolling_torque = maxf(float(props["rolling_torque"]), 0.0)
	if props.has("max_speed"):
		max_speed = maxf(float(props["max_speed"]), 0.0)
	if props.has("linear_damp_custom"):
		linear_damp_custom = maxf(float(props["linear_damp_custom"]), 0.0)
	if props.has("angular_damp_custom"):
		angular_damp_custom = maxf(float(props["angular_damp_custom"]), 0.0)
	if props.has("gust_strength"):
		gust_strength = maxf(float(props["gust_strength"]), 0.0)
	if props.has("gust_frequency"):
		gust_frequency = maxf(float(props["gust_frequency"]), 0.0)
	if props.has("interact_pickup_enabled"):
		interact_pickup_enabled = _to_bool(props["interact_pickup_enabled"], interact_pickup_enabled)


func _ready() -> void:
	ensure_default_children()
	gravity_scale = 1.0
	mass = mass_kg
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = linear_damp_custom
	angular_damp = angular_damp_custom
	continuous_cd = true
	can_sleep = true
	if not Engine.is_editor_hint() and targetname != "":
		GAME.set_targetname(self, targetname)
	_refresh_wind_source(true)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_wind_poll_timer += delta
	if _wind_poll_timer >= 0.35:
		_wind_poll_timer = 0.0
		_refresh_wind_source(false)
	if is_held():
		_apply_held_transform(delta)
		return
	if not tumbleweed_enabled:
		return
	_apply_wind_motion(delta)


func interact(activator: Node = null) -> bool:
	if not interact_pickup_enabled:
		return false
	var holder: Node3D = activator as Node3D
	if holder == null:
		return false
	if is_held_by(holder):
		drop()
		return true
	pickup(holder)
	return true


func pickup(holder: Node3D) -> void:
	if holder == null:
		return
	_holder = holder
	_held_target_valid = false
	sleeping = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func drop(throw_velocity: Vector3 = Vector3.ZERO) -> void:
	_holder = null
	_held_target_valid = false
	freeze = false
	sleeping = false
	linear_velocity = throw_velocity


func set_hold_target_position(world_pos: Vector3) -> void:
	_held_target_position = world_pos
	_held_target_valid = true


func is_held() -> bool:
	return _holder != null and is_instance_valid(_holder)


func is_held_by(node: Node) -> bool:
	return is_held() and node == _holder


func _apply_held_transform(delta: float) -> void:
	if not _held_target_valid:
		return
	var t: float = clampf(delta * 18.0, 0.0, 1.0)
	global_position = global_position.lerp(_held_target_position, t)
	global_rotation = global_rotation.lerp(Vector3.ZERO, clampf(delta * 6.0, 0.0, 1.0))


func _apply_wind_motion(delta: float) -> void:
	var dir2: Vector2 = _wind_direction.normalized()
	if dir2.length_squared() < 0.0001:
		return
	var dir3 := Vector3(dir2.x, 0.0, dir2.y)
	var wind_mag: float = maxf(_wind_speed, 0.0) * wind_response * lerpf(0.25, 1.0, clampf(_wind_intensity, 0.0, 1.0))
	if wind_mag <= 0.001:
		return

	var time_s: float = float(Time.get_ticks_msec()) * 0.001
	var phase: float = float(get_instance_id() % 997) * 0.013
	var gust: float = 1.0 + sin((time_s + phase) * gust_frequency) * gust_strength
	apply_central_force(dir3 * wind_mag * gust)

	var torque_axis: Vector3 = Vector3.UP.cross(dir3).normalized()
	if torque_axis.length_squared() > 0.0001:
		apply_torque(torque_axis * rolling_torque * wind_mag * delta)

	var planar: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var planar_speed: float = planar.length()
	if max_speed > 0.0 and planar_speed > max_speed:
		var clamped_planar: Vector3 = planar.normalized() * max_speed
		linear_velocity = Vector3(clamped_planar.x, linear_velocity.y, clamped_planar.z)


func _refresh_wind_source(force_scan: bool) -> void:
	if force_scan or _source_cache == null or not is_instance_valid(_source_cache):
		_source_cache = _find_wind_source()
	if _source_cache == null:
		return
	var source: Node = _source_cache
	var raw_dir: Variant = null
	if "wind_direction" in source:
		raw_dir = source.get("wind_direction")
	elif "wind_dir" in source:
		raw_dir = source.get("wind_dir")
	if raw_dir != null:
		_wind_direction = _parse_vec2(raw_dir, _wind_direction)

	if "wind_speed" in source:
		var raw_speed: Variant = source.get("wind_speed")
		_wind_speed = maxf(float(raw_speed), 0.0)
	if "intensity" in source:
		var raw_intensity: Variant = source.get("intensity")
		_wind_intensity = clampf(float(raw_intensity), 0.0, 1.0)
	else:
		_wind_intensity = 1.0
	if "enabled" in source:
		var raw_enabled: Variant = source.get("enabled")
		if not _to_bool(raw_enabled, true):
			_wind_speed = 0.0


func _find_wind_source() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	if scene == null:
		return null

	var storm: Node = scene.find_child("SandstormController", true, false)
	if storm != null and "wind_speed" in storm:
		return storm

	var nodes: Array[Node] = scene.find_children("*", "Node", true, false)
	var fallback: Node = null
	for node in nodes:
		if node == null or node == self:
			continue
		if not ("wind_speed" in node):
			continue
		if not ("wind_direction" in node or "wind_dir" in node):
			continue
		var node_name: String = node.name.to_lower()
		if node_name.contains("env_wind"):
			return node
		if node_name.contains("sandstorm"):
			return node
		if fallback == null:
			fallback = node
	return fallback


func ensure_default_children() -> void:
	var has_shape: bool = false
	for child in get_children():
		if child is CollisionShape3D:
			has_shape = true
			var existing_shape: Shape3D = (child as CollisionShape3D).shape
			if existing_shape is SphereShape3D:
				(existing_shape as SphereShape3D).radius = radius
			break
	if not has_shape:
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = radius
		var cs := CollisionShape3D.new()
		cs.shape = sphere_shape
		add_child(cs)

	var has_mesh: bool = false
	for child in get_children():
		if child is MeshInstance3D:
			has_mesh = true
			break
	if not has_mesh:
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		mi.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = shell_color
		mat.roughness = 0.9
		mat.metallic = 0.0
		mi.material_override = mat
		add_child(mi)


func _parse_vec2(v: Variant, fallback: Vector2) -> Vector2:
	if v is Vector2:
		return v
	var parts: PackedFloat64Array = String(v).replace(",", " ").split_floats(" ")
	if parts.size() >= 2:
		return Vector2(parts[0], parts[1])
	return fallback


func _to_bool(value: Variant, default_value: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING:
			var s: String = String(value).strip_edges().to_lower()
			if s in ["1", "true", "yes", "on", "y"]:
				return true
			if s in ["0", "false", "no", "off", "n", ""]:
				return false
			return default_value
		_:
			return default_value

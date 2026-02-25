@tool
class_name WaterVolume
extends Volume

# Combined water brush/volume behavior:
# - character bodies can switch to swim movement state
# - rigid bodies receive buoyancy + drag while inside

@export_range(0.0, 3.0, 0.01) var default_buoyancy: float = 1.0
@export_range(0.0, 20.0, 0.1) var linear_drag: float = 3.0
@export_range(0.0, 20.0, 0.1) var angular_drag: float = 2.0
@export var affect_sleeping_bodies: bool = false

var _contact_counts: Dictionary = {}
var _contact_nodes: Dictionary = {}
var _rigid_body_ids: Dictionary = {}
var _was_enabled_last_frame: bool = true


func _func_godot_apply_properties(props: Dictionary) -> void:
	super._func_godot_apply_properties(props)
	if props.has("default_buoyancy"):
		default_buoyancy = clampf(_to_float(props["default_buoyancy"], default_buoyancy), 0.0, 3.0)
	if props.has("linear_drag"):
		linear_drag = maxf(_to_float(props["linear_drag"], linear_drag), 0.0)
	if props.has("angular_drag"):
		angular_drag = maxf(_to_float(props["angular_drag"], angular_drag), 0.0)
	if props.has("affect_sleeping_bodies"):
		affect_sleeping_bodies = _to_bool(props["affect_sleeping_bodies"], affect_sleeping_bodies)


func _exit_tree() -> void:
	_clear_runtime_contacts()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not enabled:
		if _was_enabled_last_frame:
			_clear_runtime_contacts()
		_was_enabled_last_frame = false
		return
	_was_enabled_last_frame = true
	if _rigid_body_ids.is_empty():
		return
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if gravity <= 0.0:
		gravity = 9.8

	for id_v in _rigid_body_ids.keys():
		var id: int = int(id_v)
		if int(_contact_counts.get(id, 0)) <= 0:
			_rigid_body_ids.erase(id)
			_contact_nodes.erase(id)
			_contact_counts.erase(id)
			continue

		var node_v: Variant = _contact_nodes.get(id, null)
		var body: RigidBody3D = node_v as RigidBody3D
		if body == null or not is_instance_valid(body):
			_rigid_body_ids.erase(id)
			_contact_nodes.erase(id)
			_contact_counts.erase(id)
			continue
		if body.freeze:
			continue
		if body.sleeping and not affect_sleeping_bodies:
			continue

		var mass: float = maxf(body.mass, 0.0001)
		var buoyancy: float = _resolve_body_buoyancy(body)
		body.apply_central_force(Vector3.UP * gravity * mass * buoyancy)
		if linear_drag > 0.0:
			body.apply_central_force(-body.linear_velocity * linear_drag * mass)
		if angular_drag > 0.0:
			body.apply_torque(-body.angular_velocity * angular_drag * mass)


func _process_body(body: Node, entered: bool) -> void:
	if body == null:
		return
	var id: int = body.get_instance_id()
	var count: int = int(_contact_counts.get(id, 0))
	if entered:
		count += 1
	else:
		count = maxi(0, count - 1)

	if count <= 0:
		_contact_counts.erase(id)
		_contact_nodes.erase(id)
		_rigid_body_ids.erase(id)
	else:
		_contact_counts[id] = count
		_contact_nodes[id] = body
		if body is RigidBody3D:
			_rigid_body_ids[id] = true

	if entered and count == 1:
		_notify_body_water_state(body, true)
	elif (not entered) and count == 0:
		_notify_body_water_state(body, false)


func _notify_body_water_state(body: Node, entered: bool) -> void:
	if body == null:
		return
	if body.has_method("on_water_volume_state_changed"):
		body.call("on_water_volume_state_changed", self, entered, _get_water_settings())
		return
	if body.has_method("set_water_volume_state"):
		body.call("set_water_volume_state", entered)


func _get_water_settings() -> Dictionary:
	return {
		"default_buoyancy": default_buoyancy,
		"linear_drag": linear_drag,
		"angular_drag": angular_drag
	}


func _clear_runtime_contacts() -> void:
	for id_v in _contact_nodes.keys():
		var node_v: Variant = _contact_nodes.get(id_v, null)
		var body: Node = node_v as Node
		if body != null and is_instance_valid(body):
			_notify_body_water_state(body, false)
	_contact_counts.clear()
	_contact_nodes.clear()
	_rigid_body_ids.clear()


func _resolve_body_buoyancy(body: RigidBody3D) -> float:
	if body == null:
		return clampf(default_buoyancy, 0.0, 3.0)

	if body.has_method("get_water_buoyancy"):
		var method_v: Variant = body.call("get_water_buoyancy")
		return clampf(_to_float(method_v, default_buoyancy), 0.0, 3.0)

	if "water_buoyancy" in body:
		var prop_v: Variant = body.get("water_buoyancy")
		return clampf(_to_float(prop_v, default_buoyancy), 0.0, 3.0)

	var props_v: Variant = null
	if "func_godot_properties" in body:
		props_v = body.get("func_godot_properties")
	if props_v is Dictionary:
		var props: Dictionary = props_v as Dictionary
		if props.has("water_buoyancy"):
			return clampf(_to_float(props["water_buoyancy"], default_buoyancy), 0.0, 3.0)

	if body.has_meta("func_godot_properties"):
		var meta_props_v: Variant = body.get_meta("func_godot_properties")
		if meta_props_v is Dictionary:
			var meta_props: Dictionary = meta_props_v as Dictionary
			if meta_props.has("water_buoyancy"):
				return clampf(_to_float(meta_props["water_buoyancy"], default_buoyancy), 0.0, 3.0)

	return clampf(default_buoyancy, 0.0, 3.0)


func _to_float(value: Variant, fallback: float) -> float:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return float(value)
		TYPE_STRING:
			var s: String = String(value).strip_edges()
			if s.is_empty():
				return fallback
			return s.to_float()
	return fallback


func _to_bool(value: Variant, fallback: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value) != 0
		TYPE_FLOAT:
			return absf(float(value)) > 0.0001
		TYPE_STRING:
			var s: String = String(value).strip_edges().to_lower()
			if s in ["1", "true", "yes", "on"]:
				return true
			if s in ["0", "false", "no", "off"]:
				return false
	return fallback

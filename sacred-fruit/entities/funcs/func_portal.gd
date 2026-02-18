@tool
class_name FuncPortal
extends StaticBody3D

@export var target: String = ""
@export var targetname: String = ""
@export var enabled: bool = true
@export_range(0.25, 1.0, 0.05) var render_scale: float = 0.75
@export_range(0.01, 1.0, 0.01) var teleport_cooldown: float = 0.20
@export_range(0.01, 0.5, 0.01) var exit_offset: float = 0.12
@export var reverse_normal: bool = false

const LINK_RETRY_SECONDS := 0.5
const PLANE_EPSILON := 0.01

var _linked_portal: FuncPortal = null
var _viewport: SubViewport
var _portal_camera: Camera3D
var _surface: MeshInstance3D
var _surface_material: StandardMaterial3D

var _portal_local_xform: Transform3D = Transform3D.IDENTITY
var _portal_half_extents: Vector2 = Vector2.ONE * 0.5
var _portal_depth: float = 0.1

var _prev_local_pos_by_entity: Dictionary = {}
var _teleport_until_msec: Dictionary = {}
var _link_retry_accum: float = 0.0


static func _to_bool(value: Variant, default_value: bool) -> bool:
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


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = String(props["target"])
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("enabled"):
		enabled = _to_bool(props["enabled"], enabled)
	if props.has("render_scale"):
		render_scale = clampf(float(props["render_scale"]), 0.25, 1.0)
	if props.has("teleport_cooldown"):
		teleport_cooldown = clampf(float(props["teleport_cooldown"]), 0.01, 1.0)
	if props.has("exit_offset"):
		exit_offset = clampf(float(props["exit_offset"]), 0.01, 0.5)
	if props.has("reverse_normal"):
		reverse_normal = _to_bool(props["reverse_normal"], reverse_normal)


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	add_to_group("func_portal")
	if targetname != "":
		GAME.set_targetname(self, targetname)

	_disable_collision_shapes()
	_build_portal_surface()
	_setup_portal_viewport()
	_resolve_linked_portal(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not enabled:
		if _surface:
			_surface.visible = false
		return

	_link_retry_accum += delta
	if _linked_portal == null and _link_retry_accum >= LINK_RETRY_SECONDS:
		_link_retry_accum = 0.0
		_resolve_linked_portal(false)

	_update_viewport_size()
	_update_portal_camera()
	if _surface:
		_surface.visible = (_linked_portal != null)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not enabled or _linked_portal == null:
		return

	for n in get_tree().get_nodes_in_group("PLAYER"):
		if n is Node3D:
			_check_crossing(n as Node3D)


func _resolve_linked_portal(force: bool) -> void:
	if target.strip_edges().is_empty():
		if force:
			_linked_portal = null
		return
	var candidates := get_tree().get_nodes_in_group(target.strip_edges())
	var found: FuncPortal = null
	for n in candidates:
		if n == self:
			continue
		if n is FuncPortal:
			found = n as FuncPortal
			break
	_linked_portal = found


func _build_portal_surface() -> void:
	var bounds := _compute_local_bounds()
	_configure_portal_plane_from_bounds(bounds)

	if _surface == null:
		_surface = MeshInstance3D.new()
		_surface.name = "PortalSurface"
		_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_surface)

	var quad := QuadMesh.new()
	quad.size = _portal_half_extents * 2.0
	_surface.mesh = quad
	_surface.transform = _portal_local_xform

	if _surface_material == null:
		_surface_material = StandardMaterial3D.new()
		_surface_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_surface_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_surface.material_override = _surface_material


func _setup_portal_viewport() -> void:
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "PortalViewport"
		_viewport.usage = SubViewport.USAGE_3D
		_viewport.transparent_bg = false
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport)

	if _portal_camera == null:
		_portal_camera = Camera3D.new()
		_portal_camera.name = "PortalCamera"
		_portal_camera.current = false
		_viewport.add_child(_portal_camera)

	_update_viewport_size()
	if _surface_material:
		_surface_material.albedo_texture = _viewport.get_texture()


func _update_viewport_size() -> void:
	if _viewport == null:
		return
	var root_vp_size := get_viewport().get_visible_rect().size
	var w := maxi(64, int(round(root_vp_size.x * render_scale)))
	var h := maxi(64, int(round(root_vp_size.y * render_scale)))
	var wanted := Vector2i(w, h)
	if _viewport.size != wanted:
		_viewport.size = wanted


func _update_portal_camera() -> void:
	if _portal_camera == null or _linked_portal == null:
		return

	var src_cam := get_viewport().get_camera_3d()
	if src_cam == null:
		return

	_portal_camera.fov = src_cam.fov
	_portal_camera.near = maxf(src_cam.near, 0.01)
	_portal_camera.far = src_cam.far
	_portal_camera.keep_aspect = src_cam.keep_aspect
	_portal_camera.cull_mask = src_cam.cull_mask
	_portal_camera.environment = src_cam.environment
	_portal_camera.attributes = src_cam.attributes

	var mapped := _map_transform_to_link(src_cam.global_transform)
	mapped.origin += _linked_portal._get_world_normal() * maxf(exit_offset, 0.01)
	_portal_camera.global_transform = mapped


func _check_crossing(ent: Node3D) -> void:
	var ent_id := ent.get_instance_id()
	var local_now := _world_to_portal_local(ent.global_position)

	if _is_teleport_on_cooldown(ent_id):
		_prev_local_pos_by_entity[ent_id] = local_now
		return

	var local_prev := local_now
	if _prev_local_pos_by_entity.has(ent_id):
		var v: Variant = _prev_local_pos_by_entity[ent_id]
		if v is Vector3:
			local_prev = v

	_prev_local_pos_by_entity[ent_id] = local_now

	var crossed_forward := local_prev.z > PLANE_EPSILON and local_now.z <= PLANE_EPSILON
	if not crossed_forward:
		return
	if not _point_inside_portal(local_now):
		return

	_teleport_entity(ent)


func _teleport_entity(ent: Node3D) -> void:
	if _linked_portal == null:
		return

	var mapped := _map_transform_to_link(ent.global_transform)
	mapped.origin += _linked_portal._get_world_normal() * maxf(exit_offset, 0.01)

	if ent is CharacterBody3D:
		var body := ent as CharacterBody3D
		var vel := body.velocity
		body.global_transform = mapped
		body.velocity = _map_direction_to_link(vel)
	else:
		ent.global_transform = mapped

	var ent_id := ent.get_instance_id()
	_set_teleport_cooldown(ent_id)
	_prev_local_pos_by_entity[ent_id] = _world_to_portal_local(ent.global_position)
	_linked_portal._register_remote_teleport(ent_id, ent.global_position)


func _register_remote_teleport(ent_id: int, world_pos: Vector3) -> void:
	_set_teleport_cooldown(ent_id)
	_prev_local_pos_by_entity[ent_id] = _world_to_portal_local(world_pos)


func _set_teleport_cooldown(ent_id: int) -> void:
	_teleport_until_msec[ent_id] = Time.get_ticks_msec() + int(round(teleport_cooldown * 1000.0))


func _is_teleport_on_cooldown(ent_id: int) -> bool:
	if not _teleport_until_msec.has(ent_id):
		return false
	var t: Variant = _teleport_until_msec[ent_id]
	if not (t is int):
		_teleport_until_msec.erase(ent_id)
		return false
	var until := int(t)
	if Time.get_ticks_msec() <= until:
		return true
	_teleport_until_msec.erase(ent_id)
	return false


func _map_transform_to_link(src: Transform3D) -> Transform3D:
	if _linked_portal == null:
		return src
	var entry := _get_portal_global_transform()
	var exit := _linked_portal._get_portal_global_transform()
	var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var local := entry.affine_inverse() * src
	return exit * flip * local


func _map_direction_to_link(dir: Vector3) -> Vector3:
	if _linked_portal == null:
		return dir
	var entry_basis := _get_portal_global_transform().basis
	var exit_basis := _linked_portal._get_portal_global_transform().basis
	var flip_basis := Basis(Vector3.UP, PI)
	return exit_basis * (flip_basis * (entry_basis.inverse() * dir))


func _world_to_portal_local(world_pos: Vector3) -> Vector3:
	return _get_portal_global_transform().affine_inverse() * world_pos


func _point_inside_portal(local_pos: Vector3) -> bool:
	var margin := 0.15
	return absf(local_pos.x) <= (_portal_half_extents.x + margin) and absf(local_pos.y) <= (_portal_half_extents.y + margin)


func _get_portal_global_transform() -> Transform3D:
	return global_transform * _portal_local_xform


func _get_world_normal() -> Vector3:
	return _get_portal_global_transform().basis.z.normalized()


func _disable_collision_shapes() -> void:
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true


func _compute_local_bounds() -> AABB:
	var has_any := false
	var bounds := AABB()

	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var aabb := _transform_aabb(mi.mesh.get_aabb(), mi.transform)
		if not has_any:
			bounds = aabb
			has_any = true
		else:
			bounds = bounds.merge(aabb)

	if has_any:
		return bounds

	for n in find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var aabb := _transform_aabb(cs.shape.get_aabb(), cs.transform)
		if not has_any:
			bounds = aabb
			has_any = true
		else:
			bounds = bounds.merge(aabb)

	if has_any:
		return bounds

	return AABB(Vector3(-0.5, -0.5, -0.05), Vector3(1.0, 1.0, 0.1))


func _transform_aabb(aabb: AABB, xform: Transform3D) -> AABB:
	var corners := [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.end.z)
	]

	var out := AABB()
	var has_any := false
	for p in corners:
		var wp := xform * p
		if not has_any:
			out = AABB(wp, Vector3.ZERO)
			has_any = true
		else:
			out = out.expand(wp)
	return out


func _configure_portal_plane_from_bounds(bounds: AABB) -> void:
	var size := bounds.size.abs()
	var center := bounds.position + size * 0.5

	var axis := 0
	if size.y <= size.x and size.y <= size.z:
		axis = 1
	elif size.z <= size.x and size.z <= size.y:
		axis = 2

	var x_axis := Vector3(1.0, 0.0, 0.0)
	var y_axis := Vector3(0.0, 1.0, 0.0)
	var z_axis := Vector3(0.0, 0.0, 1.0)
	var half_x := maxf(size.x * 0.5, 0.05)
	var half_y := maxf(size.y * 0.5, 0.05)

	if axis == 0:
		x_axis = Vector3(0.0, 1.0, 0.0)
		y_axis = Vector3(0.0, 0.0, 1.0)
		z_axis = Vector3(1.0, 0.0, 0.0)
		half_x = maxf(size.y * 0.5, 0.05)
		half_y = maxf(size.z * 0.5, 0.05)
	elif axis == 1:
		x_axis = Vector3(0.0, 0.0, 1.0)
		y_axis = Vector3(1.0, 0.0, 0.0)
		z_axis = Vector3(0.0, 1.0, 0.0)
		half_x = maxf(size.z * 0.5, 0.05)
		half_y = maxf(size.x * 0.5, 0.05)

	if reverse_normal:
		x_axis = -x_axis
		z_axis = -z_axis

	_portal_half_extents = Vector2(half_x, half_y)
	_portal_depth = maxf(size[axis], 0.01)
	var face_offset := maxf(_portal_depth * 0.5 - 0.005, 0.0)
	var origin := center + z_axis * face_offset
	var basis := Basis(x_axis.normalized(), y_axis.normalized(), z_axis.normalized())
	_portal_local_xform = Transform3D(basis, origin)

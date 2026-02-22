@tool
class_name FuncPortal
extends StaticBody3D
const Util := preload("res://scripts/util.gd")

@export var target: String = ""
@export var targetname: String = ""
@export var enabled: bool = true
@export var use_portals_plugin: bool = true
@export_flags_3d_physics var plugin_teleport_collision_mask: int = 0xFFFFF
@export var plugin_use_opposite_face: bool = false
@export var plugin_face_from_portal_texture: bool = true
@export var plugin_keep_viewports_hot: bool = true
@export var manager_enable_budgeting: bool = true
@export_range(1, 64, 1) var manager_max_active_portals: int = 4
@export_range(0.02, 0.5, 0.01) var manager_refresh_seconds: float = 0.10
@export_range(0.0, 4.0, 0.01) var manager_min_runtime_priority: float = 0.0
@export var manager_require_visible_in_frustum: bool = true
@export var manager_require_line_of_sight: bool = true
@export var dynamic_quality_enabled: bool = true
@export_range(0.25, 1.0, 0.05) var dynamic_min_render_scale: float = 0.30
@export_range(0.5, 200.0, 0.5) var dynamic_near_distance: float = 6.0
@export_range(1.0, 400.0, 0.5) var dynamic_far_distance: float = 32.0
@export_range(0.0, 1.0, 0.05) var dynamic_size_influence: float = 0.65
@export_range(0.01, 0.25, 0.01) var dynamic_scale_step: float = 0.05
@export var portal_axis: String = "auto"
@export var portal_debug: bool = false
@export_range(0.25, 1.0, 0.05) var render_scale: float = 0.60
@export var render_use_window_projection: bool = true
@export var render_use_oblique_clip: bool = false
@export_range(-0.05, 0.05, 0.001) var render_camera_offset: float = 0.0
@export_range(0.0, 0.5, 0.005) var render_min_link_distance: float = 0.03
@export_range(0.01, 1.0, 0.01) var teleport_cooldown: float = 0.20
@export_range(0.01, 0.5, 0.01) var exit_offset: float = 0.12
@export var reverse_normal: bool = false

const LINK_RETRY_SECONDS := 0.5
const PLANE_EPSILON := 0.01
const DEBUG_PRINT_INTERVAL := 0.6
const PORTAL_SURFACE_RENDER_LAYER := 20
const PORTAL_SURFACE_LAYER_MASK := 1 << (PORTAL_SURFACE_RENDER_LAYER - 1)
const PORTAL3D_ADAPTER_SCRIPT := preload("res://entities/funcs/portal3d_adapter.gd")
const PORTAL_RUNTIME_MANAGER_SCRIPT := preload("res://entities/funcs/portal_runtime_manager.gd")
const PORTAL_RUNTIME_MANAGER_NAME := "PortalRuntimeManager"

var _linked_portal: FuncPortal = null
var _plugin_adapter: RefCounted = PORTAL3D_ADAPTER_SCRIPT.new()
var _plugin_portal: Node3D = null
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
var _debug_accum: float = 0.0
var _last_linked_portal_id: int = -1
var _render_ok: bool = false
var _has_stable_window_projection: bool = false
var _stable_frustum_size: float = 1.0
var _stable_frustum_offset: Vector2 = Vector2.ZERO
var _oblique_api_checked: bool = false
var _oblique_api_available: bool = false
var _oblique_unavailable_logged: bool = false
var _custom_proj_api_checked: bool = false
var _custom_proj_api_available: bool = false
var _auto_use_opposite_face: bool = false
var _last_target_resolve_key: String = ""
var _plugin_link_dirty: bool = true
var _last_plugin_cam_id: int = -1
var _last_plugin_enabled: bool = true
var _last_plugin_mask: int = -1
var _last_plugin_keep_hot: bool = true
var _last_plugin_render_scale: float = -1.0
var _portal_runtime_manager: Node = null
var _managed_viewport_active: bool = true


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = String(props["target"])
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("use_portals_plugin"):
		use_portals_plugin = Util.to_bool(props["use_portals_plugin"], use_portals_plugin)
	if props.has("plugin_teleport_collision_mask"):
		plugin_teleport_collision_mask = int(props["plugin_teleport_collision_mask"])
	if props.has("plugin_use_opposite_face"):
		plugin_use_opposite_face = Util.to_bool(props["plugin_use_opposite_face"], plugin_use_opposite_face)
	if props.has("plugin_face_from_portal_texture"):
		plugin_face_from_portal_texture = Util.to_bool(props["plugin_face_from_portal_texture"], plugin_face_from_portal_texture)
	if props.has("plugin_keep_viewports_hot"):
		plugin_keep_viewports_hot = Util.to_bool(props["plugin_keep_viewports_hot"], plugin_keep_viewports_hot)
	if props.has("manager_enable_budgeting"):
		manager_enable_budgeting = Util.to_bool(props["manager_enable_budgeting"], manager_enable_budgeting)
	if props.has("manager_max_active_portals"):
		manager_max_active_portals = maxi(1, int(props["manager_max_active_portals"]))
	if props.has("manager_refresh_seconds"):
		manager_refresh_seconds = clampf(float(props["manager_refresh_seconds"]), 0.02, 0.5)
	if props.has("manager_min_runtime_priority"):
		manager_min_runtime_priority = clampf(float(props["manager_min_runtime_priority"]), 0.0, 4.0)
	if props.has("manager_require_visible_in_frustum"):
		manager_require_visible_in_frustum = Util.to_bool(props["manager_require_visible_in_frustum"], manager_require_visible_in_frustum)
	if props.has("manager_require_line_of_sight"):
		manager_require_line_of_sight = Util.to_bool(props["manager_require_line_of_sight"], manager_require_line_of_sight)
	if props.has("dynamic_quality_enabled"):
		dynamic_quality_enabled = Util.to_bool(props["dynamic_quality_enabled"], dynamic_quality_enabled)
	if props.has("dynamic_min_render_scale"):
		dynamic_min_render_scale = clampf(float(props["dynamic_min_render_scale"]), 0.25, 1.0)
	if props.has("dynamic_near_distance"):
		dynamic_near_distance = clampf(float(props["dynamic_near_distance"]), 0.5, 200.0)
	if props.has("dynamic_far_distance"):
		dynamic_far_distance = clampf(float(props["dynamic_far_distance"]), 1.0, 400.0)
	if props.has("dynamic_size_influence"):
		dynamic_size_influence = clampf(float(props["dynamic_size_influence"]), 0.0, 1.0)
	if props.has("dynamic_scale_step"):
		dynamic_scale_step = clampf(float(props["dynamic_scale_step"]), 0.01, 0.25)
	if props.has("portal_axis"):
		portal_axis = String(props["portal_axis"]).strip_edges().to_lower()
	if props.has("portal_debug"):
		portal_debug = Util.to_bool(props["portal_debug"], portal_debug)
	if props.has("render_scale"):
		render_scale = clampf(float(props["render_scale"]), 0.25, 1.0)
	if props.has("render_use_window_projection"):
		render_use_window_projection = Util.to_bool(props["render_use_window_projection"], render_use_window_projection)
	if props.has("render_use_oblique_clip"):
		render_use_oblique_clip = Util.to_bool(props["render_use_oblique_clip"], render_use_oblique_clip)
	if props.has("render_camera_offset"):
		render_camera_offset = clampf(float(props["render_camera_offset"]), -0.05, 0.05)
	if props.has("render_min_link_distance"):
		render_min_link_distance = clampf(float(props["render_min_link_distance"]), 0.0, 0.5)
	if props.has("teleport_cooldown"):
		teleport_cooldown = clampf(float(props["teleport_cooldown"]), 0.01, 1.0)
	if props.has("exit_offset"):
		exit_offset = clampf(float(props["exit_offset"]), 0.01, 0.5)
	if props.has("reverse_normal"):
		reverse_normal = Util.to_bool(props["reverse_normal"], reverse_normal)

	_on_properties_applied()


func _ready() -> void:
	if Util.editor_hint():
		return

	add_to_group("func_portal")
	_register_portal_runtime_manager()
	if targetname != "":
		var game: Node = _get_game_manager()
		if game != null and game.has_method("set_targetname"):
			game.call("set_targetname", self, targetname)

	_disable_collision_shapes()
	_hide_source_mesh_children()
	if use_portals_plugin:
		_resolve_linked_portal(true)
		return

	_build_portal_surface()
	_setup_portal_viewport()
	_resolve_linked_portal(true)


func _exit_tree() -> void:
	if Util.editor_hint():
		return
	_unregister_portal_runtime_manager()
	if _plugin_portal != null:
		_plugin_adapter.deactivate_portal(_plugin_portal, true)
		if _plugin_portal.has_method("set"):
			_plugin_portal.set("exit_portal", null)
		if is_instance_valid(_plugin_portal):
			_plugin_portal.free()
	_plugin_portal = null
	if _surface_material != null:
		_surface_material.albedo_texture = null
	if _surface != null:
		_surface.material_override = null
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_viewport.world_3d = null
		if is_instance_valid(_viewport):
			_viewport.free()
	_viewport = null
	_portal_camera = null
	_linked_portal = null
	_prev_local_pos_by_entity.clear()
	_teleport_until_msec.clear()


func _process(delta: float) -> void:
	if Util.editor_hint():
		return

	if use_portals_plugin:
		_process_plugin_portal(delta)
		return

	if not enabled:
		if _surface:
			_surface.visible = false
		return

	_link_retry_accum += delta
	if _linked_portal == null and _link_retry_accum >= LINK_RETRY_SECONDS:
		_link_retry_accum = 0.0
		_resolve_linked_portal(false)

	_sync_viewport_world()
	_update_viewport_size()
	_update_portal_camera()
	_update_surface_state()
	_debug_tick(delta)


func _physics_process(_delta: float) -> void:
	if Util.editor_hint() or not enabled or _linked_portal == null:
		return
	if use_portals_plugin:
		return

	for n in get_tree().get_nodes_in_group("PLAYER"):
		if n is Node3D:
			_check_crossing(n as Node3D)


func _resolve_linked_portal(force: bool) -> void:
	var prev_linked_id: int = -1 if _linked_portal == null else _linked_portal.get_instance_id()
	var wanted_target: String = target.strip_edges()
	if wanted_target.is_empty():
		if force:
			_linked_portal = null
			_has_stable_window_projection = false
		return

	# Primary path: direct portal-to-portal property linking.
	# This avoids depending on targetname->group registration timing.
	var candidates: Array[Node] = get_tree().get_nodes_in_group("func_portal")
	var found: FuncPortal = null
	for n in candidates:
		if n == self:
			continue
		if n is FuncPortal and _portal_matches_targetname(n as FuncPortal, wanted_target):
			found = n as FuncPortal
			break

	# Fallback path: legacy group-based linking.
	if found == null:
		var grouped: Array[Node] = get_tree().get_nodes_in_group(wanted_target)
		for n in grouped:
			if n == self:
				continue
			if n is FuncPortal:
				found = n as FuncPortal
				break

	_linked_portal = found
	var linked_id: int = -1 if _linked_portal == null else _linked_portal.get_instance_id()
	if linked_id != prev_linked_id:
		_has_stable_window_projection = false
		_plugin_link_dirty = true
		if use_portals_plugin:
			_sync_plugin_link()
	if portal_debug and _is_runtime_debug_enabled():
		if linked_id != _last_linked_portal_id:
			_last_linked_portal_id = linked_id
			Util.debug_print("[Portal DEBUG] %s link target=%s resolved=%s" % [name, target, (str(linked_id) if linked_id != -1 else "none")])


func _build_portal_surface() -> void:
	_configure_portal_plane()
	if portal_debug and _is_runtime_debug_enabled():
		Util.debug_print("[Portal DEBUG] %s half_extents=%s depth=%.3f axis=%s reverse=%s" % [name, str(_portal_half_extents), _portal_depth, portal_axis, str(reverse_normal)])

	if _surface == null:
		_surface = MeshInstance3D.new()
		_surface.name = "PortalSurface"
		_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_surface)
	_surface.layers = PORTAL_SURFACE_LAYER_MASK

	var quad := QuadMesh.new()
	quad.size = _portal_half_extents * 2.0
	_surface.mesh = quad
	_surface.transform = _portal_local_xform

	if _surface_material == null:
		_surface_material = StandardMaterial3D.new()
		_surface_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_surface_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_surface_material.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
		_surface_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_surface.material_override = _surface_material


func _setup_portal_viewport() -> void:
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "PortalViewport"
		_viewport.disable_3d = false
		_viewport.transparent_bg = false
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport)

	_sync_viewport_world()

	if _portal_camera == null:
		_portal_camera = Camera3D.new()
		_portal_camera.name = "PortalCamera"
		_viewport.add_child(_portal_camera)
	_portal_camera.current = true

	_update_viewport_size()
	if _surface_material:
		_surface_material.albedo_texture = _viewport.get_texture()


func _sync_viewport_world() -> void:
	if _viewport == null:
		return
	var main_world: World3D = get_world_3d()
	if main_world == null:
		var main_vp: Viewport = get_viewport()
		if main_vp != null:
			main_world = main_vp.world_3d
	if main_world != null and _viewport.world_3d != main_world:
		_viewport.world_3d = main_world


func _update_viewport_size() -> void:
	if _viewport == null:
		return
	var root_vp_size: Vector2 = get_viewport().get_visible_rect().size
	var max_w: float = maxf(64.0, root_vp_size.x * render_scale)
	var max_h: float = maxf(64.0, root_vp_size.y * render_scale)
	var portal_aspect: float = maxf(_portal_half_extents.x / maxf(_portal_half_extents.y, 0.001), 0.05)
	var w: int = int(round(max_w))
	var h: int = int(round(float(w) / portal_aspect))
	if h > int(round(max_h)):
		h = int(round(max_h))
		w = int(round(float(h) * portal_aspect))
	w = maxi(64, w)
	h = maxi(64, h)
	var wanted: Vector2i = Vector2i(w, h)
	if _viewport.size != wanted:
		_viewport.size = wanted


func _update_portal_camera() -> void:
	if _portal_camera == null or _linked_portal == null:
		return

	var src_cam := get_viewport().get_camera_3d()
	if src_cam == null:
		return

	_portal_camera.fov = src_cam.fov
	# Portal render camera should sit exactly on the mapped viewpoint for seam continuity.
	# Keep near very small so close geometry through the destination portal is not clipped.
	var render_near: float = 0.001
	_portal_camera.near = render_near
	_portal_camera.far = src_cam.far
	_portal_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var src_mask: int = src_cam.cull_mask
	var filtered_mask: int = src_mask & ~PORTAL_SURFACE_LAYER_MASK
	_portal_camera.cull_mask = filtered_mask if filtered_mask != 0 else src_mask
	_portal_camera.environment = src_cam.environment
	_portal_camera.attributes = src_cam.attributes

	var mapped := _map_transform_to_link(src_cam.global_transform)
	mapped = _enforce_min_link_distance(mapped)
	mapped.origin += _linked_portal._get_world_normal() * render_camera_offset
	_portal_camera.global_transform = mapped
	_reset_custom_projection()
	if render_use_window_projection:
		if not _apply_window_projection(render_near):
			if _has_stable_window_projection:
				_portal_camera.set_frustum(_stable_frustum_size, _stable_frustum_offset, render_near, _portal_camera.far)
				_portal_camera.keep_aspect = Camera3D.KEEP_HEIGHT
			else:
				_portal_camera.set_perspective(src_cam.fov, render_near, src_cam.far)
	else:
		_portal_camera.set_perspective(src_cam.fov, render_near, src_cam.far)


func _update_surface_state() -> void:
	_render_ok = _is_render_ready()
	if _surface == null:
		return

	if _linked_portal == null:
		_surface.visible = false
		return

	_surface.visible = true
	if _surface_material == null:
		return

	if _render_ok:
		_surface_material.albedo_texture = _viewport.get_texture()
		_surface_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	else:
		# Linked portal but no valid render path yet: show a visible debug fallback.
		_surface_material.albedo_texture = null
		_surface_material.albedo_color = Color(1.0, 0.0, 1.0, 1.0)


func _is_render_ready() -> bool:
	if _linked_portal == null:
		return false
	if _viewport == null or _portal_camera == null:
		return false
	if _viewport.world_3d == null:
		return false
	if _viewport.size.x < 8 or _viewport.size.y < 8:
		return false
	var tex: Texture2D = _viewport.get_texture()
	if tex == null:
		return false
	var tex_size: Vector2 = tex.get_size()
	return tex_size.x > 0 and tex_size.y > 0


func _debug_tick(delta: float) -> void:
	if not portal_debug or not _is_runtime_debug_enabled():
		return
	_debug_accum += delta
	if _debug_accum < DEBUG_PRINT_INTERVAL:
		return
	_debug_accum = 0.0
	var linked_id: int = -1 if _linked_portal == null else _linked_portal.get_instance_id()
	var linked_name: String = "none" if _linked_portal == null else String(_linked_portal.name)
	var vp_size: Vector2i = Vector2i.ZERO if _viewport == null else _viewport.size
	var has_world: bool = (_viewport != null and _viewport.world_3d != null)
	var has_cam: bool = (_portal_camera != null and _portal_camera.is_inside_tree())
	var has_tex: bool = (_viewport != null and _viewport.get_texture() != null)
	var surf_vis: bool = (_surface != null and _surface.visible)
	var p_xform: Transform3D = _get_portal_global_transform()
	var portal_aspect: float = _portal_half_extents.x / maxf(_portal_half_extents.y, 0.001)
	Util.debug_print("[Portal DEBUG] %s linked_id=%d linked_name=%s render_ok=%s visible=%s vp=%s world=%s cam=%s tex=%s axis=%s portal_aspect=%.3f normal=%s origin=%s" % [
		name, linked_id, linked_name, str(_render_ok), str(surf_vis), str(vp_size), str(has_world), str(has_cam), str(has_tex), portal_axis,
		portal_aspect, str(p_xform.basis.z.normalized()), str(p_xform.origin)
	])


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


func _enforce_min_link_distance(xf: Transform3D) -> Transform3D:
	if _linked_portal == null or render_min_link_distance <= 0.0:
		return xf
	var out: Transform3D = xf
	var target_xf: Transform3D = _linked_portal._get_portal_global_transform()
	var n: Vector3 = target_xf.basis.z.normalized()
	var dist: float = n.dot(out.origin - target_xf.origin)
	if dist < render_min_link_distance:
		out.origin += n * (render_min_link_distance - dist)
	return out


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


func _hide_source_mesh_children() -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		if _plugin_portal != null and _is_descendant_of(mi, _plugin_portal):
			continue
		mi.visible = false


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	if node == null or ancestor == null:
		return false
	var cur: Node = node.get_parent()
	while cur != null:
		if cur == ancestor:
			return true
		cur = cur.get_parent()
	return false


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GAME")


func _portal_matches_targetname(portal: FuncPortal, wanted_target: String) -> bool:
	if portal == null:
		return false
	for token in portal.targetname.split(","):
		if String(token).strip_edges() == wanted_target:
			return true
	return false


func _on_properties_applied() -> void:
	if Util.editor_hint() or not is_inside_tree():
		return
	if not is_in_group("func_portal"):
		add_to_group("func_portal")
	if targetname != "":
		var game: Node = _get_game_manager()
		if game != null and game.has_method("set_targetname"):
			game.call("set_targetname", self, targetname)
	if use_portals_plugin:
		if manager_enable_budgeting:
			_register_portal_runtime_manager()
		else:
			_unregister_portal_runtime_manager()
		_setup_plugin_portal()
		_resolve_linked_portal(true)
		_sync_plugin_link()
		_mark_plugin_runtime_dirty()
		return
	_unregister_portal_runtime_manager()
	_has_stable_window_projection = false
	_hide_source_mesh_children()
	_build_portal_surface()
	_setup_portal_viewport()
	_resolve_linked_portal(true)
	_update_surface_state()


func _process_plugin_portal(delta: float) -> void:
	var src_cam: Camera3D = get_viewport().get_camera_3d()
	if src_cam == null:
		return

	if _plugin_portal == null:
		_setup_plugin_portal_with_camera(src_cam)
		if _plugin_portal == null:
			return
	if _needs_link_resolve():
		_resolve_linked_portal(false)
	_link_retry_accum += delta
	if _linked_portal == null and _link_retry_accum >= LINK_RETRY_SECONDS:
		_link_retry_accum = 0.0
		_resolve_linked_portal(false)

	var pxf: Transform3D = _get_portal_global_transform()
	if _should_use_opposite_face():
		pxf = _to_opposite_portal_face(pxf)
	_plugin_portal.global_transform = pxf
	_configure_plugin_runtime_if_needed(src_cam)

	if _linked_portal != null:
		_sync_plugin_link()
	_apply_portal_runtime_budget()

	_debug_tick(delta)


func _setup_plugin_portal() -> void:
	var src_cam: Camera3D = get_viewport().get_camera_3d()
	if src_cam == null:
		return
	_setup_plugin_portal_with_camera(src_cam)


func _setup_plugin_portal_with_camera(src_cam: Camera3D) -> void:
	if _plugin_portal != null:
		return
	_configure_portal_plane()
	var p: Node3D = _plugin_adapter.create_runtime_portal(
		self,
		"Portal3D_Runtime",
		_portal_half_extents * 2.0,
		src_cam,
		enabled,
		plugin_teleport_collision_mask,
		plugin_keep_viewports_hot,
		render_scale,
		PORTAL_SURFACE_LAYER_MASK
	)
	if p == null:
		push_error("%s: Failed to create Portal3D runtime wrapper (plugin missing/version mismatch)." % name)
		return
	_plugin_portal = p
	_mark_plugin_runtime_dirty()
	var pxf: Transform3D = _get_portal_global_transform()
	if _should_use_opposite_face():
		pxf = _to_opposite_portal_face(pxf)
	_plugin_portal.global_transform = pxf
	_hide_source_mesh_children()


func _sync_plugin_link() -> void:
	if not use_portals_plugin:
		return
	if _plugin_portal == null:
		return
	if _linked_portal == null or _linked_portal._plugin_portal == null:
		_plugin_adapter.deactivate_portal(_plugin_portal)
		_plugin_link_dirty = true
		return
	if not _plugin_link_dirty:
		return
	var src_cam: Camera3D = get_viewport().get_camera_3d()
	if src_cam == null:
		return
	_ensure_camera_environment(src_cam)
	if not _plugin_adapter.link_portals(_plugin_portal, _linked_portal._plugin_portal, src_cam):
		push_error("%s: Failed to link runtime portal pair." % name)
		return
	_plugin_link_dirty = false


func _to_opposite_portal_face(xf: Transform3D) -> Transform3D:
	var out: Transform3D = xf
	var z: Vector3 = out.basis.z.normalized()
	var face_offset: float = maxf((_portal_depth * 0.5) - 0.005, 0.0)
	out.origin -= z * (face_offset * 2.0)
	return out


func _should_use_opposite_face() -> bool:
	if plugin_face_from_portal_texture:
		return _auto_use_opposite_face
	return plugin_use_opposite_face


func _update_portal_face_from_texture_metadata() -> void:
	_auto_use_opposite_face = plugin_use_opposite_face
	if not has_meta("func_godot_mesh_data"):
		return
	var md_v: Variant = get_meta("func_godot_mesh_data")
	if not (md_v is Dictionary):
		return
	var md: Dictionary = md_v as Dictionary
	if not (md.has("normals") and md.has("textures") and md.has("texture_names")):
		return
	var normals_v: Variant = md["normals"]
	var textures_v: Variant = md["textures"]
	var texture_names_v: Variant = md["texture_names"]
	if not (normals_v is PackedVector3Array and textures_v is PackedInt32Array and texture_names_v is Array):
		return
	var normals: PackedVector3Array = normals_v as PackedVector3Array
	var textures: PackedInt32Array = textures_v as PackedInt32Array
	var texture_names: Array = texture_names_v as Array
	var count: int = mini(normals.size(), textures.size())
	if count <= 0:
		return
	var portal_z: Vector3 = _portal_local_xform.basis.z.normalized()
	var best_score: float = -1.0
	var best_dot: float = 1.0
	var found: bool = false
	for i in range(count):
		var ti: int = textures[i]
		if ti < 0 or ti >= texture_names.size():
			continue
		var tex_name: String = String(texture_names[ti]).to_lower()
		if tex_name.find("portal") == -1:
			continue
		var n: Vector3 = normals[i].normalized()
		if n.length_squared() < 0.000001:
			continue
		var d: float = n.dot(portal_z)
		var score: float = absf(d)
		if score > best_score:
			best_score = score
			best_dot = d
			found = true
	if found:
		_auto_use_opposite_face = best_dot < 0.0


func _ensure_camera_environment(src_cam: Camera3D) -> void:
	if src_cam == null:
		return
	if src_cam.environment != null:
		return
	var world: World3D = src_cam.get_world_3d()
	if world != null and world.environment != null:
		return
	# Plugin _setup_cameras() duplicates camera/world environment; guarantee one exists.
	src_cam.environment = Environment.new()


func _register_portal_runtime_manager() -> void:
	if Util.editor_hint() or not manager_enable_budgeting or not use_portals_plugin:
		return
	if _portal_runtime_manager == null:
		var existing := get_node_or_null("/root/%s" % PORTAL_RUNTIME_MANAGER_NAME)
		if existing != null and existing.has_method("register_portal"):
			_portal_runtime_manager = existing
		else:
			var mgr := PORTAL_RUNTIME_MANAGER_SCRIPT.new()
			mgr.name = PORTAL_RUNTIME_MANAGER_NAME
			get_tree().root.add_child(mgr)
			_portal_runtime_manager = mgr
	if _portal_runtime_manager != null:
		_portal_runtime_manager.register_portal(self, manager_max_active_portals, manager_refresh_seconds, manager_min_runtime_priority)


func _unregister_portal_runtime_manager() -> void:
	if _portal_runtime_manager == null:
		return
	if is_instance_valid(_portal_runtime_manager):
		_portal_runtime_manager.unregister_portal(self)
	_portal_runtime_manager = null


func portal_runtime_priority(cam: Camera3D) -> float:
	if cam == null or not enabled or not use_portals_plugin:
		return -1.0e20
	if _linked_portal == null or _plugin_portal == null:
		return -1.0e20
	if manager_require_visible_in_frustum and not _is_portal_visible_from_camera(cam):
		return -1.0e20
	if manager_require_line_of_sight and not _has_portal_line_of_sight(cam):
		return -1.0e20
	var portal_origin: Vector3 = _get_portal_global_transform().origin
	var to_portal: Vector3 = portal_origin - cam.global_position
	var dist2: float = maxf(to_portal.length_squared(), 0.001)
	var dir_to_portal: Vector3 = to_portal.normalized()
	var cam_forward: Vector3 = -cam.global_basis.z.normalized()
	var face_normal: Vector3 = _get_world_normal()
	var forward_align: float = maxf(cam_forward.dot(dir_to_portal), 0.0)
	var facing: float = absf(face_normal.dot(-dir_to_portal))
	var distance_term: float = 1.0 / (1.0 + dist2 * 0.02)
	var behind_penalty: float = 0.2 if cam.is_position_behind(portal_origin) else 1.0
	return (distance_term * 2.0 + forward_align + facing * 0.5) * behind_penalty


func _is_portal_visible_from_camera(cam: Camera3D) -> bool:
	if cam == null:
		return false
	var origin: Vector3 = _get_portal_global_transform().origin
	if cam.is_position_in_frustum(origin):
		return true
	var corners: Array[Vector3] = _get_portal_corners_world()
	for corner: Vector3 in corners:
		if cam.is_position_in_frustum(corner):
			return true
	return false


func _has_portal_line_of_sight(cam: Camera3D) -> bool:
	if cam == null:
		return false
	var world: World3D = cam.get_world_3d()
	if world == null:
		return true
	var from: Vector3 = cam.global_position
	var to: Vector3 = _get_portal_global_transform().origin
	if from.distance_squared_to(to) <= 0.0001:
		return true
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var excludes: Array[RID] = [self.get_rid()]
	var cam_parent: Node = cam.get_parent()
	if cam_parent is CollisionObject3D:
		excludes.append((cam_parent as CollisionObject3D).get_rid())
	if _linked_portal != null:
		excludes.append(_linked_portal.get_rid())
	params.exclude = excludes
	var hit: Dictionary = world.direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return true
	var collider_v: Variant = hit.get("collider", null)
	if collider_v == null:
		return true
	if collider_v is Node:
		var node: Node = collider_v as Node
		if self.is_ancestor_of(node) or node == self or node.is_ancestor_of(self):
			return true
		if _linked_portal != null and (_linked_portal.is_ancestor_of(node) or node == _linked_portal or node.is_ancestor_of(_linked_portal)):
			return true
	return false


func _apply_portal_runtime_budget() -> void:
	if _plugin_portal == null:
		return
	if not manager_enable_budgeting:
		_set_managed_viewport_active(true)
		return
	if _portal_runtime_manager == null:
		_register_portal_runtime_manager()
		if _portal_runtime_manager == null:
			return
	var active: bool = bool(_portal_runtime_manager.call("is_portal_render_active", self))
	_set_managed_viewport_active(active)


func _set_managed_viewport_active(active: bool) -> void:
	if _managed_viewport_active == active and _plugin_portal != null:
		return
	_managed_viewport_active = active
	if _plugin_portal == null:
		return
	var vp_v: Variant = _plugin_portal.get("portal_viewport")
	if not (vp_v is SubViewport):
		return
	var vp := vp_v as SubViewport
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if active else SubViewport.UPDATE_DISABLED


func _mark_plugin_runtime_dirty() -> void:
	_plugin_link_dirty = true
	_last_plugin_cam_id = -1
	_last_plugin_enabled = not enabled
	_last_plugin_mask = -1
	_last_plugin_keep_hot = not plugin_keep_viewports_hot
	_last_plugin_render_scale = -1.0


func _configure_plugin_runtime_if_needed(src_cam: Camera3D) -> void:
	if _plugin_portal == null or src_cam == null:
		return
	if manager_enable_budgeting and not _managed_viewport_active:
		return
	var cam_id: int = src_cam.get_instance_id()
	var scale: float = _compute_dynamic_render_scale(src_cam)
	var changed: bool = false
	if cam_id != _last_plugin_cam_id:
		changed = true
	if enabled != _last_plugin_enabled:
		changed = true
	if plugin_teleport_collision_mask != _last_plugin_mask:
		changed = true
	if plugin_keep_viewports_hot != _last_plugin_keep_hot:
		changed = true
	if absf(scale - _last_plugin_render_scale) > 0.001:
		changed = true
	if not changed:
		return
	_plugin_adapter.configure_runtime_portal(
		_plugin_portal,
		src_cam,
		enabled,
		plugin_teleport_collision_mask,
		plugin_keep_viewports_hot,
		scale
	)
	_last_plugin_cam_id = cam_id
	_last_plugin_enabled = enabled
	_last_plugin_mask = plugin_teleport_collision_mask
	_last_plugin_keep_hot = plugin_keep_viewports_hot
	_last_plugin_render_scale = scale
	_plugin_link_dirty = true


func _compute_dynamic_render_scale(src_cam: Camera3D) -> float:
	var max_scale: float = clampf(render_scale, 0.25, 1.0)
	if not dynamic_quality_enabled or src_cam == null:
		return max_scale
	var min_scale: float = clampf(minf(dynamic_min_render_scale, max_scale), 0.25, 1.0)
	var portal_origin: Vector3 = _get_portal_global_transform().origin
	var dist: float = maxf(src_cam.global_position.distance_to(portal_origin), 0.01)
	var near_d: float = clampf(dynamic_near_distance, 0.5, 400.0)
	var far_d: float = maxf(dynamic_far_distance, near_d + 0.01)
	var dist_t: float = clampf((dist - near_d) / (far_d - near_d), 0.0, 1.0)
	var distance_quality: float = 1.0 - dist_t
	var portal_radius: float = maxf(_portal_half_extents.length(), 0.05)
	var angular_ratio: float = portal_radius / dist
	var size_quality: float = clampf(angular_ratio * 2.5, 0.0, 1.0)
	var quality: float = clampf(
		lerpf(distance_quality, size_quality, dynamic_size_influence),
		0.0,
		1.0
	)
	var raw_scale: float = lerpf(min_scale, max_scale, quality)
	var step: float = clampf(dynamic_scale_step, 0.01, 0.25)
	var quantized: float = round(raw_scale / step) * step
	return clampf(quantized, min_scale, max_scale)


func _needs_link_resolve() -> bool:
	var target_key: String = target.strip_edges()
	if target_key != _last_target_resolve_key:
		_last_target_resolve_key = target_key
		return true
	if _linked_portal == null:
		return true
	if not is_instance_valid(_linked_portal):
		return true
	if not _portal_matches_targetname(_linked_portal, target_key):
		return true
	return false


func _configure_portal_plane() -> void:
	if _try_configure_portal_plane_from_metadata():
		return
	var bounds: AABB = _compute_local_bounds()
	_configure_portal_plane_from_bounds(bounds)
	if plugin_face_from_portal_texture:
		push_warning("%s: missing exact portal face metadata, using bounds-derived portal plane fallback." % name)


func _try_configure_portal_plane_from_metadata() -> bool:
	if not plugin_face_from_portal_texture:
		return false
	if not has_meta("func_godot_mesh_data"):
		return false
	var md_v: Variant = get_meta("func_godot_mesh_data")
	if not (md_v is Dictionary):
		return false
	var md: Dictionary = md_v as Dictionary
	if _try_configure_portal_plane_from_exact_metadata(md):
		return true
	if not (md.has("normals") and md.has("positions") and md.has("textures") and md.has("texture_names")):
		return false
	var normals_v: Variant = md["normals"]
	var positions_v: Variant = md["positions"]
	var textures_v: Variant = md["textures"]
	var texture_names_v: Variant = md["texture_names"]
	if not (normals_v is PackedVector3Array and positions_v is PackedVector3Array and textures_v is PackedInt32Array and texture_names_v is Array):
		return false
	var normals: PackedVector3Array = normals_v as PackedVector3Array
	var positions: PackedVector3Array = positions_v as PackedVector3Array
	var textures: PackedInt32Array = textures_v as PackedInt32Array
	var texture_names: Array = texture_names_v as Array
	var vertices: PackedVector3Array = PackedVector3Array()
	if md.has("vertices"):
		var vertices_v: Variant = md["vertices"]
		if vertices_v is PackedVector3Array:
			vertices = vertices_v as PackedVector3Array
	var count: int = mini(mini(normals.size(), positions.size()), textures.size())
	if count <= 0:
		return false

	var best_idx: int = -1
	var best_score: float = -1.0
	for i in range(count):
		var ti: int = textures[i]
		if ti < 0 or ti >= texture_names.size():
			continue
		var tex_name: String = String(texture_names[ti]).to_lower()
		if tex_name.find("portal") == -1:
			continue
		var n: Vector3 = normals[i].normalized()
		if n.length_squared() < 0.000001:
			continue
		var score: float = absf(n.dot(_portal_local_xform.basis.z.normalized()))
		if score > best_score:
			best_score = score
			best_idx = i
	if best_idx < 0:
		return false

	var world_normal: Vector3 = normals[best_idx].normalized()
	var world_center: Vector3 = positions[best_idx]
	if world_normal.length_squared() < 0.000001:
		return false

	var bounds: AABB = _compute_local_bounds()
	var local_center_world: Vector3 = global_transform.affine_inverse() * world_center
	var local_center_direct: Vector3 = world_center
	# FuncGodot face metadata is local to the generated node. Prefer direct-local,
	# only fallback to world->local if direct point is clearly out of bounds.
	var local_center: Vector3 = local_center_direct
	var direct_score: float = _point_in_bounds_score(bounds, local_center_direct)
	var world_score: float = _point_in_bounds_score(bounds, local_center_world)
	if direct_score < -0.25 and world_score > direct_score + 0.25:
		local_center = local_center_world

	var local_normal: Vector3 = world_normal.normalized()
	if local_normal.length_squared() < 0.000001:
		local_normal = (global_transform.basis.inverse() * world_normal).normalized()
	if reverse_normal:
		local_normal = -local_normal

	var up_ref: Vector3 = Vector3.UP
	if absf(up_ref.dot(local_normal)) > 0.98:
		up_ref = Vector3.FORWARD
	var y_axis: Vector3 = (up_ref - local_normal * up_ref.dot(local_normal)).normalized()
	if y_axis.length_squared() < 0.0001:
		y_axis = Vector3.UP
	var x_axis: Vector3 = y_axis.cross(local_normal).normalized()

	var half_size: Vector3 = bounds.size.abs() * 0.5
	var face_fit: Dictionary = _fit_portal_rect_from_face_triangles(
		textures, normals, positions, vertices, best_idx, local_normal, x_axis, y_axis
	)
	var fit_ok: bool = bool(face_fit.get("ok", false))
	if fit_ok:
		local_center = face_fit.get("center", local_center) as Vector3
		var fit_half: Vector2 = face_fit.get("half_extents", Vector2.ONE * 0.05) as Vector2
		_portal_half_extents = Vector2(maxf(fit_half.x, 0.05), maxf(fit_half.y, 0.05))
	else:
		_portal_half_extents = Vector2(
			maxf(_support_extent(half_size, x_axis), 0.05),
			maxf(_support_extent(half_size, y_axis), 0.05)
		)
	_portal_depth = maxf(_support_extent(half_size, local_normal) * 2.0, 0.01)
	_portal_local_xform = Transform3D(Basis(x_axis, y_axis, local_normal), local_center)
	_auto_use_opposite_face = false
	if portal_debug and _is_runtime_debug_enabled():
		Util.debug_print("[Portal DEBUG] %s metadata space select local_center=%s world_as_local=%s direct_local=%s local_normal=%s fit_ok=%s half=%s" % [
			name, str(local_center), str(local_center_world), str(local_center_direct), str(local_normal), str(fit_ok), str(_portal_half_extents)
		])
	return true


func _try_configure_portal_plane_from_exact_metadata(md: Dictionary) -> bool:
	var face_v: Variant = _dict_get_string_key(md, "portal_face", null)
	if not (face_v is Dictionary):
		return false
	var face: Dictionary = face_v as Dictionary
	var center_v: Variant = face.get("center", null)
	var normal_v: Variant = face.get("normal", null)
	var x_axis_v: Variant = face.get("x_axis", null)
	var y_axis_v: Variant = face.get("y_axis", null)
	var half_v: Variant = face.get("half_extents", null)
	if not (center_v is Vector3 and normal_v is Vector3 and x_axis_v is Vector3 and y_axis_v is Vector3 and half_v is Vector2):
		return false

	var local_center: Vector3 = center_v as Vector3
	var local_normal: Vector3 = (normal_v as Vector3).normalized()
	var x_axis: Vector3 = (x_axis_v as Vector3).normalized()
	var y_axis: Vector3 = (y_axis_v as Vector3).normalized()
	var half_extents: Vector2 = half_v as Vector2

	if local_normal.length_squared() < 0.000001:
		return false
	if reverse_normal:
		local_normal = -local_normal
		x_axis = -x_axis
	y_axis = (y_axis - local_normal * y_axis.dot(local_normal)).normalized()
	if y_axis.length_squared() < 0.000001:
		var up_ref: Vector3 = Vector3.UP
		if absf(up_ref.dot(local_normal)) > 0.98:
			up_ref = Vector3.FORWARD
		y_axis = (up_ref - local_normal * up_ref.dot(local_normal)).normalized()
	if y_axis.length_squared() < 0.000001:
		return false
	x_axis = y_axis.cross(local_normal).normalized()
	if x_axis.length_squared() < 0.000001:
		return false
	y_axis = local_normal.cross(x_axis).normalized()

	var half_size: Vector3 = _compute_local_bounds().size.abs() * 0.5
	_portal_local_xform = Transform3D(Basis(x_axis, y_axis, local_normal), local_center)
	_portal_half_extents = Vector2(maxf(half_extents.x, 0.05), maxf(half_extents.y, 0.05))
	_portal_depth = maxf(_support_extent(half_size, local_normal) * 2.0, 0.01)
	_auto_use_opposite_face = false
	if portal_debug and _is_runtime_debug_enabled():
		Util.debug_print("[Portal DEBUG] %s exact metadata local_center=%s local_normal=%s half=%s" % [
			name, str(local_center), str(local_normal), str(_portal_half_extents)
		])
	return true


func _dict_get_string_key(dict: Dictionary, key: String, default_value: Variant = null) -> Variant:
	if dict.has(key):
		return dict[key]
	var key_name: StringName = StringName(key)
	if dict.has(key_name):
		return dict[key_name]
	return default_value


func _point_in_bounds_score(bounds: AABB, p: Vector3) -> float:
	var size: Vector3 = bounds.size.abs()
	var expand: Vector3 = Vector3(maxf(size.x * 0.25, 0.2), maxf(size.y * 0.25, 0.2), maxf(size.z * 0.25, 0.05))
	var minp: Vector3 = bounds.position - expand
	var maxp: Vector3 = bounds.position + size + expand
	var clamped := Vector3(
		clampf(p.x, minp.x, maxp.x),
		clampf(p.y, minp.y, maxp.y),
		clampf(p.z, minp.z, maxp.z)
	)
	var dist: float = p.distance_to(clamped)
	# Higher is better; in-bounds gets 1.0, then drops with distance.
	return 1.0 - dist


func _fit_portal_rect_from_face_triangles(
	textures: PackedInt32Array,
	normals: PackedVector3Array,
	positions: PackedVector3Array,
	vertices: PackedVector3Array,
	best_idx: int,
	local_normal: Vector3,
	x_axis: Vector3,
	y_axis: Vector3
) -> Dictionary:
	if best_idx < 0 or best_idx >= textures.size() or best_idx >= positions.size():
		return {"ok": false}
	var target_texture: int = textures[best_idx]
	var plane_center: Vector3 = positions[best_idx]
	var plane_d: float = local_normal.dot(plane_center)
	var tri_count: int = mini(mini(textures.size(), normals.size()), positions.size())
	if tri_count <= 0:
		return {"ok": false}
	var has_vertices: bool = vertices.size() >= tri_count * 3
	var min_x: float = 1e20
	var max_x: float = -1e20
	var min_y: float = 1e20
	var max_y: float = -1e20
	var sum_w: float = 0.0
	var w_count: int = 0
	var accepted: int = 0
	var normal_dot_min: float = 0.995
	var plane_epsilon: float = 0.06
	for i in range(tri_count):
		if textures[i] != target_texture:
			continue
		var n: Vector3 = normals[i].normalized()
		if n.length_squared() < 0.000001:
			continue
		if absf(n.dot(local_normal)) < normal_dot_min:
			continue
		if absf(local_normal.dot(positions[i]) - plane_d) > plane_epsilon:
			continue
		if has_vertices:
			for k in range(3):
				var p: Vector3 = vertices[i * 3 + k]
				var px: float = x_axis.dot(p)
				var py: float = y_axis.dot(p)
				min_x = minf(min_x, px)
				max_x = maxf(max_x, px)
				min_y = minf(min_y, py)
				max_y = maxf(max_y, py)
				sum_w += local_normal.dot(p)
				w_count += 1
		else:
			var p2: Vector3 = positions[i]
			var px2: float = x_axis.dot(p2)
			var py2: float = y_axis.dot(p2)
			min_x = minf(min_x, px2)
			max_x = maxf(max_x, px2)
			min_y = minf(min_y, py2)
			max_y = maxf(max_y, py2)
			sum_w += local_normal.dot(p2)
			w_count += 1
		accepted += 1
	if accepted <= 0 or w_count <= 0:
		return {"ok": false}
	var half_x: float = (max_x - min_x) * 0.5
	var half_y: float = (max_y - min_y) * 0.5
	if half_x <= 0.001 or half_y <= 0.001:
		return {"ok": false}
	var mid_x: float = (min_x + max_x) * 0.5
	var mid_y: float = (min_y + max_y) * 0.5
	var mid_w: float = sum_w / float(w_count)
	var center: Vector3 = x_axis * mid_x + y_axis * mid_y + local_normal * mid_w
	return {
		"ok": true,
		"center": center,
		"half_extents": Vector2(half_x, half_y)
	}


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
		return _sanitize_portal_bounds(bounds)

	for n in find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var aabb := AABB()
		var have_shape_bounds := false
		if cs.shape.has_method("get_aabb"):
			var shape_aabb_v: Variant = cs.shape.call("get_aabb")
			if shape_aabb_v is AABB:
				aabb = _transform_aabb(shape_aabb_v as AABB, cs.transform)
				have_shape_bounds = true
		# ConcavePolygonShape3D has no get_aabb(); derive bounds from face points.
		if not have_shape_bounds and cs.shape.has_method("get_faces"):
			var faces_v: Variant = cs.shape.call("get_faces")
			if faces_v is PackedVector3Array:
				var faces: PackedVector3Array = faces_v as PackedVector3Array
				if faces.size() > 0:
					aabb = _aabb_from_points(faces, cs.transform)
					have_shape_bounds = true
		if not have_shape_bounds:
			continue
		if not has_any:
			bounds = aabb
			has_any = true
		else:
			bounds = bounds.merge(aabb)

	if has_any:
		return _sanitize_portal_bounds(bounds)

	return AABB(Vector3(-0.5, -1.0, -0.05), Vector3(1.0, 2.0, 0.1))


func _sanitize_portal_bounds(bounds: AABB) -> AABB:
	var b := bounds
	# Keep a minimum usable portal size so tiny/degenerate bounds don't create a sliver.
	var min_extent := Vector3(0.5, 0.5, 0.02)
	var size := b.size.abs()
	if size.x < min_extent.x:
		var c := b.position.x + size.x * 0.5
		b.position.x = c - min_extent.x * 0.5
		size.x = min_extent.x
	if size.y < min_extent.y:
		var c := b.position.y + size.y * 0.5
		b.position.y = c - min_extent.y * 0.5
		size.y = min_extent.y
	if size.z < min_extent.z:
		var c := b.position.z + size.z * 0.5
		b.position.z = c - min_extent.z * 0.5
		size.z = min_extent.z
	b.size = size
	return b


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
		var wp: Vector3 = xform * p
		if not has_any:
			out = AABB(wp, Vector3.ZERO)
			has_any = true
		else:
			out = out.expand(wp)
	return out


func _aabb_from_points(points: PackedVector3Array, xform: Transform3D) -> AABB:
	var out := AABB()
	var has_any := false
	for p in points:
		var wp: Vector3 = xform * p
		if not has_any:
			out = AABB(wp, Vector3.ZERO)
			has_any = true
		else:
			out = out.expand(wp)
	return out


func _configure_portal_plane_from_bounds(bounds: AABB) -> void:
	var size: Vector3 = bounds.size.abs()
	var center: Vector3 = bounds.position + size * 0.5
	var half_size: Vector3 = size * 0.5

	var axis: int = _resolve_axis_override()
	if axis == -1:
		axis = 0
		if size.y <= size.x and size.y <= size.z:
			axis = 1
		elif size.z <= size.x and size.z <= size.y:
			axis = 2

	var axis_sign: float = _resolve_axis_sign()
	if reverse_normal:
		axis_sign *= -1.0

	var z_axis: Vector3 = Vector3.ZERO
	match axis:
		0:
			z_axis = Vector3(axis_sign, 0.0, 0.0)
		1:
			z_axis = Vector3(0.0, axis_sign, 0.0)
		_:
			z_axis = Vector3(0.0, 0.0, axis_sign)

	# Build a stable in-plane frame: keep portal "up" close to world up.
	var up_ref: Vector3 = Vector3.UP
	if absf(up_ref.dot(z_axis)) > 0.98:
		up_ref = Vector3.FORWARD
	var y_axis: Vector3 = (up_ref - z_axis * up_ref.dot(z_axis)).normalized()
	if y_axis.length_squared() < 0.0001:
		y_axis = Vector3.UP
	var x_axis: Vector3 = y_axis.cross(z_axis).normalized()

	var half_x: float = maxf(_support_extent(half_size, x_axis), 0.05)
	var half_y: float = maxf(_support_extent(half_size, y_axis), 0.05)
	var half_depth: float = maxf(_support_extent(half_size, z_axis), 0.005)

	_portal_half_extents = Vector2(half_x, half_y)
	_portal_depth = maxf(half_depth * 2.0, 0.01)
	var face_offset: float = maxf(half_depth - 0.005, 0.0)
	var origin: Vector3 = center + z_axis * face_offset
	var basis: Basis = Basis(x_axis, y_axis, z_axis)
	_portal_local_xform = Transform3D(basis, origin)


func _resolve_axis_override() -> int:
	match portal_axis:
		"x", "-x":
			return 0
		"y", "-y":
			return 1
		"z", "-z":
			return 2
		_:
			return -1


func _resolve_axis_sign() -> float:
	if portal_axis.begins_with("-"):
		return -1.0
	return 1.0


func _support_extent(half_size: Vector3, dir: Vector3) -> float:
	var ad: Vector3 = Vector3(absf(dir.x), absf(dir.y), absf(dir.z))
	return half_size.x * ad.x + half_size.y * ad.y + half_size.z * ad.z


func _apply_window_projection(z_near: float) -> bool:
	if _portal_camera == null or _linked_portal == null or _viewport == null:
		return false
	var corners: Array[Vector3] = _linked_portal._get_portal_corners_world()
	if corners.is_empty():
		return false
	var cam_inv: Transform3D = _portal_camera.global_transform.affine_inverse()
	var min_u: float = 1e20
	var max_u: float = -1e20
	var min_v: float = 1e20
	var max_v: float = -1e20
	var z_gate: float = maxf(z_near * 0.25, 0.002)
	for i in corners.size():
		var cw: Vector3 = corners[i]
		var c: Vector3 = cam_inv * cw
		# If a projected corner is at/behind camera, avoid clamp-based projection because
		# it causes severe close-angle warping. Keep prior stable frustum instead.
		if c.z > -z_gate:
			return false
		var iz: float = z_near / -c.z
		var u: float = c.x * iz
		var v: float = c.y * iz
		min_u = minf(min_u, u)
		max_u = maxf(max_u, u)
		min_v = minf(min_v, v)
		max_v = maxf(max_v, v)
	var full_w: float = max_u - min_u
	var full_h: float = max_v - min_v
	if full_w <= 0.00001 or full_h <= 0.00001:
		return false
	var aspect: float = float(_viewport.size.x) / maxf(float(_viewport.size.y), 1.0)
	var need_h: float = maxf(full_h, full_w / maxf(aspect, 0.001))
	var offset: Vector2 = Vector2((min_u + max_u) * 0.5, (min_v + max_v) * 0.5)
	var left: float = min_u
	var right: float = max_u
	var bottom: float = min_v
	var top: float = max_v
	if _apply_offaxis_projection(left, right, bottom, top, z_near, _portal_camera.far):
		_stable_frustum_size = need_h
		_stable_frustum_offset = offset
		_has_stable_window_projection = true
		return true
	if render_use_oblique_clip and _apply_oblique_clip_projection(left, right, bottom, top, z_near, _portal_camera.far):
		_stable_frustum_size = need_h
		_stable_frustum_offset = offset
		_has_stable_window_projection = true
		return true
	_portal_camera.set_frustum(need_h, offset, z_near, _portal_camera.far)
	_portal_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_stable_frustum_size = need_h
	_stable_frustum_offset = offset
	_has_stable_window_projection = true
	return true


func _apply_offaxis_projection(left: float, right: float, bottom: float, top: float, z_near: float, z_far: float) -> bool:
	if _portal_camera == null:
		return false
	if not _is_custom_projection_api_available():
		return false
	var proj: Projection = Projection.create_frustum(left, right, bottom, top, z_near, z_far)
	_portal_camera.call("set_custom_projection", proj)
	_portal_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	return true


func _apply_oblique_clip_projection(left: float, right: float, bottom: float, top: float, z_near: float, z_far: float) -> bool:
	if _portal_camera == null or _linked_portal == null:
		return false
	if not _is_oblique_projection_api_available():
		return false
	var clip_plane_cam: Vector4 = _compute_link_clip_plane_camera_space()
	if clip_plane_cam == Vector4.ZERO:
		return false
	var base_proj: Projection = Projection.create_frustum(left, right, bottom, top, z_near, z_far)
	var inv_proj: Projection = base_proj.inverse()
	var q: Vector4 = inv_proj * Vector4(_sign_nonzero(clip_plane_cam.x), _sign_nonzero(clip_plane_cam.y), 1.0, 1.0)
	var denom: float = clip_plane_cam.dot(q)
	if absf(denom) < 0.000001:
		return false
	var c: Vector4 = clip_plane_cam * (2.0 / denom)
	var out_proj: Projection = base_proj
	var x_col: Vector4 = out_proj.x
	var y_col: Vector4 = out_proj.y
	var z_col: Vector4 = out_proj.z
	var w_col: Vector4 = out_proj.w
	x_col.z = c.x - x_col.w
	y_col.z = c.y - y_col.w
	z_col.z = c.z - z_col.w
	w_col.z = c.w - w_col.w
	out_proj.x = x_col
	out_proj.y = y_col
	out_proj.z = z_col
	out_proj.w = w_col
	var applied: bool = false
	if _portal_camera.has_method("set_custom_projection"):
		_portal_camera.call("set_custom_projection", out_proj)
		applied = true
	if applied:
		_portal_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	return applied


func _compute_link_clip_plane_camera_space() -> Vector4:
	if _portal_camera == null or _linked_portal == null:
		return Vector4.ZERO
	var dst_xf: Transform3D = _linked_portal._get_portal_global_transform()
	var n_world: Vector3 = dst_xf.basis.z.normalized()
	var p_world: Vector3 = dst_xf.origin
	var cam_inv: Transform3D = _portal_camera.global_transform.affine_inverse()
	var n_cam: Vector3 = (cam_inv.basis * n_world).normalized()
	var p_cam: Vector3 = cam_inv * p_world
	var d: float = -n_cam.dot(p_cam)
	var keep_world: Vector3 = p_world - n_world * 0.05
	var keep_cam: Vector3 = cam_inv * keep_world
	var keep_side: float = n_cam.dot(keep_cam) + d
	if keep_side < 0.0:
		n_cam = -n_cam
		d = -d
	return Vector4(n_cam.x, n_cam.y, n_cam.z, d)


func _sign_nonzero(v: float) -> float:
	return -1.0 if v < 0.0 else 1.0


func _is_oblique_projection_api_available() -> bool:
	if _oblique_api_checked:
		if render_use_oblique_clip and portal_debug and _is_runtime_debug_enabled() and not _oblique_api_available and not _oblique_unavailable_logged:
			_oblique_unavailable_logged = true
			Util.debug_print("[Portal DEBUG] %s oblique clip API unavailable; using frustum fallback." % [name])
		return _oblique_api_available
	_oblique_api_checked = true
	_oblique_api_available = _portal_camera != null and _portal_camera.has_method("set_custom_projection")
	if render_use_oblique_clip and portal_debug and _is_runtime_debug_enabled() and not _oblique_api_available and not _oblique_unavailable_logged:
		_oblique_unavailable_logged = true
		Util.debug_print("[Portal DEBUG] %s oblique clip API unavailable; using frustum fallback." % [name])
	return _oblique_api_available


func _reset_custom_projection() -> void:
	if _portal_camera == null:
		return
	if _portal_camera.has_method("clear_custom_projection"):
		_portal_camera.call("clear_custom_projection")


func _is_custom_projection_api_available() -> bool:
	if _custom_proj_api_checked:
		return _custom_proj_api_available
	_custom_proj_api_checked = true
	_custom_proj_api_available = _portal_camera != null and _portal_camera.has_method("set_custom_projection")
	return _custom_proj_api_available


func _is_runtime_debug_enabled() -> bool:
	var dbg := get_node_or_null("/root/DEBUG")
	if dbg != null and dbg.has_method("is_runtime_debug_enabled"):
		return bool(dbg.call("is_runtime_debug_enabled"))
	return false


func _get_portal_corners_world() -> Array[Vector3]:
	var xf: Transform3D = _get_portal_global_transform()
	var hx: float = _portal_half_extents.x
	var hy: float = _portal_half_extents.y
	var right: Vector3 = xf.basis.x
	var up: Vector3 = xf.basis.y
	var c: Vector3 = xf.origin
	return [
		c + right * -hx + up * -hy,
		c + right * hx + up * -hy,
		c + right * hx + up * hy,
		c + right * -hx + up * hy
	]

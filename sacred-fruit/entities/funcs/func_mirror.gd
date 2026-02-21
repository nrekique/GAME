@tool
class_name FuncMirror
extends StaticBody3D

@export var enabled: bool = true
@export var mirror_axis: String = "auto"
@export var mirror_debug: bool = false
@export var mirror_face_from_texture: bool = true
@export var mirror_flip_u: bool = false
@export var use_plugin_mirror: bool = true
@export var mirror_tint: Color = Color(0.9, 0.97, 0.94, 1.0)
@export_range(0.0, 30.0, 0.01) var mirror_distortion: float = 0.0
@export var mirror_distortion_texture: Texture2D
@export_range(0.25, 1.0, 0.05) var render_scale: float = 0.60
@export var render_use_window_projection: bool = true
@export var render_use_oblique_clip: bool = false
@export_range(-0.05, 0.05, 0.001) var render_camera_offset: float = 0.0
@export var render_cull_exclude_layers: PackedInt32Array = PackedInt32Array()
@export var manager_enable_budgeting: bool = true
@export_range(1, 64, 1) var manager_max_active_mirrors: int = 2
@export_range(0.02, 0.5, 0.01) var manager_refresh_seconds: float = 0.08
@export_range(0.0, 4.0, 0.01) var manager_min_runtime_priority: float = 0.0
@export var manager_require_visible_in_frustum: bool = true
@export var manager_require_line_of_sight: bool = true
@export var plugin_dynamic_resolution: bool = true
@export_range(32, 1024, 1) var plugin_min_resolution_per_unit: int = 96
@export_range(32, 2048, 1) var plugin_max_resolution_per_unit: int = 512
@export_range(32, 1024, 1) var plugin_base_resolution_per_unit: int = 96
@export_range(0.1, 8.0, 0.05) var plugin_resolution_near_distance: float = 1.0
@export_range(1.0, 8.0, 0.05) var plugin_max_resolution_boost: float = 3.0
@export var reverse_normal: bool = false
@export var mirror_allow_legacy_face_fit: bool = false

const DEBUG_PRINT_INTERVAL := 5.0
const MIRROR_SURFACE_RENDER_LAYER := 19
const MIRROR_SURFACE_LAYER_MASK := 1 << (MIRROR_SURFACE_RENDER_LAYER - 1)
const PLUGIN_MIRROR_LAYER_INDEX := 2
const MIRROR_RUNTIME_MANAGER_SCRIPT := preload("res://entities/funcs/mirror_runtime_manager.gd")
const MIRROR_RUNTIME_MANAGER_NAME := "MirrorRuntimeManager"

var _viewport: SubViewport
var _mirror_camera: Camera3D
var _surface: MeshInstance3D
var _surface_material: ShaderMaterial
var _plugin_mirror: Node3D
var _mirror_local_xform: Transform3D = Transform3D.IDENTITY
var _mirror_half_extents: Vector2 = Vector2.ONE * 0.5
var _mirror_depth: float = 0.1
var _debug_accum: float = 0.0
var _render_ok: bool = false
var _has_stable_window_projection: bool = false
var _stable_frustum_size: float = 1.0
var _stable_frustum_offset: Vector2 = Vector2.ZERO
var _stable_custom_projection_valid: bool = false
var _stable_custom_projection: Projection = Projection()
var _custom_proj_api_checked: bool = false
var _custom_proj_api_available: bool = false
var _metadata_retry_pending: bool = false
var _used_metadata_plane: bool = false
var _metadata_warning_emitted: bool = false
var _mirror_runtime_manager: Node = null
var _managed_mirror_active: bool = true
var _last_plugin_resolution_per_unit: int = -1
var _last_plugin_cull_signature: String = ""
var _last_plugin_tint: Color = Color(-1.0, -1.0, -1.0, -1.0)
var _last_plugin_distortion: float = -1.0
var _last_plugin_distortion_tex_id: int = -1

const MIRROR_SURFACE_SHADER := "
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D mirror_tex : source_color;
uniform bool mirror_valid = false;
uniform bool mirror_flip_u = true;
uniform vec3 mirror_tint = vec3(0.9, 0.97, 0.94);
uniform sampler2D distort_tex : source_color;
uniform float distort_strength = 0.0;
uniform bool distort_enabled = false;
void fragment() {
	if (mirror_valid) {
		// Mirror texture must be sampled in mesh UV-space.
		// SCREEN_UV causes a screen-projected look (window-like drift).
		vec2 uv = UV;
		if (distort_enabled && distort_strength > 0.0001) {
			vec2 d = texture(distort_tex, uv).rg * 2.0 - 1.0;
			uv += d * (distort_strength * 0.03);
		}
		if (mirror_flip_u) {
			uv.x = 1.0 - uv.x;
		}
		ALBEDO = texture(mirror_tex, uv).rgb * mirror_tint;
	} else {
		ALBEDO = vec3(0.12, 0.12, 0.12);
	}
}
"


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
	if props.has("enabled"):
		enabled = _to_bool(props["enabled"], enabled)
	if props.has("mirror_axis"):
		mirror_axis = String(props["mirror_axis"]).strip_edges().to_lower()
	if props.has("mirror_debug"):
		mirror_debug = _to_bool(props["mirror_debug"], mirror_debug)
	if props.has("mirror_face_from_texture"):
		mirror_face_from_texture = _to_bool(props["mirror_face_from_texture"], mirror_face_from_texture)
	if props.has("mirror_flip_u"):
		mirror_flip_u = _to_bool(props["mirror_flip_u"], mirror_flip_u)
	if props.has("use_plugin_mirror"):
		use_plugin_mirror = _to_bool(props["use_plugin_mirror"], use_plugin_mirror)
	if props.has("mirror_tint"):
		mirror_tint = _to_color(props["mirror_tint"], mirror_tint)
	if props.has("mirror_distortion"):
		mirror_distortion = clampf(float(props["mirror_distortion"]), 0.0, 30.0)
	if props.has("mirror_distortion_texture"):
		var tex_v: Variant = props["mirror_distortion_texture"]
		if tex_v is Texture2D:
			mirror_distortion_texture = tex_v as Texture2D
		else:
			var tex_path: String = String(tex_v).strip_edges()
			if tex_path != "":
				var loaded: Resource = load(tex_path)
				if loaded is Texture2D:
					mirror_distortion_texture = loaded as Texture2D
	if props.has("render_scale"):
		render_scale = clampf(float(props["render_scale"]), 0.25, 1.0)
	if props.has("render_use_window_projection"):
		render_use_window_projection = _to_bool(props["render_use_window_projection"], render_use_window_projection)
	if props.has("render_use_oblique_clip"):
		render_use_oblique_clip = _to_bool(props["render_use_oblique_clip"], render_use_oblique_clip)
	if props.has("render_camera_offset"):
		render_camera_offset = clampf(float(props["render_camera_offset"]), -0.05, 0.05)
	if props.has("render_cull_exclude_layers"):
		render_cull_exclude_layers = _parse_layer_list(props["render_cull_exclude_layers"])
	if props.has("manager_enable_budgeting"):
		manager_enable_budgeting = _to_bool(props["manager_enable_budgeting"], manager_enable_budgeting)
	if props.has("manager_max_active_mirrors"):
		manager_max_active_mirrors = maxi(1, int(props["manager_max_active_mirrors"]))
	if props.has("manager_refresh_seconds"):
		manager_refresh_seconds = clampf(float(props["manager_refresh_seconds"]), 0.02, 0.5)
	if props.has("manager_min_runtime_priority"):
		manager_min_runtime_priority = clampf(float(props["manager_min_runtime_priority"]), 0.0, 4.0)
	if props.has("manager_require_visible_in_frustum"):
		manager_require_visible_in_frustum = _to_bool(props["manager_require_visible_in_frustum"], manager_require_visible_in_frustum)
	if props.has("manager_require_line_of_sight"):
		manager_require_line_of_sight = _to_bool(props["manager_require_line_of_sight"], manager_require_line_of_sight)
	if props.has("reverse_normal"):
		reverse_normal = _to_bool(props["reverse_normal"], reverse_normal)
	_on_properties_applied()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("func_mirror")
	_register_mirror_runtime_manager()
	if use_plugin_mirror:
		_configure_mirror_plane()
		if mirror_face_from_texture and not _used_metadata_plane:
			_configure_mirror_plane_from_bounds(_compute_local_bounds())
		_hide_source_mesh_children()
		_setup_plugin_mirror()
		return
	_build_mirror_surface()
	_setup_mirror_viewport()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_unregister_mirror_runtime_manager()
	if _plugin_mirror != null and is_instance_valid(_plugin_mirror):
		_plugin_mirror.queue_free()
	_plugin_mirror = null
	if _surface_material != null:
		_surface_material.set_shader_parameter("mirror_valid", false)
		_surface_material.set_shader_parameter("mirror_tex", null)
	if _surface != null:
		_surface.material_override = null
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_viewport.world_3d = null
		if is_instance_valid(_viewport):
			_viewport.free()
	_viewport = null
	_mirror_camera = null


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if use_plugin_mirror:
		_apply_mirror_runtime_budget()
		if not enabled:
			if _plugin_mirror != null and is_instance_valid(_plugin_mirror):
				_plugin_mirror.visible = false
			return
		if manager_enable_budgeting and not _managed_mirror_active:
			return
		if _plugin_mirror == null or not is_instance_valid(_plugin_mirror):
			_setup_plugin_mirror()
		_sync_plugin_mirror()
		_debug_tick(delta)
		return
	_apply_mirror_runtime_budget()
	if manager_enable_budgeting and not _managed_mirror_active:
		if _surface != null:
			_surface.visible = false
		return
	if not enabled:
		if _surface != null:
			_surface.visible = false
		return
	_sync_viewport_world()
	_update_viewport_size()
	_update_mirror_camera()
	_update_surface_state()
	_debug_tick(delta)


func _on_properties_applied() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	_register_mirror_runtime_manager()
	if use_plugin_mirror:
		_configure_mirror_plane()
		if mirror_face_from_texture and not _used_metadata_plane:
			_configure_mirror_plane_from_bounds(_compute_local_bounds())
		_hide_source_mesh_children()
		_setup_plugin_mirror()
		_sync_plugin_mirror()
		return
	# During FuncGodot startup, properties can apply before face metadata is attached.
	# Defer mirror-surface rebuild to _ready in that case to avoid false fallback warnings.
	if _surface == null and not has_meta("func_godot_mesh_data"):
		return
	_has_stable_window_projection = false
	_stable_custom_projection_valid = false
	_used_metadata_plane = false
	_metadata_warning_emitted = false
	_hide_source_mesh_children()
	_build_mirror_surface()
	_setup_mirror_viewport()
	_update_surface_state()


func _build_mirror_surface() -> void:
	_configure_mirror_plane()
	_hide_source_mesh_children()
	if _surface == null:
		_surface = MeshInstance3D.new()
		_surface.name = "MirrorSurface"
		_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_surface)
	_surface.layers = MIRROR_SURFACE_LAYER_MASK
	var quad := QuadMesh.new()
	quad.size = _mirror_half_extents * 2.0
	_surface.mesh = quad
	_surface.transform = _mirror_local_xform
	if _surface_material == null:
		var shader := Shader.new()
		shader.code = MIRROR_SURFACE_SHADER
		_surface_material = ShaderMaterial.new()
		_surface_material.shader = shader
	_surface.material_override = _surface_material


func _setup_mirror_viewport() -> void:
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "MirrorViewport"
		_viewport.disable_3d = false
		_viewport.transparent_bg = false
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport)
	_sync_viewport_world()
	if _mirror_camera == null:
		_mirror_camera = Camera3D.new()
		_mirror_camera.name = "MirrorCamera"
		_viewport.add_child(_mirror_camera)
	_mirror_camera.current = true
	_update_viewport_size()
	if _surface_material != null:
		_surface_material.set_shader_parameter("mirror_tex", _viewport.get_texture())
		_surface_material.set_shader_parameter("mirror_valid", true)
		_surface_material.set_shader_parameter("mirror_flip_u", mirror_flip_u)
		_surface_material.set_shader_parameter("mirror_tint", mirror_tint)
		_surface_material.set_shader_parameter("distort_tex", mirror_distortion_texture)
		_surface_material.set_shader_parameter("distort_strength", mirror_distortion)
		_surface_material.set_shader_parameter("distort_enabled", mirror_distortion_texture != null)


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
	var mirror_aspect: float = maxf(_mirror_half_extents.x / maxf(_mirror_half_extents.y, 0.001), 0.05)
	var w: int = int(round(max_w))
	var h: int = int(round(float(w) / mirror_aspect))
	if h > int(round(max_h)):
		h = int(round(max_h))
		w = int(round(float(h) * mirror_aspect))
	w = maxi(64, w)
	h = maxi(64, h)
	var wanted: Vector2i = Vector2i(w, h)
	if _viewport.size != wanted:
		_viewport.size = wanted


func _update_mirror_camera() -> void:
	if _mirror_camera == null:
		return
	if mirror_face_from_texture and not _used_metadata_plane:
		return
	var src_cam: Camera3D = get_viewport().get_camera_3d()
	if src_cam == null:
		return
	var mirror_xf: Transform3D = _get_mirror_global_transform()
	var normal: Vector3 = mirror_xf.basis.z.normalized()
	var plane_point: Vector3 = mirror_xf.origin
	var src_xf: Transform3D = src_cam.global_transform
	# Strict plane reflection transform.
	var reflected_origin: Vector3 = _reflect_point(src_xf.origin, plane_point, normal)
	var reflected_x: Vector3 = _reflect_direction(src_xf.basis.x.normalized(), normal).normalized()
	var reflected_y: Vector3 = _reflect_direction(src_xf.basis.y.normalized(), normal).normalized()
	var reflected_z: Vector3 = _reflect_direction(src_xf.basis.z.normalized(), normal).normalized()
	# Reflection produces a left-handed frame. Flip one axis to restore right-handed basis
	# while preserving mirrored forward direction.
	var x_axis: Vector3 = -reflected_x
	var y_axis: Vector3 = reflected_y
	var z_axis: Vector3 = reflected_z
	# Re-orthonormalize to remove numeric drift.
	z_axis = z_axis.normalized()
	y_axis = (y_axis - z_axis * y_axis.dot(z_axis)).normalized()
	if y_axis.length_squared() < 0.000001:
		y_axis = Vector3.UP
		if absf(y_axis.dot(z_axis)) > 0.98:
			y_axis = Vector3.FORWARD
		y_axis = (y_axis - z_axis * y_axis.dot(z_axis)).normalized()
	x_axis = y_axis.cross(z_axis).normalized()
	if x_axis.length_squared() < 0.000001:
		var fallback_up: Vector3 = Vector3.UP
		if absf(fallback_up.dot(z_axis)) > 0.98:
			fallback_up = Vector3.FORWARD
		x_axis = fallback_up.cross(z_axis).normalized()
		y_axis = z_axis.cross(x_axis).normalized()
	reflected_origin += normal * render_camera_offset
	_mirror_camera.global_transform = Transform3D(Basis(x_axis, y_axis, z_axis), reflected_origin)
	_mirror_camera.fov = src_cam.fov
	_mirror_camera.near = maxf(0.005, src_cam.near)
	_mirror_camera.far = src_cam.far
	_mirror_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var src_mask: int = src_cam.cull_mask
	var filtered_mask: int = src_mask & ~MIRROR_SURFACE_LAYER_MASK
	for layer_num in render_cull_exclude_layers:
		if layer_num >= 1 and layer_num <= 32:
			filtered_mask &= ~(1 << (layer_num - 1))
	_mirror_camera.cull_mask = filtered_mask if filtered_mask != 0 else src_mask
	_mirror_camera.environment = src_cam.environment
	_mirror_camera.attributes = src_cam.attributes
	_reset_custom_projection()
	if render_use_window_projection:
		if not _apply_window_projection(_mirror_camera.near):
			# Mirror path must never reuse stale cached frustum state from prior frames.
			_mirror_camera.set_perspective(src_cam.fov, _mirror_camera.near, src_cam.far)
	else:
		_mirror_camera.set_perspective(src_cam.fov, _mirror_camera.near, src_cam.far)


func _update_surface_state() -> void:
	_render_ok = _is_render_ready()
	if _surface == null:
		return
	if mirror_face_from_texture and not _used_metadata_plane:
		_surface.visible = false
	else:
		_surface.visible = enabled
	if _surface_material == null:
		return
	if _render_ok:
		_surface_material.set_shader_parameter("mirror_tex", _viewport.get_texture())
		_surface_material.set_shader_parameter("mirror_valid", true)
		_surface_material.set_shader_parameter("mirror_flip_u", mirror_flip_u)
		_surface_material.set_shader_parameter("mirror_tint", mirror_tint)
		_surface_material.set_shader_parameter("distort_tex", mirror_distortion_texture)
		_surface_material.set_shader_parameter("distort_strength", mirror_distortion)
		_surface_material.set_shader_parameter("distort_enabled", mirror_distortion_texture != null)
	else:
		_surface_material.set_shader_parameter("mirror_valid", false)


func _is_render_ready() -> bool:
	if _viewport == null or _mirror_camera == null:
		return false
	if mirror_face_from_texture and not _used_metadata_plane:
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
	if not mirror_debug or not _is_runtime_debug_enabled():
		return
	_debug_accum += delta
	if _debug_accum < DEBUG_PRINT_INTERVAL:
		return
	_debug_accum = 0.0
	var vp_size: Vector2i = Vector2i.ZERO if _viewport == null else _viewport.size
	var has_world: bool = (_viewport != null and _viewport.world_3d != null)
	var has_cam: bool = (_mirror_camera != null and _mirror_camera.is_inside_tree())
	var has_tex: bool = (_viewport != null and _viewport.get_texture() != null)
	var surf_vis: bool = (_surface != null and _surface.visible)
	var m_xf: Transform3D = _get_mirror_global_transform()
	print("[Mirror DEBUG] %s render_ok=%s visible=%s vp=%s world=%s cam=%s tex=%s axis=%s normal=%s origin=%s" % [
		name, str(_render_ok), str(surf_vis), str(vp_size), str(has_world), str(has_cam), str(has_tex), mirror_axis,
		str(m_xf.basis.z.normalized()), str(m_xf.origin)
	])


func _is_runtime_debug_enabled() -> bool:
	var dbg := get_node_or_null("/root/DEBUG")
	if dbg != null and dbg.has_method("is_runtime_debug_enabled"):
		return bool(dbg.call("is_runtime_debug_enabled"))
	return false


func _reflect_point(p: Vector3, plane_point: Vector3, plane_normal: Vector3) -> Vector3:
	var n: Vector3 = plane_normal.normalized()
	return p - (2.0 * n.dot(p - plane_point)) * n


func _reflect_direction(d: Vector3, plane_normal: Vector3) -> Vector3:
	var n: Vector3 = plane_normal.normalized()
	return d - (2.0 * n.dot(d)) * n


func _get_mirror_global_transform() -> Transform3D:
	return global_transform * _mirror_local_xform


func _apply_window_projection(z_near: float) -> bool:
	if _mirror_camera == null or _viewport == null:
		return false
	var corners: Array[Vector3] = _get_mirror_corners_world()
	if corners.is_empty():
		return false
	var cam_inv: Transform3D = _mirror_camera.global_transform.affine_inverse()
	var min_u: float = 1e20
	var max_u: float = -1e20
	var min_v: float = 1e20
	var max_v: float = -1e20
	var z_gate: float = maxf(z_near * 0.25, 0.002)
	for i in corners.size():
		var c: Vector3 = cam_inv * corners[i]
		if c.z > -z_gate:
			# Strict path: reject frame instead of reusing stale window frustum.
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
	var base_proj: Projection = Projection.create_frustum(left, right, bottom, top, z_near, _mirror_camera.far)
	if render_use_oblique_clip:
		var clipped: Projection = _build_oblique_clip_projection(base_proj)
		if clipped == Projection():
			return false
		return _set_projection(clipped)
	return _set_projection(base_proj)


func _set_projection(proj: Projection) -> bool:
	if _mirror_camera == null:
		return false
	if _is_custom_projection_api_available():
		_mirror_camera.call("set_custom_projection", proj)
		_mirror_camera.keep_aspect = Camera3D.KEEP_HEIGHT
		_stable_custom_projection = proj
		_stable_custom_projection_valid = true
		return true
	# Fallback without custom projection API: this is still computed per-frame and never cached.
	var x_col: Vector4 = proj.x
	var y_col: Vector4 = proj.y
	var z_col: Vector4 = proj.z
	var inv_x_scale: float = 1.0 / maxf(absf(x_col.x), 0.000001)
	var inv_y_scale: float = 1.0 / maxf(absf(y_col.y), 0.000001)
	var frustum_size: float = 2.0 * _mirror_camera.near * inv_y_scale
	var frustum_offset: Vector2 = Vector2(x_col.z * _mirror_camera.near * inv_x_scale, y_col.z * _mirror_camera.near * inv_y_scale)
	_mirror_camera.set_frustum(frustum_size, frustum_offset, _mirror_camera.near, _mirror_camera.far)
	_mirror_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	return true


func _is_custom_projection_api_available() -> bool:
	if _custom_proj_api_checked:
		return _custom_proj_api_available
	_custom_proj_api_checked = true
	_custom_proj_api_available = _mirror_camera != null and _mirror_camera.has_method("set_custom_projection")
	return _custom_proj_api_available


func _reset_custom_projection() -> void:
	if _mirror_camera == null:
		return
	if _mirror_camera.has_method("clear_custom_projection"):
		_mirror_camera.call("clear_custom_projection")


func _build_oblique_clip_projection(base_proj: Projection) -> Projection:
	if _mirror_camera == null:
		return Projection()
	var clip_plane_cam: Vector4 = _compute_mirror_clip_plane_camera_space()
	if clip_plane_cam == Vector4.ZERO:
		return Projection()
	var inv_proj: Projection = base_proj.inverse()
	var q: Vector4 = inv_proj * Vector4(_sign_nonzero(clip_plane_cam.x), _sign_nonzero(clip_plane_cam.y), 1.0, 1.0)
	var denom: float = clip_plane_cam.dot(q)
	if absf(denom) < 0.000001:
		return Projection()
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
	return out_proj


func _compute_mirror_clip_plane_camera_space() -> Vector4:
	if _mirror_camera == null:
		return Vector4.ZERO
	var mirror_xf: Transform3D = _get_mirror_global_transform()
	var n_world: Vector3 = mirror_xf.basis.z.normalized()
	var p_world: Vector3 = mirror_xf.origin
	# Deterministic clip side: orient plane normal toward the reflected camera.
	var cam_world: Vector3 = _mirror_camera.global_transform.origin
	if n_world.dot(cam_world - p_world) < 0.0:
		n_world = -n_world
	var cam_inv: Transform3D = _mirror_camera.global_transform.affine_inverse()
	var n_cam: Vector3 = (cam_inv.basis * n_world).normalized()
	var p_cam: Vector3 = cam_inv * p_world
	var d: float = -n_cam.dot(p_cam)
	# Fixed plane convention: no per-frame side probing/flip heuristics.
	return Vector4(n_cam.x, n_cam.y, n_cam.z, d)


func _sign_nonzero(v: float) -> float:
	return -1.0 if v < 0.0 else 1.0


func _to_color(value: Variant, default_value: Color) -> Color:
	if value is Color:
		return value as Color
	var s: String = String(value).strip_edges()
	if s == "":
		return default_value
	if s.begins_with("#"):
		return Color.from_string(s, default_value)
	var tokens: PackedStringArray = s.replace(",", " ").split(" ", false)
	if tokens.size() >= 3:
		var a: float = default_value.a
		if tokens.size() >= 4:
			a = tokens[3].to_float()
		return Color(tokens[0].to_float(), tokens[1].to_float(), tokens[2].to_float(), a)
	return default_value


func _parse_layer_list(value: Variant) -> PackedInt32Array:
	if value is PackedInt32Array:
		return value as PackedInt32Array
	var out: PackedInt32Array = PackedInt32Array()
	if value is Array:
		var arr: Array = value as Array
		for item in arr:
			var n: int = int(item)
			if n >= 1 and n <= 32:
				out.append(n)
		return out
	var text: String = String(value).strip_edges()
	if text == "":
		return out
	var tokens: PackedStringArray = text.replace(",", " ").split(" ", false)
	for token in tokens:
		var n2: int = token.to_int()
		if n2 >= 1 and n2 <= 32:
			out.append(n2)
	return out


func _register_mirror_runtime_manager() -> void:
	if Engine.is_editor_hint() or not manager_enable_budgeting:
		return
	if _mirror_runtime_manager == null:
		var existing: Node = get_node_or_null("/root/%s" % MIRROR_RUNTIME_MANAGER_NAME)
		if existing != null and existing.has_method("register_mirror"):
			_mirror_runtime_manager = existing
		else:
			var mgr: Node = MIRROR_RUNTIME_MANAGER_SCRIPT.new()
			mgr.name = MIRROR_RUNTIME_MANAGER_NAME
			get_tree().root.add_child(mgr)
			_mirror_runtime_manager = mgr
	if _mirror_runtime_manager != null:
		_mirror_runtime_manager.call("register_mirror", self, manager_max_active_mirrors, manager_refresh_seconds, manager_min_runtime_priority)


func _unregister_mirror_runtime_manager() -> void:
	if _mirror_runtime_manager == null:
		return
	if is_instance_valid(_mirror_runtime_manager):
		_mirror_runtime_manager.call("unregister_mirror", self)
	_mirror_runtime_manager = null


func mirror_runtime_priority(cam: Camera3D) -> float:
	if cam == null or not enabled:
		return -1.0e20
	if not use_plugin_mirror:
		return -1.0e20
	if manager_require_visible_in_frustum and not _is_mirror_visible_from_camera(cam):
		return -1.0e20
	if manager_require_line_of_sight and not _has_mirror_line_of_sight(cam):
		return -1.0e20
	var mirror_xf: Transform3D = _get_mirror_global_transform()
	var mirror_origin: Vector3 = mirror_xf.origin
	var to_mirror: Vector3 = mirror_origin - cam.global_position
	var dist2: float = maxf(to_mirror.length_squared(), 0.001)
	var dir_to_mirror: Vector3 = to_mirror.normalized()
	var cam_forward: Vector3 = -cam.global_basis.z.normalized()
	var face_normal: Vector3 = mirror_xf.basis.z.normalized()
	var forward_align: float = maxf(cam_forward.dot(dir_to_mirror), 0.0)
	var facing: float = absf(face_normal.dot(-dir_to_mirror))
	var mirror_radius: float = maxf(_mirror_half_extents.length(), 0.05)
	var distance_term: float = mirror_radius / maxf(sqrt(dist2), 0.05)
	var distance_quality: float = clampf(distance_term * 2.0, 0.0, 2.0)
	var behind_penalty: float = 0.2 if cam.is_position_behind(mirror_origin) else 1.0
	return (distance_quality * 1.5 + forward_align + facing * 0.4) * behind_penalty


func _is_mirror_visible_from_camera(cam: Camera3D) -> bool:
	if cam == null:
		return false
	var origin: Vector3 = _get_mirror_global_transform().origin
	if cam.is_position_in_frustum(origin):
		return true
	var corners: Array[Vector3] = _get_mirror_corners_world()
	for corner: Vector3 in corners:
		if cam.is_position_in_frustum(corner):
			return true
	return false


func _has_mirror_line_of_sight(cam: Camera3D) -> bool:
	if cam == null:
		return false
	var world: World3D = cam.get_world_3d()
	if world == null:
		return true
	var from: Vector3 = cam.global_position
	var to: Vector3 = _get_mirror_global_transform().origin
	if from.distance_squared_to(to) <= 0.0001:
		return true
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var excludes: Array[RID] = [self.get_rid()]
	var cam_parent: Node = cam.get_parent()
	if cam_parent is CollisionObject3D:
		excludes.append((cam_parent as CollisionObject3D).get_rid())
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
	return false


func _apply_mirror_runtime_budget() -> void:
	if not manager_enable_budgeting:
		_set_managed_mirror_active(true)
		return
	if _mirror_runtime_manager == null:
		_register_mirror_runtime_manager()
		if _mirror_runtime_manager == null:
			return
	var active: bool = bool(_mirror_runtime_manager.call("is_mirror_render_active", self))
	_set_managed_mirror_active(active)


func _set_managed_mirror_active(active: bool) -> void:
	if _managed_mirror_active == active:
		return
	_managed_mirror_active = active
	if _plugin_mirror != null and is_instance_valid(_plugin_mirror):
		_plugin_mirror.set_process(active)
		_plugin_mirror.visible = active and enabled
		var plugin_vp: SubViewport = _get_plugin_subviewport()
		if plugin_vp != null:
			plugin_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if active else SubViewport.UPDATE_DISABLED
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


func _get_plugin_subviewport() -> SubViewport:
	if _plugin_mirror == null or not is_instance_valid(_plugin_mirror):
		return null
	var by_path: Node = _plugin_mirror.get_node_or_null("MirrorContainer/SubViewport")
	if by_path is SubViewport:
		return by_path as SubViewport
	var by_name: Node = _plugin_mirror.find_child("SubViewport", true, false)
	if by_name is SubViewport:
		return by_name as SubViewport
	return null


func _setup_plugin_mirror() -> void:
	if _plugin_mirror != null and is_instance_valid(_plugin_mirror):
		return
	var script_res: Resource = load("res://addons/Mirror/Mirror/Mirror.gd")
	if not (script_res is Script):
		push_warning("%s: Mirror plugin backend script not found. Falling back to built-in mirror backend." % name)
		use_plugin_mirror = false
		_build_mirror_surface()
		_setup_mirror_viewport()
		return
	_plugin_mirror = Node3D.new()
	_plugin_mirror.name = "PluginMirrorBackend"
	_plugin_mirror.set_script(script_res as Script)
	add_child(_plugin_mirror)
	_plugin_mirror.set_process(_managed_mirror_active)
	_sync_plugin_mirror()


func _sync_plugin_mirror() -> void:
	if _plugin_mirror == null or not is_instance_valid(_plugin_mirror):
		return
	_plugin_mirror.visible = enabled and _managed_mirror_active
	_plugin_mirror.transform = _mirror_local_xform
	var wanted_size: Vector2 = _mirror_half_extents * 2.0
	_plugin_mirror.set("size", wanted_size)
	var rpu: int = _compute_plugin_resolution_per_unit()
	if rpu != _last_plugin_resolution_per_unit:
		_plugin_mirror.set("ResolutionPerUnit", rpu)
		_last_plugin_resolution_per_unit = rpu
	_plugin_mirror.set("MainCamPath", NodePath(""))
	if mirror_tint != _last_plugin_tint:
		_plugin_mirror.set("MirrorColor", mirror_tint)
		_last_plugin_tint = mirror_tint
	if absf(mirror_distortion - _last_plugin_distortion) > 0.0001:
		_plugin_mirror.set("MirrorDistortion", mirror_distortion)
		_last_plugin_distortion = mirror_distortion
	var tex_id: int = -1 if mirror_distortion_texture == null else mirror_distortion_texture.get_instance_id()
	if tex_id != _last_plugin_distortion_tex_id:
		_plugin_mirror.set("DistortionTexture", mirror_distortion_texture)
		_last_plugin_distortion_tex_id = tex_id
	var cull: Array[int] = _build_plugin_cull_mask()
	var cull_sig: String = ""
	for i in range(cull.size()):
		if i > 0:
			cull_sig += ","
		cull_sig += str(cull[i])
	if cull_sig != _last_plugin_cull_signature:
		_plugin_mirror.set("cullMask", cull)
		_last_plugin_cull_signature = cull_sig
	var plugin_vp: SubViewport = _get_plugin_subviewport()
	if plugin_vp != null:
		plugin_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if _managed_mirror_active else SubViewport.UPDATE_DISABLED


func _build_plugin_cull_mask() -> Array[int]:
	var out: Array[int] = []
	var seen: Dictionary = {}
	# Mirror plugin expects 0-based layer indices.
	var mirror_surface_idx: int = PLUGIN_MIRROR_LAYER_INDEX
	out.append(mirror_surface_idx)
	seen[mirror_surface_idx] = true
	for layer_num in render_cull_exclude_layers:
		if layer_num < 1 or layer_num > 32:
			continue
		var idx: int = layer_num - 1
		if seen.has(idx):
			continue
		out.append(idx)
		seen[idx] = true
	return out


func _compute_plugin_resolution_per_unit() -> int:
	var base_rpu: int = maxi(int(round(float(plugin_base_resolution_per_unit) * render_scale)), 32)
	var min_rpu: int = mini(plugin_min_resolution_per_unit, plugin_max_resolution_per_unit)
	var max_rpu: int = maxi(plugin_min_resolution_per_unit, plugin_max_resolution_per_unit)
	if not plugin_dynamic_resolution:
		return clampi(base_rpu, min_rpu, max_rpu)

	var src_cam: Camera3D = get_viewport().get_camera_3d()
	if src_cam == null:
		return clampi(base_rpu, min_rpu, max_rpu)
	var mirror_xf: Transform3D = _get_mirror_global_transform()
	var n: Vector3 = mirror_xf.basis.z.normalized()
	var dist: float = absf((src_cam.global_position - mirror_xf.origin).dot(n))
	var safe_dist: float = maxf(dist, 0.05)
	var boost: float = clampf(plugin_resolution_near_distance / safe_dist, 1.0, plugin_max_resolution_boost)
	var dynamic_rpu: int = int(round(float(base_rpu) * boost))
	return clampi(dynamic_rpu, min_rpu, max_rpu)


func _get_mirror_corners_world() -> Array[Vector3]:
	var xf: Transform3D = _get_mirror_global_transform()
	var hx: float = _mirror_half_extents.x
	var hy: float = _mirror_half_extents.y
	var right: Vector3 = xf.basis.x
	var up: Vector3 = xf.basis.y
	var c: Vector3 = xf.origin
	return [
		c + right * -hx + up * -hy,
		c + right * hx + up * -hy,
		c + right * hx + up * hy,
		c + right * -hx + up * hy
	]


func _hide_source_mesh_children() -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		if mi == _surface:
			continue
		if _plugin_mirror != null and is_instance_valid(_plugin_mirror) and _plugin_mirror.is_ancestor_of(mi):
			continue
		mi.visible = false


func _configure_mirror_plane() -> void:
	if _try_configure_mirror_plane_from_metadata():
		return
	if mirror_face_from_texture:
		if not _metadata_retry_pending:
			_metadata_retry_pending = true
			call_deferred("_retry_configure_mirror_plane_from_metadata")
		return
	var bounds: AABB = _compute_local_bounds()
	_configure_mirror_plane_from_bounds(bounds)


func _retry_configure_mirror_plane_from_metadata() -> void:
	_metadata_retry_pending = false
	if not is_inside_tree():
		return
	if _try_configure_mirror_plane_from_metadata():
		_metadata_warning_emitted = false
		if use_plugin_mirror:
			_sync_plugin_mirror()
			return
		if _surface != null:
			var quad := QuadMesh.new()
			quad.size = _mirror_half_extents * 2.0
			_surface.mesh = quad
			_surface.transform = _mirror_local_xform
		return
	# If metadata still isn't attached in this deferred tick, do not emit fallback warning.
	# _ready() will rebuild and try again once FuncGodot has finished attaching metadata.
	if not has_meta("func_godot_mesh_data"):
		return
	if _used_metadata_plane:
		return
	if mirror_face_from_texture and mirror_debug and not _metadata_warning_emitted:
		push_warning("%s: missing exact mirror face metadata, using bounds-derived mirror plane fallback." % name)
		_metadata_warning_emitted = true


func _try_configure_mirror_plane_from_metadata() -> bool:
	if not mirror_face_from_texture:
		return false
	if not has_meta("func_godot_mesh_data"):
		return false
	var md_v: Variant = get_meta("func_godot_mesh_data")
	if not (md_v is Dictionary):
		return false
	var md: Dictionary = md_v as Dictionary
	if _try_configure_mirror_plane_from_exact_metadata(md):
		return true
	if not mirror_allow_legacy_face_fit:
		return false
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
		if tex_name.find("mirror") == -1:
			continue
		var n: Vector3 = normals[i].normalized()
		if n.length_squared() < 0.000001:
			continue
		var score: float = absf(n.dot(_mirror_local_xform.basis.z.normalized()))
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
	# FuncGodot face metadata is provided in entity-local space; use directly.
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
	var fit: Dictionary = _fit_mirror_rect_and_axes_from_face_triangles(textures, normals, positions, vertices, best_idx, local_normal, x_axis, y_axis)
	var fit_ok: bool = bool(fit.get("ok", false))
	if fit_ok:
		x_axis = fit.get("x_axis", x_axis) as Vector3
		y_axis = fit.get("y_axis", y_axis) as Vector3
		_mirror_local_xform = Transform3D(Basis(x_axis, y_axis, local_normal), fit.get("center", local_center) as Vector3)
		var fit_half: Vector2 = fit.get("half_extents", Vector2.ONE * 0.05) as Vector2
		_mirror_half_extents = Vector2(maxf(fit_half.x, 0.05), maxf(fit_half.y, 0.05))
	else:
		_mirror_local_xform = Transform3D(Basis(x_axis, y_axis, local_normal), local_center)
		_mirror_half_extents = Vector2(
			maxf(_support_extent(half_size, x_axis), 0.05),
			maxf(_support_extent(half_size, y_axis), 0.05)
		)
	_mirror_depth = maxf(_support_extent(half_size, local_normal) * 2.0, 0.01)
	_used_metadata_plane = true
	if mirror_debug:
		print("[Mirror DEBUG] %s metadata local_center=%s world_as_local=%s direct_local=%s local_normal=%s fit_ok=%s half=%s basis_det=%.4f metadata_used=%s" % [
			name, str(local_center), str(local_center_world), str(local_center_direct), str(local_normal), str(fit_ok), str(_mirror_half_extents), _mirror_local_xform.basis.determinant()
			, str(_used_metadata_plane)
		])
	return true


func _try_configure_mirror_plane_from_exact_metadata(md: Dictionary) -> bool:
	var face_v: Variant = _dict_get_string_key(md, "mirror_face", null)
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
	_mirror_local_xform = Transform3D(Basis(x_axis, y_axis, local_normal), local_center)
	_mirror_half_extents = Vector2(maxf(half_extents.x, 0.05), maxf(half_extents.y, 0.05))
	_mirror_depth = maxf(_support_extent(half_size, local_normal) * 2.0, 0.01)
	_used_metadata_plane = true
	if mirror_debug and _is_runtime_debug_enabled():
		print("[Mirror DEBUG] %s exact metadata local_center=%s local_normal=%s half=%s" % [
			name, str(local_center), str(local_normal), str(_mirror_half_extents)
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


func _fit_mirror_rect_from_face_triangles(
	textures: PackedInt32Array,
	normals: PackedVector3Array,
	positions: PackedVector3Array,
	vertices: PackedVector3Array,
	best_idx: int,
	local_normal: Vector3,
	x_axis: Vector3,
	y_axis: Vector3
) -> Dictionary:
	return _fit_mirror_rect_and_axes_from_face_triangles(
		textures, normals, positions, vertices, best_idx, local_normal, x_axis, y_axis
	)


func _fit_mirror_rect_and_axes_from_face_triangles(
	textures: PackedInt32Array,
	normals: PackedVector3Array,
	positions: PackedVector3Array,
	vertices: PackedVector3Array,
	best_idx: int,
	local_normal: Vector3,
	x_axis_seed: Vector3,
	y_axis_seed: Vector3
) -> Dictionary:
	if best_idx < 0 or best_idx >= textures.size() or best_idx >= positions.size():
		return {"ok": false}
	var x_axis: Vector3 = x_axis_seed
	var y_axis: Vector3 = y_axis_seed
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
		"half_extents": Vector2(half_x, half_y),
		"x_axis": x_axis,
		"y_axis": y_axis
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
		return bounds
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
		return bounds
	return AABB(Vector3(-0.5, -1.0, -0.05), Vector3(1.0, 2.0, 0.1))


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


func _configure_mirror_plane_from_bounds(bounds: AABB) -> void:
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
	_mirror_half_extents = Vector2(half_x, half_y)
	_mirror_depth = maxf(half_depth * 2.0, 0.01)
	var face_offset: float = maxf(half_depth - 0.005, 0.0)
	var origin: Vector3 = center + z_axis * face_offset
	_mirror_local_xform = Transform3D(Basis(x_axis, y_axis, z_axis), origin)


func _resolve_axis_override() -> int:
	match mirror_axis:
		"x", "-x":
			return 0
		"y", "-y":
			return 1
		"z", "-z":
			return 2
		_:
			return -1


func _resolve_axis_sign() -> float:
	if mirror_axis.begins_with("-"):
		return -1.0
	return 1.0


func _support_extent(half_size: Vector3, dir: Vector3) -> float:
	var ad: Vector3 = Vector3(absf(dir.x), absf(dir.y), absf(dir.z))
	return half_size.x * ad.x + half_size.y * ad.y + half_size.z * ad.z

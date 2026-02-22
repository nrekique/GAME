class_name PS1ShaderManager
extends Node

# exported settings originally on GameManager
@export var enable_ps1_geometry_shader: bool = true
@export_range(32.0, 1024.0, 1.0) var vertex_snap: float = 320.0
@export_range(2.0, 64.0, 1.0) var color_steps: float = 32.0
@export_range(0.0, 1.0, 0.01) var posterize_strength: float = 0.35
@export_range(0.0, 1.0, 0.01) var affine_warp: float = 0.08
@export_range(0.0, 0.02, 0.0001) var uv_jitter: float = 0.0006
@export var jitter_depth_independent: bool = true
@export var jitter_z_coordinate: bool = false
@export var affine_texture_mapping: bool = false
@export_range(0.0, 1.0, 0.01) var affine_mapping_strength: float = 0.0
@export_range(0.0, 1.0, 0.01) var alpha_scissor_threshold: float = 0.0
@export var dithering_enabled: bool = true
@export_range(0.0, 2.0, 0.01) var dither_strength: float = 1.2
@export_range(1, 8, 1) var dither_resolution_scale: int = 2
@export var light_dither_enabled: bool = true
@export var light_dither_texture: Texture2D
@export_range(0.1, 16.0, 0.1) var light_dither_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var light_dither_strength: float = 0.2
@export_range(1.0, 16.0, 1.0) var light_dither_levels: float = 5.0

const PS1_SHADER_PATH := "res://shaders/ps1_geometry.gdshader"

# internal state
var _ps1_shader: Shader = null
var _ps1_material_cache: Dictionary = {}
var _ps1_cached_materials: Array[ShaderMaterial] = []
var _ps1_mesh_ids: Dictionary = {}
var _ps1_original_materials: Dictionary = {}
var _ps1_scene_id: int = -1
var _ps1_default_dither_texture: Texture2D = null

var _ps1_globals_checked: bool = false
var _ps1_globals_available: bool = false
var _ps1_globals_warned: bool = false

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
	var dither_texture := light_dither_texture
	if dither_texture == null:
		dither_texture = _get_default_ps1_light_dither_texture()
	var light_strength := light_dither_strength
	if not enable_ps1_geometry_shader or not light_dither_enabled:
		light_strength = 0.0
	RenderingServer.global_shader_parameter_set("dither_texture", dither_texture)
	RenderingServer.global_shader_parameter_set("dither_scale", maxf(light_dither_scale, 0.001))
	RenderingServer.global_shader_parameter_set("dither_strength", clampf(light_strength, 0.0, 1.0))
	RenderingServer.global_shader_parameter_set("dither_levels", maxf(light_dither_levels, 1.0))

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

func apply_to_node(node: Node) -> void:
	# external call analogue of GameManager's _on_tree_node_added
	if node is MeshInstance3D:
		call_deferred("_apply_ps1_to_mesh", node)

func apply_scene(root: Node) -> void:
	_apply_ps1_to_scene(root)

func _on_tree_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		call_deferred("_apply_ps1_to_mesh", node)

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
	result.set_shader_parameter("jitter_depth_independent", jitter_depth_independent)
	result.set_shader_parameter("jitter_z_coordinate", jitter_z_coordinate)
	result.set_shader_parameter("affine_texture_mapping", affine_texture_mapping)
	result.set_shader_parameter("affine_mapping_strength", affine_mapping_strength)
	result.set_shader_parameter("alpha_scissor_threshold", alpha_scissor_threshold)

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
	material.set_shader_parameter("vertex_snap", vertex_snap)
	material.set_shader_parameter("color_steps", color_steps)
	material.set_shader_parameter("posterize_strength", posterize_strength)
	material.set_shader_parameter("affine_warp_strength", affine_warp)
	material.set_shader_parameter("uv_jitter", uv_jitter)
	material.set_shader_parameter("jitter_depth_independent", jitter_depth_independent)
	material.set_shader_parameter("jitter_z_coordinate", jitter_z_coordinate)
	material.set_shader_parameter("affine_texture_mapping", affine_texture_mapping)
	material.set_shader_parameter("affine_mapping_strength", affine_mapping_strength)
	material.set_shader_parameter("alpha_scissor_threshold", alpha_scissor_threshold)
	material.set_shader_parameter("dithering_enabled", dithering_enabled)
	material.set_shader_parameter("color_dither_strength", dither_strength)
	material.set_shader_parameter("dither_resolution_scale", dither_resolution_scale)

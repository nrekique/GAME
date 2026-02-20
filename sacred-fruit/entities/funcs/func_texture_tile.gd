@tool
class_name FuncTextureTile
extends StaticBody3D

@export var tiling_texture: Texture2D
@export_range(0.01, 64.0, 0.01) var tiling_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var roughness: float = 0.9
@export_range(0.0, 1.0, 0.01) var metallic: float = 0.0
@export var use_texture_alpha: bool = false
@export var use_alpha_cutout: bool = false
@export_range(0.0, 1.0, 0.01) var alpha_cutoff: float = 0.5

const SHADER_PATH := "res://shaders/func_texture_tile.gdshader"
const DEFAULT_TEXTURE_PATH := "res://addons/func_godot/textures/default_texture.png"
const TEXTURE_SEARCH_ROOTS: PackedStringArray = ["res://tb/textures", "res://textures"]
const TEXTURE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "bmp", "tga", "webp"]
const MIN_TILING_SCALE := 0.01

var _tile_material: ShaderMaterial
var _apply_retry_count: int = 0


func _ready() -> void:
	call_deferred("_apply_tiled_material")


func _func_godot_apply_properties(props: Dictionary) -> void:
	_apply_retry_count = 0
	if props.has("tiling_scale"):
		tiling_scale = maxf(float(props["tiling_scale"]), MIN_TILING_SCALE)
	if props.has("tiling_texture"):
		tiling_texture = _parse_texture(props["tiling_texture"])
	if props.has("roughness"):
		roughness = clampf(float(props["roughness"]), 0.0, 1.0)
	if props.has("metallic"):
		metallic = clampf(float(props["metallic"]), 0.0, 1.0)
	if props.has("use_texture_alpha"):
		use_texture_alpha = _parse_bool(props["use_texture_alpha"], use_texture_alpha)
	if props.has("use_alpha_cutout"):
		use_alpha_cutout = _parse_bool(props["use_alpha_cutout"], use_alpha_cutout)
	if props.has("alpha_cutoff"):
		alpha_cutoff = clampf(float(props["alpha_cutoff"]), 0.0, 1.0)
	call_deferred("_apply_tiled_material")


func _apply_tiled_material() -> void:
	var meshes: Array[MeshInstance3D] = _collect_mesh_instances(self)
	if meshes.is_empty():
		if _apply_retry_count < 8:
			_apply_retry_count += 1
			call_deferred("_apply_tiled_material")
		return

	if _tile_material == null:
		var shader := load(SHADER_PATH) as Shader
		if shader == null:
			push_warning("%s: missing shader at %s" % [name, SHADER_PATH])
			return
		_tile_material = ShaderMaterial.new()
		_tile_material.shader = shader

	var resolved_texture: Texture2D = tiling_texture
	if resolved_texture == null:
		resolved_texture = _find_fallback_texture(meshes)
	if resolved_texture == null:
		resolved_texture = _find_texture_from_metadata()
	if resolved_texture == null:
		resolved_texture = load(DEFAULT_TEXTURE_PATH) as Texture2D
	if resolved_texture != null:
		_tile_material.set_shader_parameter("tiling_texture", resolved_texture)
	_tile_material.set_shader_parameter("tiling_scale", maxf(tiling_scale, MIN_TILING_SCALE))
	_tile_material.set_shader_parameter("roughness", roughness)
	_tile_material.set_shader_parameter("metallic", metallic)
	_tile_material.set_shader_parameter("use_texture_alpha", use_texture_alpha)
	_tile_material.set_shader_parameter("use_alpha_cutout", use_alpha_cutout)
	_tile_material.set_shader_parameter("alpha_cutoff", alpha_cutoff)

	for mesh_instance in meshes:
		mesh_instance.material_override = _tile_material


func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			result.append(current as MeshInstance3D)
		for child in current.get_children():
			if child is Node:
				stack.append(child as Node)
	return result


func _find_fallback_texture(meshes: Array[MeshInstance3D]) -> Texture2D:
	for mesh_instance in meshes:
		var from_override := _texture_from_material(mesh_instance.material_override)
		if from_override != null:
			return from_override
		if mesh_instance.mesh == null:
			continue
		var surface_count := mesh_instance.mesh.get_surface_count()
		for i in surface_count:
			var mat := mesh_instance.mesh.surface_get_material(i)
			var from_surface := _texture_from_material(mat)
			if from_surface != null:
				return from_surface
	return null


func _find_texture_from_metadata() -> Texture2D:
	if not has_meta("func_godot_mesh_data"):
		return null
	var md_v: Variant = get_meta("func_godot_mesh_data")
	if not (md_v is Dictionary):
		return null
	var md: Dictionary = md_v
	if not md.has("texture_names"):
		return null
	var names_v: Variant = md["texture_names"]
	if not (names_v is Array):
		return null
	var names: Array = names_v
	for name_v in names:
		var raw_name := String(name_v).strip_edges()
		if raw_name.is_empty():
			continue
		for root in TEXTURE_SEARCH_ROOTS:
			for ext in TEXTURE_EXTENSIONS:
				var path := "%s/%s.%s" % [root, raw_name, ext]
				if ResourceLoader.exists(path, "Texture2D"):
					var tex := load(path) as Texture2D
					if tex != null:
						return tex
	return null


func _texture_from_material(material: Material) -> Texture2D:
	if material == null:
		return null
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).albedo_texture
	if material is ShaderMaterial:
		var shader_mat := material as ShaderMaterial
		var candidates := ["albedo_texture", "texture_albedo", "tex_alb", "texture"]
		for key in candidates:
			var value: Variant = shader_mat.get_shader_parameter(key)
			if value is Texture2D:
				return value as Texture2D
	return null


func _parse_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value as Texture2D
	if value is String:
		var path := String(value).strip_edges()
		if path.is_empty():
			return null
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return null


func _parse_bool(value: Variant, default_value: bool) -> bool:
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

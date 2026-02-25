extends Node3D
const Util := preload("res://scripts/core/util.gd")

@export var enabled: bool = true
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.85
@export var wind_direction: Vector2 = Vector2(1.0, 0.2)
@export_range(0.0, 4.0, 0.01) var wind_speed: float = 1.0
@export var affect_fog: bool = true
@export_range(0.0, 0.2, 0.001) var fog_density_min: float = 0.01
@export_range(0.0, 0.2, 0.001) var fog_density_max: float = 0.065
@export_range(0.0, 0.2, 0.001) var volumetric_fog_density_min: float = 0.01
@export_range(0.0, 0.2, 0.001) var volumetric_fog_density_max: float = 0.05
@export var force_fog_enabled: bool = false
@export var force_volumetric_fog_enabled: bool = false
@export var fog_color: Color = Color(0.78, 0.62, 0.36, 1.0)
@export var overlay_noise_texture: Texture2D = preload("res://tb/textures/special/sandstorm.png")
@export var dust_texture: Texture2D = preload("res://tb/textures/special/sandstorm.png")
@export_range(0.0, 1.0, 0.01) var dust_alpha: float = 0.24
@export var allow_map_overrides: bool = true
@export var weather_mode: String = "none" # none, rain, snow
@export_range(0.0, 1.0, 0.01) var weather_intensity: float = 0.0
@export_range(0.0, 1.0, 0.01) var postfx_strength: float = 0.0
@export_range(0.25, 4.0, 0.01) var postfx_exposure: float = 1.0
@export_range(0.1, 4.0, 0.01) var postfx_contrast: float = 1.0
@export_range(0.0, 2.0, 0.01) var postfx_saturation: float = 1.0
@export var audio_ambience_stream_path: String = ""
@export_range(-60.0, 12.0, 0.1) var audio_ambience_volume_db: float = -10.0
@export var audio_ambience_bus: String = "SFX"
@export_range(1, 64, 1) var portal_budget_max_active: int = 4
@export_range(0.02, 0.5, 0.01) var portal_budget_refresh_seconds: float = 0.10
@export_range(0.25, 1.0, 0.05) var portal_budget_max_render_scale: float = 0.60
@export_range(0.25, 1.0, 0.05) var portal_budget_min_render_scale: float = 0.30
@export_range(0.0, 4.0, 0.01) var portal_budget_min_priority: float = 0.0
@export_range(1, 64, 1) var mirror_budget_max_active: int = 2
@export_range(0.02, 0.5, 0.01) var mirror_budget_refresh_seconds: float = 0.08
@export_range(0.25, 1.0, 0.05) var mirror_budget_render_scale: float = 0.60
@export_range(0.0, 4.0, 0.01) var mirror_budget_min_priority: float = 0.0
@export var portal_budget_stress_profile: bool = false
@export var portal_budget_profile_mode: String = "balanced" # cinematic, balanced, stress

const OVERLAY_SHADER := preload("res://shaders/sandstorm_overlay.gdshader")

var _camera: Camera3D = null
var _world_env_node: WorldEnvironment = null
var _overlay_layer: CanvasLayer = null
var _overlay_rect: ColorRect = null
var _overlay_mat: ShaderMaterial = null
var _dust_particles_near: GPUParticles3D = null
var _dust_particles_far: GPUParticles3D = null
var _weather_particles: GPUParticles3D = null
var _ambient_audio: AudioStreamPlayer = null
var _zone_settings: Array[Dictionary] = []
var _base_intensity: float = 0.0
var _base_fog_density_min: float = 0.0
var _base_fog_density_max: float = 0.0
var _base_wind_speed: float = 0.0

var _saved_env: Dictionary = {}


func _ready() -> void:
	if Util.editor_hint():
		set_process(false)
		return
	if allow_map_overrides:
		_apply_map_overrides()
	else:
		_base_intensity = intensity
		_base_fog_density_min = fog_density_min
		_base_fog_density_max = fog_density_max
		_base_wind_speed = wind_speed
	if not enabled:
		set_process(false)
		return
	_camera = _find_active_camera()
	_world_env_node = _find_world_environment()
	_setup_overlay()
	_setup_particles()
	_setup_weather_particles()
	_setup_audio_ambience()
	_capture_env_state()
	_apply_state()
	set_process(true)


func _exit_tree() -> void:
	_restore_env_state()


func _process(_delta: float) -> void:
	if not enabled:
		return
	if _camera == null:
		_camera = _find_active_camera()
		_attach_particles_to_camera_if_needed()
		_attach_weather_to_camera_if_needed()
	_update_zone_blend()
	_apply_state()


func set_intensity(v: float) -> void:
	intensity = clampf(v, 0.0, 1.0)
	_apply_state()


func _find_active_camera() -> Camera3D:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		return cam
	var found := get_tree().root.find_child("Camera", true, false)
	return found as Camera3D


func _find_world_environment() -> WorldEnvironment:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	if scene == null:
		return null
	var nodes := scene.find_children("*", "WorldEnvironment", true, false)
	if nodes.is_empty():
		return null
	return nodes[0] as WorldEnvironment


func _setup_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "SandstormOverlay"
	_overlay_layer.layer = 60
	add_child(_overlay_layer)

	_overlay_rect = ColorRect.new()
	_overlay_rect.name = "SandstormPostFX"
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.anchor_left = 0.0
	_overlay_rect.anchor_top = 0.0
	_overlay_rect.anchor_right = 1.0
	_overlay_rect.anchor_bottom = 1.0
	_overlay_rect.offset_left = 0.0
	_overlay_rect.offset_top = 0.0
	_overlay_rect.offset_right = 0.0
	_overlay_rect.offset_bottom = 0.0
	_overlay_rect.color = Color(1, 1, 1, 1)

	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = OVERLAY_SHADER
	if overlay_noise_texture != null:
		_overlay_mat.set_shader_parameter("noise_texture", overlay_noise_texture)
	_overlay_rect.material = _overlay_mat
	_overlay_layer.add_child(_overlay_rect)


func _setup_particles() -> void:
	_dust_particles_near = _make_dust_particles("SandDustNear", 520, 5.0, 1.5, 0.22)
	_dust_particles_far = _make_dust_particles("SandDustFar", 320, 8.0, 3.2, 0.55)
	if _camera != null:
		_camera.add_child(_dust_particles_near)
		_camera.add_child(_dust_particles_far)
		_dust_particles_near.position = Vector3(0.0, 0.0, -2.0)
		_dust_particles_far.position = Vector3(0.0, 0.0, -5.0)
	else:
		add_child(_dust_particles_near)
		add_child(_dust_particles_far)


func _setup_weather_particles() -> void:
	_weather_particles = _make_dust_particles("WeatherParticles", 720, 2.5, 4.0, 0.16)
	if _weather_particles == null:
		return
	if _camera != null:
		_camera.add_child(_weather_particles)
		_weather_particles.position = Vector3(0.0, 2.0, -1.0)
	else:
		add_child(_weather_particles)


func _setup_audio_ambience() -> void:
	_ambient_audio = AudioStreamPlayer.new()
	_ambient_audio.name = "EnvAmbience"
	_ambient_audio.autoplay = false
	_ambient_audio.bus = audio_ambience_bus
	add_child(_ambient_audio)


func _make_dust_particles(name: String, amount: int, lifetime: float, radius: float, scale: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = name
	p.amount = amount
	p.set_meta("base_amount", amount)
	p.lifetime = lifetime
	p.explosiveness = 0.0
	p.randomness = 0.35
	p.local_coords = false
	p.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	p.visibility_aabb = AABB(Vector3(-radius, -radius, -radius * 2.0), Vector3(radius * 2.0, radius * 2.0, radius * 4.0))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius, radius * 0.6, radius)
	pm.direction = Vector3(1.0, -0.02, 0.2).normalized()
	pm.spread = 25.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.8
	pm.gravity = Vector3.ZERO
	pm.scale_min = scale * 0.7
	pm.scale_max = scale
	pm.damping_min = 0.1
	pm.damping_max = 0.35
	pm.alpha_curve = _build_alpha_curve()
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.12 * scale, 0.12 * scale)
	quad.material = _build_dust_material()
	p.draw_pass_1 = quad
	return p


func _build_dust_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(fog_color.r, fog_color.g, fog_color.b, dust_alpha)
	if dust_texture != null:
		mat.albedo_texture = dust_texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


func _build_alpha_curve() -> CurveTexture:
	var c := Curve.new()
	c.min_value = 0.0
	c.max_value = 1.0
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.15, 0.65))
	c.add_point(Vector2(0.8, 0.42))
	c.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex


func _capture_env_state() -> void:
	if _world_env_node == null or _world_env_node.environment == null:
		return
	var env := _world_env_node.environment
	_saved_env["fog_enabled"] = env.get("fog_enabled")
	_saved_env["volumetric_fog_enabled"] = env.get("volumetric_fog_enabled")
	_saved_env["fog_density"] = env.get("fog_density")
	_saved_env["fog_light_color"] = env.get("fog_light_color")
	_saved_env["volumetric_fog_albedo"] = env.get("volumetric_fog_albedo")
	_saved_env["volumetric_fog_density"] = env.get("volumetric_fog_density")
	_saved_env["adjustment_enabled"] = env.get("adjustment_enabled")
	_saved_env["adjustment_brightness"] = env.get("adjustment_brightness")
	_saved_env["adjustment_contrast"] = env.get("adjustment_contrast")
	_saved_env["adjustment_saturation"] = env.get("adjustment_saturation")
	_saved_env["tonemap_exposure"] = env.get("tonemap_exposure")


func _restore_env_state() -> void:
	if _world_env_node == null or _world_env_node.environment == null:
		return
	if _saved_env.is_empty():
		return
	var env := _world_env_node.environment
	for key in _saved_env.keys():
		env.set(key, _saved_env[key])


func _apply_state() -> void:
	var i := clampf(intensity, 0.0, 1.0)
	var wind2 := wind_direction.normalized() * maxf(wind_speed, 0.01)

	if _overlay_mat != null:
		_overlay_mat.set_shader_parameter("intensity", i)
		_overlay_mat.set_shader_parameter("wind_dir", wind2)
		_overlay_mat.set_shader_parameter("wind_speed", 0.12 * maxf(wind_speed, 0.01))
		_overlay_mat.set_shader_parameter("storm_color", fog_color)

	_update_particle_state(_dust_particles_near, i, wind2, 1.0)
	_update_particle_state(_dust_particles_far, i, wind2, 0.7)
	_update_weather_state(i, wind2)
	_apply_fog_state(i)
	_apply_postfx_state()


func _update_particle_state(p: GPUParticles3D, i: float, wind2: Vector2, weight: float) -> void:
	if p == null:
		return
	var pm := p.process_material as ParticleProcessMaterial
	if pm == null:
		return
	p.emitting = i > 0.01
	var dir := Vector3(wind2.x, -0.02, wind2.y).normalized()
	pm.direction = dir
	pm.initial_velocity_min = lerpf(0.7, 2.2, i) * weight
	pm.initial_velocity_max = lerpf(1.6, 4.8, i) * weight
	pm.scale_min = lerpf(0.08, 0.22, i) * weight
	pm.scale_max = lerpf(0.14, 0.34, i) * weight
	var base_amount: int = int(p.get_meta("base_amount", p.amount))
	p.amount = int(round(lerpf(12.0, float(base_amount), i)))
	var quad := p.draw_pass_1 as QuadMesh
	if quad != null:
		var mat := quad.material as StandardMaterial3D
		if mat != null:
			var alpha := clampf(dust_alpha * i * (0.8 + 0.2 * weight), 0.0, 1.0)
			mat.albedo_color = Color(fog_color.r, fog_color.g, fog_color.b, alpha)


func _apply_fog_state(i: float) -> void:
	if not affect_fog:
		return
	if _world_env_node == null or _world_env_node.environment == null:
		return
	var env := _world_env_node.environment
	env.set("fog_enabled", force_fog_enabled or i > 0.01)
	env.set("volumetric_fog_enabled", force_volumetric_fog_enabled or i > 0.25)
	env.set("fog_density", lerpf(fog_density_min, fog_density_max, i))
	env.set("volumetric_fog_density", lerpf(volumetric_fog_density_min, volumetric_fog_density_max, i))
	env.set("fog_light_color", fog_color)
	env.set("volumetric_fog_albedo", fog_color)


func _apply_postfx_state() -> void:
	if _world_env_node == null or _world_env_node.environment == null:
		return
	var env := _world_env_node.environment
	var enabled: bool = postfx_strength > 0.001
	env.set("adjustment_enabled", enabled)
	if enabled:
		env.set("adjustment_brightness", 1.0)
		env.set("adjustment_contrast", lerpf(1.0, postfx_contrast, postfx_strength))
		env.set("adjustment_saturation", lerpf(1.0, postfx_saturation, postfx_strength))
		env.set("tonemap_exposure", lerpf(1.0, postfx_exposure, postfx_strength))


func _update_weather_state(storm_intensity: float, wind2: Vector2) -> void:
	if _weather_particles == null:
		return
	var mode: String = weather_mode.strip_edges().to_lower()
	var active: bool = mode != "none" and weather_intensity > 0.01
	_weather_particles.emitting = active
	if not active:
		return
	var pm := _weather_particles.process_material as ParticleProcessMaterial
	if pm == null:
		return
	var weight: float = clampf(weather_intensity, 0.0, 1.0)
	var dir := Vector3(wind2.x, -1.0, wind2.y).normalized()
	pm.direction = dir
	pm.spread = 12.0 if mode == "rain" else 25.0
	pm.initial_velocity_min = lerpf(4.0, 12.0, weight) if mode == "rain" else lerpf(0.5, 2.0, weight)
	pm.initial_velocity_max = lerpf(8.0, 20.0, weight) if mode == "rain" else lerpf(1.0, 3.4, weight)
	pm.scale_min = 0.04 if mode == "rain" else 0.09
	pm.scale_max = 0.08 if mode == "rain" else 0.18
	_weather_particles.amount = int(round(lerpf(120.0, 900.0, weight)))
	var quad := _weather_particles.draw_pass_1 as QuadMesh
	if quad != null:
		var mat := quad.material as StandardMaterial3D
		if mat != null:
			if mode == "rain":
				mat.albedo_color = Color(0.78, 0.84, 0.92, clampf(0.25 * weight, 0.0, 1.0))
			else:
				mat.albedo_color = Color(0.92, 0.92, 0.95, clampf(0.35 * weight, 0.0, 1.0))


func _attach_particles_to_camera_if_needed() -> void:
	if _camera == null:
		return
	if _dust_particles_near != null and _dust_particles_near.get_parent() != _camera:
		if _dust_particles_near.get_parent() != null:
			_dust_particles_near.get_parent().remove_child(_dust_particles_near)
		_camera.add_child(_dust_particles_near)
		_dust_particles_near.position = Vector3(0.0, 0.0, -2.0)
	if _dust_particles_far != null and _dust_particles_far.get_parent() != _camera:
		if _dust_particles_far.get_parent() != null:
			_dust_particles_far.get_parent().remove_child(_dust_particles_far)
		_camera.add_child(_dust_particles_far)
		_dust_particles_far.position = Vector3(0.0, 0.0, -5.0)


func _attach_weather_to_camera_if_needed() -> void:
	if _camera == null or _weather_particles == null:
		return
	if _weather_particles.get_parent() == _camera:
		return
	if _weather_particles.get_parent() != null:
		_weather_particles.get_parent().remove_child(_weather_particles)
	_camera.add_child(_weather_particles)
	_weather_particles.position = Vector3(0.0, 2.0, -1.0)


func _update_zone_blend() -> void:
	intensity = _base_intensity
	fog_density_min = _base_fog_density_min
	fog_density_max = _base_fog_density_max
	wind_speed = _base_wind_speed
	if _zone_settings.is_empty() or _camera == null:
		return
	var best_weight: float = 0.0
	var best_zone: Dictionary = {}
	var cam_pos: Vector3 = _camera.global_position
	for z in _zone_settings:
		var center: Vector3 = z.get("origin", Vector3.ZERO) as Vector3
		var radius: float = maxf(float(z.get("radius", 0.0)), 0.01)
		var dist: float = cam_pos.distance_to(center)
		var w: float = clampf(1.0 - (dist / radius), 0.0, 1.0)
		if w > best_weight:
			best_weight = w
			best_zone = z
	if best_zone.is_empty() or best_weight <= 0.0:
		return
	if best_zone.has("intensity"):
		intensity = lerpf(_base_intensity, clampf(float(best_zone["intensity"]), 0.0, 1.0), best_weight)
	if best_zone.has("fog_density"):
		var zone_fog: float = clampf(float(best_zone["fog_density"]), 0.0, 0.2)
		fog_density_min = lerpf(_base_fog_density_min, zone_fog, best_weight)
		fog_density_max = lerpf(_base_fog_density_max, zone_fog, best_weight)
	if best_zone.has("wind_speed"):
		wind_speed = lerpf(_base_wind_speed, maxf(float(best_zone["wind_speed"]), 0.0), best_weight)


func _apply_map_overrides() -> void:
	_base_intensity = intensity
	_base_fog_density_min = fog_density_min
	_base_fog_density_max = fog_density_max
	_base_wind_speed = wind_speed
	var map_path := _find_current_map_path()
	if map_path.is_empty():
		return
	var cfg := _read_sandstorm_settings_from_map(map_path)
	if not cfg.is_empty():
		if cfg.has("enabled"):
			enabled = bool(cfg["enabled"])
		if cfg.has("intensity"):
			intensity = clampf(float(cfg["intensity"]), 0.0, 1.0)
		if cfg.has("wind_speed"):
			wind_speed = maxf(float(cfg["wind_speed"]), 0.0)
		if cfg.has("wind_direction"):
			wind_direction = cfg["wind_direction"] as Vector2
		if cfg.has("fog_color"):
			fog_color = cfg["fog_color"] as Color

	var fog_cfg: Dictionary = _read_fog_settings_from_map(map_path)
	if not fog_cfg.is_empty():
		affect_fog = true
		if fog_cfg.has("fog_enabled"):
			force_fog_enabled = bool(fog_cfg["fog_enabled"])
		if fog_cfg.has("volumetric_enabled"):
			force_volumetric_fog_enabled = bool(fog_cfg["volumetric_enabled"])
		if fog_cfg.has("fog_color"):
			fog_color = fog_cfg["fog_color"] as Color
		if fog_cfg.has("fog_density"):
			var fog_d: float = clampf(float(fog_cfg["fog_density"]), 0.0, 0.2)
			fog_density_min = fog_d
			fog_density_max = fog_d
		if fog_cfg.has("volumetric_fog_density"):
			var vol_d: float = clampf(float(fog_cfg["volumetric_fog_density"]), 0.0, 0.2)
			volumetric_fog_density_min = vol_d
			volumetric_fog_density_max = vol_d

	var wind_cfg: Dictionary = _read_wind_settings_from_map(map_path)
	if not wind_cfg.is_empty():
		if wind_cfg.has("wind_speed"):
			wind_speed = maxf(float(wind_cfg["wind_speed"]), 0.0)
		if wind_cfg.has("wind_direction"):
			wind_direction = wind_cfg["wind_direction"] as Vector2

	var postfx_cfg: Dictionary = _read_postfx_settings_from_map(map_path)
	if not postfx_cfg.is_empty():
		if postfx_cfg.has("postfx_strength"):
			postfx_strength = clampf(float(postfx_cfg["postfx_strength"]), 0.0, 1.0)
		if postfx_cfg.has("postfx_exposure"):
			postfx_exposure = clampf(float(postfx_cfg["postfx_exposure"]), 0.25, 4.0)
		if postfx_cfg.has("postfx_contrast"):
			postfx_contrast = clampf(float(postfx_cfg["postfx_contrast"]), 0.1, 4.0)
		if postfx_cfg.has("postfx_saturation"):
			postfx_saturation = clampf(float(postfx_cfg["postfx_saturation"]), 0.0, 2.0)

	var weather_cfg: Dictionary = _read_weather_settings_from_map(map_path)
	if not weather_cfg.is_empty():
		if weather_cfg.has("weather_mode"):
			weather_mode = String(weather_cfg["weather_mode"]).strip_edges().to_lower()
		if weather_cfg.has("weather_intensity"):
			weather_intensity = clampf(float(weather_cfg["weather_intensity"]), 0.0, 1.0)

	var audio_cfg: Dictionary = _read_audio_settings_from_map(map_path)
	if not audio_cfg.is_empty():
		if audio_cfg.has("stream_path"):
			audio_ambience_stream_path = String(audio_cfg["stream_path"])
		if audio_cfg.has("volume_db"):
			audio_ambience_volume_db = clampf(float(audio_cfg["volume_db"]), -60.0, 12.0)
		if audio_cfg.has("bus"):
			audio_ambience_bus = String(audio_cfg["bus"]).strip_edges()

	var portal_cfg: Dictionary = _read_portal_budget_settings_from_map(map_path)
	if not portal_cfg.is_empty():
		if portal_cfg.has("profile_mode"):
			portal_budget_profile_mode = String(portal_cfg["profile_mode"]).strip_edges().to_lower()
		if portal_cfg.has("stress_profile"):
			portal_budget_stress_profile = bool(portal_cfg["stress_profile"])
		if portal_cfg.has("max_active"):
			portal_budget_max_active = maxi(1, int(portal_cfg["max_active"]))
		if portal_cfg.has("refresh_seconds"):
			portal_budget_refresh_seconds = clampf(float(portal_cfg["refresh_seconds"]), 0.02, 0.5)
		if portal_cfg.has("max_render_scale"):
			portal_budget_max_render_scale = clampf(float(portal_cfg["max_render_scale"]), 0.25, 1.0)
		if portal_cfg.has("min_render_scale"):
			portal_budget_min_render_scale = clampf(float(portal_cfg["min_render_scale"]), 0.25, portal_budget_max_render_scale)
		if portal_cfg.has("min_priority"):
			portal_budget_min_priority = clampf(float(portal_cfg["min_priority"]), 0.0, 4.0)
		if portal_cfg.has("mirror_max_active"):
			mirror_budget_max_active = maxi(1, int(portal_cfg["mirror_max_active"]))
		if portal_cfg.has("mirror_refresh_seconds"):
			mirror_budget_refresh_seconds = clampf(float(portal_cfg["mirror_refresh_seconds"]), 0.02, 0.5)
		if portal_cfg.has("mirror_render_scale"):
			mirror_budget_render_scale = clampf(float(portal_cfg["mirror_render_scale"]), 0.25, 1.0)
		if portal_cfg.has("mirror_min_priority"):
			mirror_budget_min_priority = clampf(float(portal_cfg["mirror_min_priority"]), 0.0, 4.0)
	if portal_budget_stress_profile:
		portal_budget_profile_mode = "stress"
	_apply_budget_profile_overrides()
	_apply_portal_budget_overrides()

	_zone_settings = _read_zone_settings_from_map(map_path)
	_apply_audio_settings()
	_base_intensity = intensity
	_base_fog_density_min = fog_density_min
	_base_fog_density_max = fog_density_max
	_base_wind_speed = wind_speed


func _find_current_map_path() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	if scene == null:
		return ""
	var map := scene.find_child("FuncGodotMap", true, false)
	if map == null:
		return ""
	var local_path := String(map.get("local_map_file"))
	if not local_path.is_empty():
		return local_path
	return String(map.get("global_map_file"))


func _read_sandstorm_settings_from_map(map_path: String) -> Dictionary:
	var entity_props: Dictionary = _read_first_entity_props(map_path, "env_sandstorm")
	if not entity_props.is_empty():
		return _parse_sandstorm_props(entity_props)
	var worldspawn_props: Dictionary = _read_first_entity_props(map_path, "worldspawn")
	if worldspawn_props.is_empty():
		return {}
	return _parse_sandstorm_props(worldspawn_props)


func _read_fog_settings_from_map(map_path: String) -> Dictionary:
	var entity_props: Dictionary = _read_first_entity_props(map_path, "env_fog_controller")
	if not entity_props.is_empty():
		return _parse_fog_props(entity_props)
	var worldspawn_props: Dictionary = _read_first_entity_props(map_path, "worldspawn")
	if worldspawn_props.is_empty():
		return {}
	return _parse_fog_props(worldspawn_props)


func _read_wind_settings_from_map(map_path: String) -> Dictionary:
	var entity_props: Dictionary = _read_first_entity_props(map_path, "env_wind")
	if not entity_props.is_empty():
		return _parse_wind_props(entity_props)
	var worldspawn_props: Dictionary = _read_first_entity_props(map_path, "worldspawn")
	if worldspawn_props.is_empty():
		return {}
	return _parse_wind_props(worldspawn_props)


func _read_postfx_settings_from_map(map_path: String) -> Dictionary:
	var entity_props: Dictionary = _read_first_entity_props(map_path, "env_postfx")
	if not entity_props.is_empty():
		return _parse_postfx_props(entity_props)
	var worldspawn_props: Dictionary = _read_first_entity_props(map_path, "worldspawn")
	if worldspawn_props.is_empty():
		return {}
	return _parse_postfx_props(worldspawn_props)


func _read_weather_settings_from_map(map_path: String) -> Dictionary:
	var entity_props: Dictionary = _read_first_entity_props(map_path, "env_weather")
	if not entity_props.is_empty():
		return _parse_weather_props(entity_props)
	var worldspawn_props: Dictionary = _read_first_entity_props(map_path, "worldspawn")
	if worldspawn_props.is_empty():
		return {}
	return _parse_weather_props(worldspawn_props)


func _read_portal_budget_settings_from_map(map_path: String) -> Dictionary:
	var entity_props: Dictionary = _read_first_entity_props(map_path, "env_portal_budget")
	if not entity_props.is_empty():
		return _parse_portal_budget_props(entity_props)
	var worldspawn_props: Dictionary = _read_first_entity_props(map_path, "worldspawn")
	if worldspawn_props.is_empty():
		return {}
	return _parse_portal_budget_props(worldspawn_props)


func _read_audio_settings_from_map(map_path: String) -> Dictionary:
	var entity_props: Dictionary = _read_first_entity_props(map_path, "env_audio_ambience")
	if not entity_props.is_empty():
		return _parse_audio_props(entity_props)
	var worldspawn_props: Dictionary = _read_first_entity_props(map_path, "worldspawn")
	if worldspawn_props.is_empty():
		return {}
	return _parse_audio_props(worldspawn_props)


func _read_zone_settings_from_map(map_path: String) -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	var scale_factor: float = _find_map_scale_factor()
	var entries: Array[Dictionary] = _read_entity_props_list(map_path, "env_zone")
	for entry in entries:
		var z: Dictionary = _parse_zone_props(entry, scale_factor)
		if not z.is_empty():
			zones.append(z)
	return zones


func _find_map_scale_factor() -> float:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	if scene == null:
		return 0.03125
	var map := scene.find_child("FuncGodotMap", true, false)
	if map == null:
		return 0.03125
	var ms: Variant = map.get("map_settings")
	if ms == null:
		return 0.03125
	var sf: Variant = ms.get("scale_factor")
	return maxf(float(sf), 0.000001)


func _read_entity_props_list(map_path: String, classname: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(map_path, FileAccess.READ)
	if f == null:
		return out
	var depth: int = 0
	var props: Dictionary = {}
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line == "{":
			depth += 1
			if depth == 1:
				props = {}
			continue
		if line == "}":
			if depth == 1:
				var cls: String = String(props.get("classname", ""))
				if cls == classname:
					out.append(props.duplicate(true))
			depth = maxi(0, depth - 1)
			continue
		if depth != 1 or not line.begins_with('"'):
			continue
		var parts: PackedStringArray = line.split('"')
		if parts.size() < 4:
			continue
		props[String(parts[1])] = String(parts[3])
	f.close()
	return out


func _read_first_entity_props(map_path: String, classname: String) -> Dictionary:
	var f := FileAccess.open(map_path, FileAccess.READ)
	if f == null:
		return {}

	var depth: int = 0
	var props: Dictionary = {}
	var target_props: Dictionary = {}

	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "{":
			depth += 1
			if depth == 1:
				props = {}
			continue
		if line == "}":
			if depth == 1:
				var cls: String = String(props.get("classname", ""))
				if cls == classname:
					target_props = props.duplicate(true)
					break
			depth = maxi(0, depth - 1)
			continue
		if depth != 1:
			continue
		if not line.begins_with('"'):
			continue
		var parts := line.split('"')
		if parts.size() < 4:
			continue
		props[String(parts[1])] = String(parts[3])

	f.close()
	return target_props


func _parse_sandstorm_props(props: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	_apply_bool_key(props, out, ["sandstorm_enabled", "enabled"], "enabled")
	_apply_float_key(props, out, ["sandstorm_intensity", "intensity"], "intensity")
	_apply_float_key(props, out, ["sandstorm_wind_speed", "wind_speed"], "wind_speed")

	var wind_vec: Variant = _parse_vector2_keys(props, ["sandstorm_wind_direction", "sandstorm_wind_dir", "wind_direction", "wind_dir"])
	if wind_vec != null:
		out["wind_direction"] = wind_vec

	var color: Variant = _parse_color_keys(props, ["sandstorm_fog_color", "fog_color", "sandstorm_color"])
	if color != null:
		out["fog_color"] = color
	return out


func _parse_fog_props(props: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	_apply_bool_key(props, out, ["fog_enabled", "enabled"], "fog_enabled")
	_apply_bool_key(props, out, ["volumetric_fog_enabled", "volumetric_enabled"], "volumetric_enabled")
	_apply_float_key(props, out, ["fog_density"], "fog_density")
	_apply_float_key(props, out, ["volumetric_fog_density"], "volumetric_fog_density")
	var color: Variant = _parse_color_keys(props, ["fog_color", "sandstorm_fog_color"])
	if color != null:
		out["fog_color"] = color
	return out


func _parse_wind_props(props: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	_apply_float_key(props, out, ["wind_speed", "sandstorm_wind_speed"], "wind_speed")
	var wind_vec: Variant = _parse_vector2_keys(props, ["wind_direction", "wind_dir", "sandstorm_wind_direction", "sandstorm_wind_dir"])
	if wind_vec != null:
		out["wind_direction"] = wind_vec
	return out


func _parse_postfx_props(props: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	_apply_float_key(props, out, ["postfx_strength", "strength"], "postfx_strength")
	_apply_float_key(props, out, ["postfx_exposure", "exposure"], "postfx_exposure")
	_apply_float_key(props, out, ["postfx_contrast", "contrast"], "postfx_contrast")
	_apply_float_key(props, out, ["postfx_saturation", "saturation"], "postfx_saturation")
	return out


func _parse_weather_props(props: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in ["weather_mode", "mode"]:
		if props.has(key):
			out["weather_mode"] = String(props[key]).strip_edges().to_lower()
			break
	_apply_float_key(props, out, ["weather_intensity", "intensity"], "weather_intensity")
	return out


func _parse_portal_budget_props(props: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in ["profile_mode", "profile", "preset"]:
		if props.has(key):
			out["profile_mode"] = String(props[key]).strip_edges().to_lower()
			break
	_apply_bool_key(props, out, ["stress_profile", "stress"], "stress_profile")
	_apply_float_key(props, out, ["portal_refresh_seconds", "refresh_seconds"], "refresh_seconds")
	_apply_float_key(props, out, ["portal_max_render_scale", "max_render_scale"], "max_render_scale")
	_apply_float_key(props, out, ["portal_min_render_scale", "min_render_scale"], "min_render_scale")
	_apply_float_key(props, out, ["portal_min_priority", "min_priority"], "min_priority")
	_apply_float_key(props, out, ["mirror_refresh_seconds"], "mirror_refresh_seconds")
	_apply_float_key(props, out, ["mirror_render_scale"], "mirror_render_scale")
	_apply_float_key(props, out, ["mirror_min_priority"], "mirror_min_priority")
	for key in ["portal_max_active", "max_active"]:
		if props.has(key):
			out["max_active"] = int(String(props[key]).to_int())
			break
	for key in ["mirror_max_active"]:
		if props.has(key):
			out["mirror_max_active"] = int(String(props[key]).to_int())
			break
	return out


func _parse_audio_props(props: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in ["ambience_stream", "stream_path", "audio_stream"]:
		if props.has(key):
			out["stream_path"] = String(props[key]).strip_edges()
			break
	for key in ["ambience_bus", "audio_bus", "bus"]:
		if props.has(key):
			out["bus"] = String(props[key]).strip_edges()
			break
	_apply_float_key(props, out, ["ambience_volume_db", "volume_db"], "volume_db")
	return out


func _parse_zone_props(props: Dictionary, scale_factor: float) -> Dictionary:
	var out: Dictionary = {}
	_apply_float_key(props, out, ["radius"], "radius")
	_apply_float_key(props, out, ["intensity"], "intensity")
	_apply_float_key(props, out, ["fog_density"], "fog_density")
	_apply_float_key(props, out, ["wind_speed"], "wind_speed")
	if props.has("origin"):
		var origin_v: Variant = _parse_vector3_string(String(props["origin"]))
		if origin_v != null:
			var origin_map: Vector3 = origin_v as Vector3
			out["origin"] = Vector3(origin_map.y, origin_map.z, origin_map.x) * scale_factor
	return out


func _apply_portal_budget_overrides() -> void:
	var portals: Array[Node] = get_tree().get_nodes_in_group("func_portal")
	for n in portals:
		if n == null:
			continue
		n.set("manager_max_active_portals", portal_budget_max_active)
		n.set("manager_refresh_seconds", portal_budget_refresh_seconds)
		n.set("render_scale", portal_budget_max_render_scale)
		n.set("dynamic_min_render_scale", portal_budget_min_render_scale)
		n.set("manager_min_runtime_priority", portal_budget_min_priority)
		if n.has_method("_on_properties_applied"):
			n.call("_on_properties_applied")
	var mirrors: Array[Node] = get_tree().get_nodes_in_group("func_mirror")
	for m in mirrors:
		if m == null:
			continue
		m.set("manager_max_active_mirrors", mirror_budget_max_active)
		m.set("manager_refresh_seconds", mirror_budget_refresh_seconds)
		m.set("render_scale", mirror_budget_render_scale)
		m.set("manager_min_runtime_priority", mirror_budget_min_priority)
		if m.has_method("_on_properties_applied"):
			m.call("_on_properties_applied")


func _apply_budget_profile_overrides() -> void:
	var mode: String = portal_budget_profile_mode.strip_edges().to_lower()
	match mode:
		"cinematic":
			portal_budget_max_active = 8
			portal_budget_refresh_seconds = minf(portal_budget_refresh_seconds, 0.10)
			portal_budget_max_render_scale = maxf(portal_budget_max_render_scale, 0.85)
			portal_budget_min_render_scale = maxf(portal_budget_min_render_scale, 0.60)
			portal_budget_min_priority = minf(portal_budget_min_priority, 0.05)
			mirror_budget_max_active = 4
			mirror_budget_refresh_seconds = minf(mirror_budget_refresh_seconds, 0.08)
			mirror_budget_render_scale = maxf(mirror_budget_render_scale, 0.85)
			mirror_budget_min_priority = minf(mirror_budget_min_priority, 0.05)
		"stress":
			portal_budget_max_active = 3
			portal_budget_refresh_seconds = minf(portal_budget_refresh_seconds, 0.10)
			portal_budget_max_render_scale = minf(portal_budget_max_render_scale, 0.60)
			portal_budget_min_render_scale = minf(portal_budget_min_render_scale, 0.25)
			portal_budget_min_priority = maxf(portal_budget_min_priority, 0.20)
			mirror_budget_max_active = 1
			mirror_budget_refresh_seconds = minf(mirror_budget_refresh_seconds, 0.08)
			mirror_budget_render_scale = minf(mirror_budget_render_scale, 0.60)
			mirror_budget_min_priority = maxf(mirror_budget_min_priority, 0.25)
		_:
			# balanced (default)
			portal_budget_max_active = mini(maxi(portal_budget_max_active, 4), 5)
			portal_budget_refresh_seconds = minf(portal_budget_refresh_seconds, 0.10)
			portal_budget_max_render_scale = minf(maxf(portal_budget_max_render_scale, 0.65), 0.75)
			portal_budget_min_render_scale = minf(maxf(portal_budget_min_render_scale, 0.35), 0.45)
			portal_budget_min_priority = maxf(portal_budget_min_priority, 0.14)
			mirror_budget_max_active = 2
			mirror_budget_refresh_seconds = minf(mirror_budget_refresh_seconds, 0.08)
			mirror_budget_render_scale = minf(maxf(mirror_budget_render_scale, 0.65), 0.75)
			mirror_budget_min_priority = maxf(mirror_budget_min_priority, 0.18)


func _apply_audio_settings() -> void:
	if _ambient_audio == null:
		return
	_ambient_audio.bus = audio_ambience_bus
	_ambient_audio.volume_db = audio_ambience_volume_db
	if audio_ambience_stream_path.is_empty():
		_ambient_audio.stop()
		_ambient_audio.stream = null
		return
	var stream_v: Variant = load(audio_ambience_stream_path)
	if stream_v is AudioStream:
		_ambient_audio.stream = stream_v as AudioStream
		if not _ambient_audio.playing:
			_ambient_audio.play()


func _parse_vector3_string(v: String) -> Variant:
	var cleaned: String = v.replace(",", " ").strip_edges()
	var parts := cleaned.split_floats(" ")
	if parts.size() < 3:
		return null
	return Vector3(parts[0], parts[1], parts[2])


func _apply_bool_key(src: Dictionary, dst: Dictionary, keys: Array[String], dst_key: String) -> void:
	for key in keys:
		if src.has(key):
			dst[dst_key] = _parse_bool(String(src[key]))
			return


func _apply_float_key(src: Dictionary, dst: Dictionary, keys: Array[String], dst_key: String) -> void:
	for key in keys:
		if src.has(key):
			dst[dst_key] = String(src[key]).to_float()
			return


func _parse_vector2_keys(src: Dictionary, keys: Array[String]) -> Variant:
	for key in keys:
		if not src.has(key):
			continue
		var parsed_vec: Variant = _parse_vector2_string(String(src[key]))
		if parsed_vec != null:
			return parsed_vec
	return null


func _parse_color_keys(src: Dictionary, keys: Array[String]) -> Variant:
	for key in keys:
		if not src.has(key):
			continue
		var parsed_color: Variant = _parse_color_string(String(src[key]))
		if parsed_color != null:
			return parsed_color
	return null


func _parse_bool(v: String) -> bool:
	var s := v.strip_edges().to_lower()
	return s == "1" or s == "true" or s == "yes" or s == "on"


func _parse_vector2_string(v: String) -> Variant:
	var cleaned := v.replace(",", " ").strip_edges()
	var parts := cleaned.split_floats(" ")
	if parts.size() < 2:
		return null
	return Vector2(parts[0], parts[1])


func _parse_color_string(v: String) -> Variant:
	var cleaned := v.replace(",", " ").strip_edges()
	var parts := cleaned.split_floats(" ")
	if parts.size() < 3:
		return null
	var r := parts[0]
	var g := parts[1]
	var b := parts[2]
	# Allow either 0..1 or 0..255 authored values.
	if r > 1.0 or g > 1.0 or b > 1.0:
		r /= 255.0
		g /= 255.0
		b /= 255.0
	return Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0), 1.0)
@tool
extends Node3D
const Util := preload("res://scripts/util.gd")

@export var visual_root_path: NodePath = NodePath("metarig")
@export var origin_to_feet_units: float = 24.0
@export var default_inverse_scale_factor: float = 32.0
@export var extra_offset: Vector3 = Vector3.ZERO
@export var idle_animation_name: String = "idle"
@export var idle_fallback_enabled: bool = true
@export_range(0.0, 0.2, 0.001) var idle_bob_amplitude: float = 0.02
@export_range(0.1, 8.0, 0.01) var idle_bob_frequency: float = 1.2
@export_range(0.0, 8.0, 0.01) var idle_sway_degrees: float = 3.0
@export_range(0.1, 8.0, 0.01) var idle_sway_frequency: float = 0.8

var _base_visual_position: Vector3 = Vector3.ZERO
var _aligned_visual_position: Vector3 = Vector3.ZERO
var _cached_base_position: bool = false
var _idle_visual_root: Node3D = null
var _base_visual_rotation: Vector3 = Vector3.ZERO
var _idle_phase: float = 0.0
var _has_animation_player: bool = false

func _ready() -> void:
	_apply_alignment()
	if Util.editor_hint():
		return
	_setup_idle_animation()

func _process(delta: float) -> void:
	if Util.editor_hint():
		return
	if _has_animation_player:
		return
	if not idle_fallback_enabled:
		return
	if _idle_visual_root == null:
		return
	_idle_phase += delta
	var bob_y: float = sin(_idle_phase * TAU * idle_bob_frequency) * idle_bob_amplitude
	var sway_y: float = sin((_idle_phase + 0.37) * TAU * idle_sway_frequency) * idle_sway_degrees
	var p: Vector3 = _aligned_visual_position
	p.y += bob_y
	_idle_visual_root.position = p
	var r: Vector3 = _base_visual_rotation
	r.y += sway_y
	_idle_visual_root.rotation_degrees = r

func _notification(what: int) -> void:
	if Util.editor_hint() and what == NOTIFICATION_ENTER_TREE:
		call_deferred("_apply_alignment")

func _apply_alignment() -> void:
	var visual_root: Node3D = get_node_or_null(visual_root_path) as Node3D
	if visual_root == null:
		return

	if not _cached_base_position:
		_base_visual_position = visual_root.position
		_cached_base_position = true

	var scale_factor: float = _find_map_scale_factor()
	var feet_offset: Vector3 = Vector3(0.0, -origin_to_feet_units * scale_factor, 0.0)
	_aligned_visual_position = _base_visual_position + feet_offset + extra_offset
	visual_root.position = _aligned_visual_position
	if _idle_visual_root == visual_root:
		_base_visual_rotation = visual_root.rotation_degrees

func _find_map_scale_factor() -> float:
	var current: Node = self
	while current != null:
		var map_settings: Variant = current.get("map_settings")
		if map_settings != null:
			var scale_value: Variant = map_settings.get("scale_factor")
			if scale_value is float:
				var scale_float: float = scale_value
				if scale_float > 0.0:
					return scale_float
			elif scale_value is int:
				var scale_int: int = scale_value
				if scale_int > 0:
					return float(scale_int)
		current = current.get_parent()

	if default_inverse_scale_factor <= 0.0:
		return 0.03125
	return 1.0 / default_inverse_scale_factor

func _setup_idle_animation() -> void:
	var visual_root: Node3D = get_node_or_null(visual_root_path) as Node3D
	_idle_visual_root = visual_root
	if _idle_visual_root == null:
		return
	_base_visual_rotation = _idle_visual_root.rotation_degrees
	_idle_phase = float(get_instance_id() % 360) * 0.0174533
	var anim_player: AnimationPlayer = _find_animation_player(self)
	if anim_player == null:
		_has_animation_player = false
		return
	var clip: String = _pick_idle_clip(anim_player)
	if clip == "":
		_has_animation_player = false
		return
	anim_player.play(clip)
	_has_animation_player = true

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	var children: Array = root.get_children()
	for child in children:
		var node_child: Node = child as Node
		if node_child == null:
			continue
		var found: AnimationPlayer = _find_animation_player(node_child)
		if found != null:
			return found
	return null

func _pick_idle_clip(anim_player: AnimationPlayer) -> String:
	if idle_animation_name != "" and anim_player.has_animation(idle_animation_name):
		return idle_animation_name
	var candidate_names: PackedStringArray = PackedStringArray([
		"idle",
		"Idle",
		"idle_loop",
		"IdleLoop",
		"Armature|Idle"
	])
	for candidate in candidate_names:
		if anim_player.has_animation(candidate):
			return candidate
	var names: PackedStringArray = anim_player.get_animation_list()
	for name in names:
		if name.to_lower().find("idle") != -1:
			return name
	return ""
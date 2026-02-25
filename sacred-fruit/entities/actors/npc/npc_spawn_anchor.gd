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
@export_range(0.2, 2.0, 0.01) var npc_visual_scale: float = 0.82
@export var ai_enabled: bool = false
@export var ai_route_id: String = "default"
@export_range(0.1, 20.0, 0.01) var ai_patrol_speed: float = 2.0
@export_range(0.0, 30.0, 0.01) var ai_alert_duration: float = 4.0
@export var ai_reacts_to_alerts: bool = true
@export var dialogue_enabled: bool = true
@export_file("*.json", "*.md", "*.markdown") var dialogue_resource_path: String = "res://data/dialogue/npc_default.md"
@export var dialogue_speaker_name: String = ""
@export var dialogue_once_flag: String = ""
@export_range(0.2, 3.0, 0.01) var dialogue_focus_height: float = 1.15
@export var dialogue_focus_bone_name: String = "spine.003"
@export_range(-0.5, 0.5, 0.01) var dialogue_focus_bone_offset: float = -0.06

var _base_visual_position: Vector3 = Vector3.ZERO
var _base_visual_scale: Vector3 = Vector3.ONE
var _aligned_visual_position: Vector3 = Vector3.ZERO
var _cached_base_position: bool = false
var _idle_visual_root: Node3D = null
var _base_visual_rotation: Vector3 = Vector3.ZERO
var _idle_phase: float = 0.0
var _has_animation_player: bool = false
var _ai_controller: Node = null
const AI_CONTROLLER_SCRIPT := preload("res://entities/logic/ai_controller.gd")

func _ready() -> void:
	_apply_alignment()
	if Util.editor_hint():
		return
	_setup_idle_animation()
	_setup_ai_controller()

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
		_base_visual_scale = visual_root.scale
		_cached_base_position = true

	var scale_factor: float = _find_map_scale_factor()
	var feet_offset: Vector3 = Vector3(0.0, -origin_to_feet_units * scale_factor, 0.0)
	_aligned_visual_position = _base_visual_position + feet_offset + extra_offset
	visual_root.position = _aligned_visual_position
	visual_root.scale = _base_visual_scale * maxf(npc_visual_scale, 0.01)
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

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("npc_visual_scale"):
		npc_visual_scale = clampf(float(props["npc_visual_scale"]), 0.2, 2.0)
	if props.has("ai_enabled"):
		ai_enabled = Util.to_bool(props["ai_enabled"], ai_enabled)
	if props.has("ai_route_id"):
		ai_route_id = String(props["ai_route_id"]).strip_edges()
	if props.has("ai_patrol_speed"):
		ai_patrol_speed = maxf(float(props["ai_patrol_speed"]), 0.1)
	if props.has("ai_alert_duration"):
		ai_alert_duration = maxf(float(props["ai_alert_duration"]), 0.0)
	if props.has("ai_reacts_to_alerts"):
		ai_reacts_to_alerts = Util.to_bool(props["ai_reacts_to_alerts"], ai_reacts_to_alerts)
	if props.has("dialogue_enabled"):
		dialogue_enabled = Util.to_bool(props["dialogue_enabled"], dialogue_enabled)
	if props.has("dialogue_resource_path"):
		dialogue_resource_path = String(props["dialogue_resource_path"]).strip_edges()
	if props.has("dialogue_speaker_name"):
		dialogue_speaker_name = String(props["dialogue_speaker_name"]).strip_edges()
	if props.has("dialogue_once_flag"):
		dialogue_once_flag = String(props["dialogue_once_flag"]).strip_edges()
	if props.has("dialogue_focus_height"):
		dialogue_focus_height = maxf(float(props["dialogue_focus_height"]), 0.2)
	if props.has("dialogue_focus_bone_name"):
		dialogue_focus_bone_name = String(props["dialogue_focus_bone_name"]).strip_edges()
	if props.has("dialogue_focus_bone_offset"):
		dialogue_focus_bone_offset = clampf(float(props["dialogue_focus_bone_offset"]), -0.5, 0.5)
	_apply_alignment()

func _setup_ai_controller() -> void:
	if not ai_enabled:
		return
	if AI_CONTROLLER_SCRIPT == null:
		return
	if _ai_controller != null and is_instance_valid(_ai_controller):
		return
	var ctrl := AI_CONTROLLER_SCRIPT.new()
	if ctrl == null:
		return
	ctrl.name = "AIController"
	if ctrl.has_method("setup"):
		ctrl.call("setup", self, {
			"enabled": ai_enabled,
			"route_id": ai_route_id,
			"patrol_speed": ai_patrol_speed,
			"alert_duration": ai_alert_duration,
			"reacts_to_alerts": ai_reacts_to_alerts
		})
	add_child(ctrl)
	_ai_controller = ctrl


func interact(activator: Node = null) -> bool:
	if Util.editor_hint():
		return false
	if not dialogue_enabled:
		return false
	if dialogue_resource_path.strip_edges().is_empty():
		return false

	var game: Node = get_node_or_null("/root/GAME")
	var once_key: String = dialogue_once_flag.strip_edges()
	if once_key != "" and game != null and game.has_method("state_has_fired"):
		if bool(game.call("state_has_fired", once_key)):
			return false

	var dialogue: Node = get_node_or_null("/root/DIALOGUE")
	if dialogue == null or not dialogue.has_method("start_dialogue_from_resource"):
		return false

	if activator != null and activator.has_method("_release_held_ball"):
		activator.call("_release_held_ball")

	var started_v: Variant = dialogue.call(
		"start_dialogue_from_resource",
		dialogue_resource_path,
		dialogue_speaker_name,
		activator,
		self
	)
	var started: bool = started_v is bool and bool(started_v)
	if started and once_key != "" and game != null and game.has_method("state_mark_fired"):
		game.call("state_mark_fired", once_key)
	return started


func use(activator: Node = null) -> void:
	interact(activator)


func get_dialogue_focus_point() -> Vector3:
	var skeleton: Skeleton3D = _find_dialogue_focus_skeleton()
	if skeleton != null:
		var bone_name: String = dialogue_focus_bone_name.strip_edges()
		if not bone_name.is_empty():
			var bone_idx: int = skeleton.find_bone(bone_name)
			if bone_idx >= 0:
				var bone_pose: Transform3D = skeleton.get_bone_global_pose(bone_idx)
				return skeleton.to_global(bone_pose.origin) + Vector3(0.0, dialogue_focus_bone_offset, 0.0)

	var visual_root: Node3D = get_node_or_null(visual_root_path) as Node3D
	if visual_root != null and is_instance_valid(visual_root):
		return visual_root.global_position + Vector3(0.0, dialogue_focus_height, 0.0)
	return global_position + Vector3(0.0, dialogue_focus_height, 0.0)


func _find_dialogue_focus_skeleton() -> Skeleton3D:
	var visual_root: Node3D = get_node_or_null(visual_root_path) as Node3D
	if visual_root != null and is_instance_valid(visual_root):
		var under_visual: Skeleton3D = visual_root.find_child("Skeleton3D", true, false) as Skeleton3D
		if under_visual != null:
			return under_visual
	return find_child("Skeleton3D", true, false) as Skeleton3D

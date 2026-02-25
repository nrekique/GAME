extends CharacterBody3D

signal health_changed(current: int, max_health: int, max_overhealth: int)
signal died

# Quake-ish health model
@export var max_health: int = 100
@export var max_overhealth: int = 200
@export var health: int = 100
@export var overheal_decay_per_sec: float = 5.0
@export var respawn_on_death: bool = true
@export var respawn_delay: float = 1.0

# Movement (HL2-grounded style)
@export var JUMP_HEIGHT: float = 1.0
@export var WALKING_SPEED: float = 4.5
@export var SPRINTING_SPEED: float = 7.5
@export var CROUCHING_SPEED: float = 2.2
@export var CROUCHING_DEPTH: float = -0.6
@export var GROUND_ACCELERATION: float = 22.0
@export var AIR_ACCELERATION: float = 6.0
@export var GROUND_FRICTION: float = 8.0
@export var STOP_SPEED: float = 1.8
@export var AIR_CONTROL: float = 0.22
@export var BUNNY_HOP_ACCELERATION: float = 0.12
@export var BUNNY_HOP_MAX_SPEED: float = 9.0
@export var WATER_MOVE_SPEED: float = 2.2
@export var WATER_ACCELERATION: float = 8.0
@export var WATER_DRAG: float = 3.5
@export var WATER_GRAVITY_SCALE: float = 0.22
@export var WATER_MAX_FALL_SPEED: float = 2.4
@export var WATER_SWIM_UP_SPEED: float = 3.0
@export var WATER_SWIM_DOWN_SPEED: float = 2.6
@export var WATER_IDLE_SINK_SPEED: float = 0.6
@export_range(0.0, 20.0, 0.1) var RIGIDBODY_PUSH_FORCE: float = 6.0
@export_range(0.0, 4.0, 0.01) var RIGIDBODY_MAX_PUSH_IMPULSE: float = 1.2
@export_range(0.0, 2.0, 0.01) var RIGIDBODY_PUSH_MIN_SPEED: float = 0.25
@export_range(0.0, 2.0, 0.01) var RIGIDBODY_PUSH_MASS_FACTOR: float = 0.35

# Look/feel
@export var MOUSE_SENS: float = 0.25
@export var MOUSE_SMOOTHING: float = 0.0
@export var GAMEPLAY_FOV: float = 90.0
@export var FOV_MIN: float = 75.0
@export var FOV_MAX: float = 110.0
@export var LERP_SPEED: float = 10.0
@export var AIR_LERP_SPEED: float = 6.0

# Camera grounding
@export var BOB_WALK_FREQ: float = 10.0
@export var BOB_SPRINT_FREQ: float = 14.0
@export var BOB_CROUCH_FREQ: float = 7.0
@export var BOB_WALK_INTENSITY: float = 0.025
@export var BOB_SPRINT_INTENSITY: float = 0.038
@export var BOB_CROUCH_INTENSITY: float = 0.014
@export var LANDING_DIP_SCALE: float = 0.012
@export var LANDING_DIP_MAX: float = 0.08
@export var LANDING_DIP_RECOVER: float = 9.0
@export var CAMERA_ROLL_ENABLED: bool = false
@export var SWAY_ROLL_MAX_DEG: float = 1.6
@export var SWAY_ROLL_SPEED: float = 8.0
@export var SWAY_STRAFE_SCALE: float = 0.015
@export_range(0.5, 8.0, 0.1) var INTERACT_DISTANCE: float = 3.2
@export_range(0.3, 5.0, 0.1) var HOLD_DISTANCE: float = 1.8
@export_range(0.0, 30.0, 0.1) var DROP_THROW_SPEED: float = 7.0
@export_range(0.0, 60.0, 0.1) var PUNT_THROW_SPEED: float = 15.0
@export var show_interact_crosshair: bool = true
@export_range(1.0, 12.0, 1.0) var crosshair_dot_size: float = 4.0
@export var crosshair_idle_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var crosshair_target_color: Color = Color(0.65, 1.0, 0.65, 0.95)
@export var crosshair_holding_color: Color = Color(1.0, 0.85, 0.45, 0.95)
@export var dialogue_cinematic_enabled: bool = true
@export_range(0.0, 0.6, 0.01) var dialogue_camera_shoulder_offset: float = 0.14
@export_range(-0.4, 0.4, 0.01) var dialogue_camera_vertical_offset: float = -0.12
@export_range(20.0, 120.0, 0.1) var dialogue_camera_fov: float = 78.0
@export_range(0.0, 4.0, 0.01) var dialogue_focus_height_offset: float = 1.05
@export_range(1.0, 20.0, 0.1) var dialogue_focus_lerp_speed: float = 8.0
@export_range(5.0, 85.0, 0.1) var dialogue_max_head_pitch_deg: float = 50.0

# Feel helpers
@export var COYOTE_TIME: float = 0.12
@export var JUMP_BUFFER: float = 0.12

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var direction: Vector3 = Vector3.ZERO
var current_speed: float = WALKING_SPEED
var bunny_hop_speed: float = SPRINTING_SPEED

var is_walking: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _was_on_floor: bool = false
var _water_volume_contacts: int = 0

var _mouse_delta_accum: Vector2 = Vector2.ZERO
var _mouse_delta_filtered: Vector2 = Vector2.ZERO
var _last_frame_mouse_delta: Vector2 = Vector2.ZERO

var _bob_phase: float = 0.0
var _landing_dip: float = 0.0
var _camera_roll: float = 0.0
var _dialogue_focus_active: bool = false
var _dialogue_focus_target: Node3D = null
var _dialogue_base_camera_local_position: Vector3 = Vector3.ZERO
var _dialogue_base_camera_local_rotation: Vector3 = Vector3.ZERO
var _dialogue_focus_blend: float = 0.0

@onready var _neck: Node3D = $Neck
@onready var _head: Node3D = $Neck/Head
@onready var _eyes: Node3D = $Neck/Head/Eyes
@onready var _camera: Camera3D = $Neck/Head/Eyes/Camera
@onready var _standing_collision: CollisionShape3D = $StandingCollisionShape
@onready var _crouching_collision: CollisionShape3D = $CrouchingCollisionShape
@onready var _headroom_raycast: RayCast3D = $RayCast
@onready var _anim_player: AnimationPlayer = $Neck/Head/Eyes/AnimationPlayer

var _held_ball: PhysicsBall = null
var _current_interaction_target: Node = null
var _crosshair_layer: CanvasLayer = null
var _crosshair_dot: ColorRect = null
var _portal_source_camera: Camera3D = null


func _ready() -> void:
	add_to_group("PLAYER")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_ensure_use_input_action()
	_ensure_throw_input_action()
	_ensure_interact_crosshair()
	_ensure_portal_source_camera()
	_sync_portal_source_camera_from_game_camera()
	if _camera != null:
		_dialogue_base_camera_local_position = _camera.position
		_dialogue_base_camera_local_rotation = _camera.rotation

	var settings := get_node_or_null("/root/SETTINGS")
	if settings != null:
		_apply_settings_from_singleton(settings)
		if settings.has_signal("settings_applied"):
			settings.settings_applied.connect(_on_settings_applied)

	var game := get_node_or_null("/root/GAME")
	if game != null and game.has_method("register_player"):
		game.call("register_player", self)

	_emit_health_changed()


func _on_settings_applied() -> void:
	var settings := get_node_or_null("/root/SETTINGS")
	if settings != null:
		_apply_settings_from_singleton(settings)


func _apply_settings_from_singleton(settings: Node) -> void:
	if "mouse_sens" in settings:
		MOUSE_SENS = float(settings.mouse_sens)
	if "mouse_smoothing" in settings:
		MOUSE_SMOOTHING = clampf(float(settings.mouse_smoothing), 0.0, 0.25)
	if "gameplay_fov" in settings:
		GAMEPLAY_FOV = clampf(float(settings.gameplay_fov), FOV_MIN, FOV_MAX)
	if _camera != null:
		_camera.fov = GAMEPLAY_FOV
	_sync_portal_source_camera_from_game_camera()


func _input(event: InputEvent) -> void:
	if _is_dialogue_active():
		return
	if event is InputEventMouseMotion:
		_mouse_delta_accum += event.relative


func _physics_process(delta: float) -> void:
	var was_on_floor: bool = _was_on_floor
	var on_floor: bool = is_on_floor()
	var in_water: bool = _is_in_water_volume()
	var dialogue_active: bool = _is_dialogue_active()
	if dialogue_active:
		velocity = Vector3.ZERO
		_mouse_delta_accum = Vector2.ZERO
		_mouse_delta_filtered = Vector2.ZERO
		_last_frame_mouse_delta = Vector2.ZERO
		_update_dialogue_focus(delta)
		_sync_portal_source_camera_from_game_camera()
		_update_interaction_target()
		_update_interact_crosshair()
		return
	if _dialogue_focus_active:
		end_dialogue_focus()

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = JUMP_BUFFER
	else:
		_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

	if on_floor:
		_coyote_left = COYOTE_TIME
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)

	_update_crouch_state(delta, in_water)
	_apply_look(delta)

	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "back")
	var wish_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)

	_update_move_state(input_dir, in_water)
	var target_speed: float = _target_speed(in_water)
	current_speed = lerpf(current_speed, target_speed, clampf(delta * 8.0, 0.0, 1.0))

	if in_water:
		horizontal_vel = _apply_water_drag(horizontal_vel, delta)
		horizontal_vel = _accelerate(horizontal_vel, wish_dir, current_speed, WATER_ACCELERATION, delta)
	elif on_floor:
		horizontal_vel = _apply_friction(horizontal_vel, delta)
		horizontal_vel = _accelerate(horizontal_vel, wish_dir, current_speed, GROUND_ACCELERATION, delta)
	else:
		horizontal_vel = _accelerate(horizontal_vel, wish_dir, current_speed, AIR_ACCELERATION, delta)
		horizontal_vel = _air_control(horizontal_vel, wish_dir, input_dir.y, current_speed, delta)

	if in_water:
		_apply_water_vertical_motion(delta)
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
	elif not on_floor:
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.01

	if in_water:
		bunny_hop_speed = SPRINTING_SPEED
	elif _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = sqrt(2.0 * gravity * maxf(JUMP_HEIGHT, 0.01))
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		if is_sprinting and input_dir.length() > 0.0:
			bunny_hop_speed = minf(maxf(bunny_hop_speed, SPRINTING_SPEED) + BUNNY_HOP_ACCELERATION, BUNNY_HOP_MAX_SPEED)
		else:
			bunny_hop_speed = SPRINTING_SPEED
		if _anim_player != null:
			_anim_player.play("jump")
	elif on_floor and not is_sprinting:
		bunny_hop_speed = SPRINTING_SPEED

	velocity.x = horizontal_vel.x
	velocity.z = horizontal_vel.z

	var pre_move_velocity_y: float = velocity.y
	move_and_slide()
	_was_on_floor = is_on_floor()
	_push_rigid_bodies_from_collisions(delta)

	if _was_on_floor and not was_on_floor and not in_water:
		var impact_speed: float = -pre_move_velocity_y
		if impact_speed > 0.0:
			_landing_dip = minf(LANDING_DIP_MAX, impact_speed * LANDING_DIP_SCALE)
		if impact_speed >= 5.0 and _anim_player != null:
			_anim_player.play("landing")

	_apply_camera_grounding(delta, was_on_floor)
	_sync_portal_source_camera_from_game_camera()
	_update_held_ball()
	_update_interaction_target()
	_update_interact_crosshair()

	if health > max_health and overheal_decay_per_sec > 0.0:
		var new_health := maxf(float(max_health), float(health) - overheal_decay_per_sec * delta)
		var rounded := int(floor(new_health + 0.5))
		if rounded != health:
			health = rounded
			_emit_health_changed()
	if InputMap.has_action("use") and Input.is_action_just_pressed("use"):
		_handle_interact_pressed()
	if InputMap.has_action("throw_held") and Input.is_action_just_pressed("throw_held"):
		_handle_throw_pressed()


func _update_crouch_state(delta: float, in_water: bool = false) -> void:
	var wants_crouch: bool = false if in_water else Input.is_action_pressed("crouch")
	if not in_water and not wants_crouch and _headroom_raycast.is_colliding():
		wants_crouch = true

	is_crouching = wants_crouch
	_standing_collision.disabled = wants_crouch
	_crouching_collision.disabled = not wants_crouch

	var target_head_y: float = CROUCHING_DEPTH if wants_crouch else 0.0
	_head.position.y = lerpf(_head.position.y, target_head_y, clampf(delta * LERP_SPEED, 0.0, 1.0))


func _apply_look(delta: float) -> void:
	var raw: Vector2 = _mouse_delta_accum
	_mouse_delta_accum = Vector2.ZERO

	if MOUSE_SMOOTHING <= 0.001:
		_mouse_delta_filtered = raw
	else:
		# Convert 0.00-0.25 slider to a stable smoothing rate.
		var smooth_t: float = clampf(delta / MOUSE_SMOOTHING, 0.0, 1.0)
		_mouse_delta_filtered = _mouse_delta_filtered.lerp(raw, smooth_t)

	_last_frame_mouse_delta = _mouse_delta_filtered

	rotate_y(deg_to_rad(-_mouse_delta_filtered.x * MOUSE_SENS))
	_head.rotate_x(deg_to_rad(-_mouse_delta_filtered.y * MOUSE_SENS))
	_head.rotation.x = clamp(_head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))


func _update_move_state(input_dir: Vector2, in_water: bool = false) -> void:
	is_sprinting = (not in_water) and Input.is_action_pressed("sprint") and (not is_crouching)
	is_walking = (not is_sprinting) and (not is_crouching)
	if input_dir.length() <= 0.001:
		is_sprinting = false


func _target_speed(in_water: bool = false) -> float:
	if in_water:
		return WATER_MOVE_SPEED
	if is_crouching:
		return CROUCHING_SPEED
	if is_sprinting:
		return maxf(SPRINTING_SPEED, bunny_hop_speed)
	return WALKING_SPEED


func _apply_water_drag(horizontal_vel: Vector3, delta: float) -> Vector3:
	var drag_t: float = clampf(WATER_DRAG * delta, 0.0, 1.0)
	return horizontal_vel.lerp(Vector3.ZERO, drag_t)


func _apply_water_vertical_motion(delta: float) -> void:
	var wants_up: bool = Input.is_action_pressed("jump")
	var wants_down: bool = Input.is_action_pressed("crouch")
	var target_vertical: float = -WATER_IDLE_SINK_SPEED
	if wants_up and not wants_down:
		target_vertical = WATER_SWIM_UP_SPEED
	elif wants_down and not wants_up:
		target_vertical = -WATER_SWIM_DOWN_SPEED
	var blend: float = clampf(delta * 6.0, 0.0, 1.0)
	velocity.y = lerpf(velocity.y, target_vertical, blend)
	if not wants_up:
		velocity.y -= gravity * WATER_GRAVITY_SCALE * delta
	velocity.y = maxf(velocity.y, -WATER_MAX_FALL_SPEED)


func _push_rigid_bodies_from_collisions(delta: float) -> void:
	if delta <= 0.0:
		return
	var movement_push: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = movement_push.length()
	if speed < RIGIDBODY_PUSH_MIN_SPEED:
		return
	var base_impulse: float = speed * RIGIDBODY_PUSH_FORCE * delta
	if base_impulse <= 0.0001:
		return

	var hit_count: int = get_slide_collision_count()
	for i in range(hit_count):
		var hit: KinematicCollision3D = get_slide_collision(i)
		if hit == null:
			continue
		var collider_v: Variant = hit.get_collider()
		var body: RigidBody3D = collider_v as RigidBody3D
		if body == null or not is_instance_valid(body):
			continue
		if body.freeze:
			continue
		if _held_ball != null and body == _held_ball:
			continue

		var normal: Vector3 = hit.get_normal()
		var push_dir: Vector3 = movement_push - normal * movement_push.dot(normal)
		push_dir.y = 0.0
		if push_dir.length_squared() <= 0.000001:
			push_dir = Vector3(-normal.x, 0.0, -normal.z)
		if push_dir.length_squared() <= 0.000001:
			continue

		var mass_factor: float = 1.0 / (1.0 + maxf(body.mass - 1.0, 0.0) * RIGIDBODY_PUSH_MASS_FACTOR)
		var impulse_mag: float = clampf(base_impulse * mass_factor, 0.0, RIGIDBODY_MAX_PUSH_IMPULSE)
		if impulse_mag <= 0.0001:
			continue

		body.sleeping = false
		body.apply_central_impulse(push_dir.normalized() * impulse_mag)


func _apply_friction(horizontal_vel: Vector3, delta: float) -> Vector3:
	var speed: float = horizontal_vel.length()
	if speed <= 0.0001:
		return Vector3.ZERO
	var control: float = maxf(speed, STOP_SPEED)
	var drop: float = control * GROUND_FRICTION * delta
	var new_speed: float = maxf(speed - drop, 0.0)
	if new_speed == speed:
		return horizontal_vel
	return horizontal_vel * (new_speed / speed)


func _accelerate(horizontal_vel: Vector3, wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> Vector3:
	if wish_dir.length_squared() <= 0.000001:
		return horizontal_vel
	var current_speed_along_wish: float = horizontal_vel.dot(wish_dir)
	var add_speed: float = wish_speed - current_speed_along_wish
	if add_speed <= 0.0:
		return horizontal_vel
	var accel_speed: float = accel * delta * wish_speed
	if accel_speed > add_speed:
		accel_speed = add_speed
	return horizontal_vel + wish_dir * accel_speed


func _air_control(horizontal_vel: Vector3, wish_dir: Vector3, forward_move: float, wish_speed: float, delta: float) -> Vector3:
	if absf(forward_move) < 0.001 or wish_speed <= 0.0:
		return horizontal_vel
	var z_speed: float = horizontal_vel.y
	horizontal_vel.y = 0.0
	var speed: float = horizontal_vel.length()
	if speed <= 0.0001:
		horizontal_vel.y = z_speed
		return horizontal_vel
	horizontal_vel = horizontal_vel.normalized()
	var dot_val: float = horizontal_vel.dot(wish_dir)
	var k: float = 32.0 * AIR_CONTROL * dot_val * dot_val * delta
	if dot_val > 0.0:
		horizontal_vel = (horizontal_vel * speed + wish_dir * k).normalized()
		horizontal_vel *= speed
	horizontal_vel.y = z_speed
	return horizontal_vel


func _apply_camera_grounding(delta: float, was_on_floor: bool) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var speed_ratio: float = clampf(horizontal_speed / maxf(SPRINTING_SPEED, 0.001), 0.0, 1.0)

	_landing_dip = lerpf(_landing_dip, 0.0, clampf(delta * LANDING_DIP_RECOVER, 0.0, 1.0))

	var bob_freq: float = BOB_WALK_FREQ
	var bob_intensity: float = BOB_WALK_INTENSITY
	if is_crouching:
		bob_freq = BOB_CROUCH_FREQ
		bob_intensity = BOB_CROUCH_INTENSITY
	elif is_sprinting:
		bob_freq = BOB_SPRINT_FREQ
		bob_intensity = BOB_SPRINT_INTENSITY

	if _was_on_floor and horizontal_speed > 0.1:
		_bob_phase += delta * bob_freq * (0.6 + speed_ratio)

	var bob_x: float = sin(_bob_phase * 0.5) * bob_intensity
	var bob_y: float = absf(sin(_bob_phase)) * bob_intensity * 0.6
	if not _was_on_floor:
		bob_x = 0.0
		bob_y = 0.0

	var target_eye_pos := Vector3(bob_x, bob_y - _landing_dip, 0.0)
	_eyes.position = _eyes.position.lerp(target_eye_pos, clampf(delta * (LERP_SPEED + 2.0), 0.0, 1.0))

	var target_roll: float = 0.0
	if CAMERA_ROLL_ENABLED:
		var local_vel: Vector3 = global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
		var strafe_roll: float = clampf(-local_vel.x * SWAY_STRAFE_SCALE, deg_to_rad(-SWAY_ROLL_MAX_DEG), deg_to_rad(SWAY_ROLL_MAX_DEG))
		var mouse_roll: float = clampf(-_last_frame_mouse_delta.x * 0.0006, deg_to_rad(-SWAY_ROLL_MAX_DEG), deg_to_rad(SWAY_ROLL_MAX_DEG))
		target_roll = strafe_roll + mouse_roll
	_camera_roll = lerpf(_camera_roll, target_roll, clampf(delta * SWAY_ROLL_SPEED, 0.0, 1.0))
	_camera.rotation.z = _camera_roll

	if _camera != null:
		_camera.fov = GAMEPLAY_FOV


func begin_dialogue_focus(target: Node = null) -> void:
	if not dialogue_cinematic_enabled:
		return
	if _camera == null or not is_instance_valid(_camera):
		return
	_dialogue_focus_target = target as Node3D
	_dialogue_base_camera_local_position = _camera.position
	_dialogue_base_camera_local_rotation = _camera.rotation
	_dialogue_focus_blend = 0.0
	_dialogue_focus_active = true


func end_dialogue_focus() -> void:
	_dialogue_focus_active = false
	_dialogue_focus_target = null
	_dialogue_focus_blend = 0.0
	if _camera != null and is_instance_valid(_camera):
		_camera.position = _dialogue_base_camera_local_position
		_camera.rotation = _dialogue_base_camera_local_rotation
		_camera.rotation.z = 0.0
		_camera.fov = GAMEPLAY_FOV
	_camera_roll = 0.0


func _update_dialogue_focus(delta: float) -> void:
	if not _dialogue_focus_active:
		return
	if _camera == null or not is_instance_valid(_camera):
		return
	var speed: float = clampf(dialogue_focus_lerp_speed, 1.0, 20.0)
	var t: float = clampf(delta * speed, 0.0, 1.0)
	_dialogue_focus_blend = minf(1.0, _dialogue_focus_blend + t)

	var target_point: Vector3 = _resolve_dialogue_focus_point()
	var to_target: Vector3 = target_point - _camera.global_position
	if to_target.length_squared() > 0.0001:
		var flat: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
		if flat.length_squared() > 0.0001:
			var desired_yaw: float = atan2(-flat.x, -flat.z)
			rotation.y = lerp_angle(rotation.y, desired_yaw, t)
		var flat_len: float = maxf(flat.length(), 0.0001)
		var desired_pitch: float = -atan2(to_target.y, flat_len)
		var max_pitch: float = deg_to_rad(dialogue_max_head_pitch_deg)
		_head.rotation.x = lerp_angle(_head.rotation.x, clampf(desired_pitch, -max_pitch, max_pitch), t)
		_head.rotation.x = clampf(_head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	var blend: float = smoothstep(0.0, 1.0, _dialogue_focus_blend)
	var offset := Vector3(dialogue_camera_shoulder_offset, dialogue_camera_vertical_offset, 0.0) * blend
	var desired_camera_local: Vector3 = _dialogue_base_camera_local_position + offset
	_camera.position = _camera.position.lerp(desired_camera_local, t)
	_camera.rotation.z = lerpf(_camera.rotation.z, 0.0, t)
	_camera.fov = lerpf(_camera.fov, clampf(dialogue_camera_fov, FOV_MIN, FOV_MAX), t)


func _resolve_dialogue_focus_point() -> Vector3:
	if _dialogue_focus_target != null and is_instance_valid(_dialogue_focus_target):
		if _dialogue_focus_target.has_method("get_dialogue_focus_point"):
			var focus_v: Variant = _dialogue_focus_target.call("get_dialogue_focus_point")
			if focus_v is Vector3:
				return focus_v
		return _dialogue_focus_target.global_position + Vector3(0.0, dialogue_focus_height_offset, 0.0)
	if _camera != null and is_instance_valid(_camera):
		return _camera.global_position + (-_camera.global_basis.z.normalized() * 3.0)
	return global_position + (-global_basis.z.normalized() * 3.0)


func _on_sliding_timer_timeout() -> void:
	# Legacy signal kept for scene compatibility.
	pass


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	# Legacy signal kept for scene compatibility.
	pass


func get_portal_source_camera() -> Camera3D:
	if _portal_source_camera != null and is_instance_valid(_portal_source_camera):
		return _portal_source_camera
	return _camera


func _ensure_portal_source_camera() -> void:
	if _portal_source_camera != null and is_instance_valid(_portal_source_camera):
		return
	if _head == null:
		return
	_portal_source_camera = Camera3D.new()
	_portal_source_camera.name = "PortalSourceCamera"
	_portal_source_camera.current = false
	_portal_source_camera.transform = Transform3D.IDENTITY
	_head.add_child(_portal_source_camera)


func _sync_portal_source_camera_from_game_camera() -> void:
	if _camera == null:
		return
	_ensure_portal_source_camera()
	if _portal_source_camera == null or not is_instance_valid(_portal_source_camera):
		return
	_portal_source_camera.fov = _camera.fov
	_portal_source_camera.near = _camera.near
	_portal_source_camera.far = _camera.far
	_portal_source_camera.keep_aspect = _camera.keep_aspect
	_portal_source_camera.cull_mask = _camera.cull_mask
	_portal_source_camera.environment = _camera.environment
	_portal_source_camera.attributes = _camera.attributes
	# Keep seam-parallax in sync with the player's true camera position,
	# but avoid view roll wobble by taking rotation from the head rig.
	_portal_source_camera.global_position = _camera.global_position
	if _head != null and is_instance_valid(_head):
		_portal_source_camera.global_basis = _head.global_basis
	else:
		_portal_source_camera.global_basis = _camera.global_basis


func add_health(amount: int, allow_overheal: bool = false, overheal_cap: int = 0) -> void:
	if amount <= 0:
		return
	var cap := max_health
	if allow_overheal:
		cap = max_overhealth
		if overheal_cap > 0:
			cap = min(cap, overheal_cap)
	health = clampi(health + amount, 0, cap)
	_emit_health_changed()


func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	health = maxi(0, int(floor(float(health) - amount + 0.5)))
	_emit_health_changed()
	if health <= 0:
		die()


func reset_health() -> void:
	health = max_health
	_emit_health_changed()


func die() -> void:
	if health > 0:
		health = 0
	_emit_health_changed()
	emit_signal("died")

	if not respawn_on_death:
		return
	# Ask GAME to respawn us (keeps logic centralized).
	var game := get_node_or_null("/root/GAME")
	if game != null and game.has_method("handle_player_death"):
		game.call("handle_player_death", self, respawn_delay)


func _emit_health_changed() -> void:
	emit_signal("health_changed", health, max_health, max_overhealth)


func _ensure_use_input_action() -> void:
	if InputMap.has_action("use"):
		return
	InputMap.add_action("use", 0.2)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("use", ev)


func _ensure_throw_input_action() -> void:
	if InputMap.has_action("throw_held"):
		return
	InputMap.add_action("throw_held", 0.2)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("throw_held", ev)


func _handle_interact_pressed() -> void:
	if _is_dialogue_active():
		return
	if _held_ball != null and is_instance_valid(_held_ball):
		_release_held_ball()
		return
	var target_node: Node = _current_interaction_target
	if target_node != null and not is_instance_valid(target_node):
		target_node = null
	if target_node == null:
		target_node = _find_interaction_target()
	if target_node == null:
		return
	if target_node.has_method("interact"):
		var result: Variant = target_node.call("interact", self)
		if result is bool and not bool(result):
			return
		if target_node is PhysicsBall and (target_node as PhysicsBall).is_held_by(self):
			_held_ball = target_node as PhysicsBall
		return
	if target_node.has_method("use"):
		target_node.call("use")


func _handle_throw_pressed() -> void:
	if _is_dialogue_active():
		return
	if _held_ball == null:
		return
	if not is_instance_valid(_held_ball) or not _held_ball.is_held_by(self):
		_held_ball = null
		return
	_throw_held_ball()


func _find_interaction_target() -> Node:
	if _camera == null:
		return null
	var world: World3D = _camera.get_world_3d()
	if world == null:
		return null
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from + (-_camera.global_basis.z.normalized() * INTERACT_DISTANCE)
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.exclude = [self.get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return null
	var collider_v: Variant = hit.get("collider", null)
	if collider_v == null:
		return null
	var n: Node = collider_v as Node
	if n == null:
		return null
	var cur: Node = n
	while cur != null:
		if cur.has_method("interact") or cur.has_method("use"):
			return cur
		cur = cur.get_parent()
	return null


func _update_interaction_target() -> void:
	if _held_ball != null and is_instance_valid(_held_ball) and _held_ball.is_held_by(self):
		_current_interaction_target = _held_ball
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		_current_interaction_target = null
		return
	_current_interaction_target = _find_interaction_target()


func _update_held_ball() -> void:
	if _held_ball == null:
		return
	if not is_instance_valid(_held_ball) or not _held_ball.is_held_by(self):
		_held_ball = null
		return
	var hold_target: Vector3 = _camera.global_position + (-_camera.global_basis.z.normalized() * HOLD_DISTANCE)
	_held_ball.set_hold_target_position(hold_target)


func _release_held_ball() -> void:
	if _held_ball == null or not is_instance_valid(_held_ball):
		_held_ball = null
		return
	var drop_vel: Vector3 = -_camera.global_basis.z.normalized() * DROP_THROW_SPEED
	_held_ball.drop(drop_vel)
	_held_ball = null


func _throw_held_ball() -> void:
	if _held_ball == null or not is_instance_valid(_held_ball):
		_held_ball = null
		return
	var throw_vel: Vector3 = -_camera.global_basis.z.normalized() * PUNT_THROW_SPEED
	_held_ball.drop(throw_vel)
	_held_ball = null


func on_teleport(portal: Node) -> void:
	if _held_ball == null:
		return
	if not is_instance_valid(_held_ball) or not _held_ball.is_held_by(self):
		_held_ball = null
		return
	var hold_target: Vector3
	if _camera != null and is_instance_valid(_camera):
		hold_target = _camera.global_position + (-_camera.global_basis.z.normalized() * HOLD_DISTANCE)
	else:
		hold_target = global_position + (-global_basis.z.normalized() * HOLD_DISTANCE)
	_held_ball.sync_after_holder_teleport(portal, hold_target, true)


func _ensure_interact_crosshair() -> void:
	if not show_interact_crosshair:
		return
	if _crosshair_layer != null and is_instance_valid(_crosshair_layer):
		return
	_crosshair_layer = CanvasLayer.new()
	_crosshair_layer.name = "InteractCrosshair"
	_crosshair_layer.layer = 10
	add_child(_crosshair_layer)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_layer.add_child(root)

	_crosshair_dot = ColorRect.new()
	_crosshair_dot.name = "Dot"
	_crosshair_dot.color = crosshair_idle_color
	_crosshair_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair_dot)
	_set_crosshair_dot_size(crosshair_dot_size)


func _set_crosshair_dot_size(size_px: float) -> void:
	if _crosshair_dot == null:
		return
	var s: float = maxf(size_px, 1.0)
	_crosshair_dot.anchor_left = 0.5
	_crosshair_dot.anchor_top = 0.5
	_crosshair_dot.anchor_right = 0.5
	_crosshair_dot.anchor_bottom = 0.5
	_crosshair_dot.offset_left = -s * 0.5
	_crosshair_dot.offset_top = -s * 0.5
	_crosshair_dot.offset_right = s * 0.5
	_crosshair_dot.offset_bottom = s * 0.5


func _update_interact_crosshair() -> void:
	if _crosshair_layer == null or _crosshair_dot == null:
		return
	var active: bool = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	_crosshair_layer.visible = active
	if not active:
		return
	if _held_ball != null and is_instance_valid(_held_ball) and _held_ball.is_held_by(self):
		_crosshair_dot.color = crosshair_holding_color
		_set_crosshair_dot_size(crosshair_dot_size + 1.0)
	elif _current_interaction_target != null:
		_crosshair_dot.color = crosshair_target_color
		_set_crosshair_dot_size(crosshair_dot_size + 1.0)
	else:
		_crosshair_dot.color = crosshair_idle_color
		_set_crosshair_dot_size(crosshair_dot_size)


func set_water_volume_state(entered: bool) -> void:
	if entered:
		_water_volume_contacts += 1
	else:
		_water_volume_contacts = maxi(0, _water_volume_contacts - 1)


func on_water_volume_state_changed(_volume: Node, entered: bool, _settings: Dictionary = {}) -> void:
	set_water_volume_state(entered)


func _is_in_water_volume() -> bool:
	return _water_volume_contacts > 0


func _is_dialogue_active() -> bool:
	var dialogue: Node = get_node_or_null("/root/DIALOGUE")
	if dialogue == null or not dialogue.has_method("is_dialogue_active"):
		return false
	var active_v: Variant = dialogue.call("is_dialogue_active")
	return active_v is bool and bool(active_v)

extends Sprite3D
class_name EnvSprite

## Billboard sprite entity for Half-Life style decorative elements like foliage, particles, etc.
## Always faces the camera

@export var properties: Dictionary :
	set(new_properties):
		if properties != new_properties:
			properties = new_properties
			_update_properties()

@export var sprite_texture: Texture2D
@export var sprite_scale: float = 1.0
@export var sprite_modulate: Color = Color.WHITE
@export var sprite_transparent: bool = true
@export var sprite_shaded: bool = false
@export var sprite_double_sided: bool = false
@export var sprite_billboard: int = 1  # 0=disabled, 1=enabled, 2=y-billboard
@export var sprite_animated: bool = false
@export var sprite_frames: int = 1
@export var sprite_framerate: float = 10.0

var _frame_timer: float = 0.0
var _current_frame: int = 0

func _ready() -> void:
	_update_properties()

func _process(delta: float) -> void:
	if sprite_animated and sprite_frames > 1:
		_frame_timer += delta
		if _frame_timer >= 1.0 / sprite_framerate:
			_frame_timer = 0.0
			_current_frame = (_current_frame + 1) % sprite_frames
			_update_animation_frame()

func _update_properties() -> void:
	# Texture
	if 'texture' in properties:
		var tex_path: String = properties['texture']
		if not tex_path.begins_with("res://"):
			tex_path = "res://tb/textures/" + tex_path + ".png"
		if ResourceLoader.exists(tex_path):
			sprite_texture = load(tex_path)
			texture = sprite_texture
	
	# Scale
	if 'scale' in properties:
		if properties['scale'] is float or properties['scale'] is int:
			sprite_scale = float(properties['scale'])
			pixel_size = 0.03125 * sprite_scale  # TrenchBroom -> Godot scale
		elif properties['scale'] is Vector3:
			var scale_vec: Vector3 = properties['scale']
			sprite_scale = (scale_vec.x + scale_vec.y + scale_vec.z) / 3.0
			pixel_size = 0.03125 * sprite_scale
	
	# Color modulation
	if '_color' in properties:
		sprite_modulate = properties['_color']
		modulate = sprite_modulate
	
	# Transparency
	if 'transparent' in properties:
		sprite_transparent = bool(properties['transparent'])
	
	transparency = 1.0 if sprite_transparent else 0.0
	
	# Shading
	if 'shaded' in properties:
		sprite_shaded = bool(properties['shaded'])
	
	shaded = sprite_shaded
	
	# Double-sided
	if 'double_sided' in properties:
		sprite_double_sided = bool(properties['double_sided'])
	
	double_sided = sprite_double_sided
	
	# Billboard mode
	if 'billboard' in properties:
		sprite_billboard = int(properties['billboard'])
	
	match sprite_billboard:
		0:
			billboard = BaseMaterial3D.BILLBOARD_DISABLED
		1:
			billboard = BaseMaterial3D.BILLBOARD_ENABLED
		2:
			billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_:
			billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Animation
	if 'frames' in properties:
		sprite_frames = max(1, int(properties['frames']))
		if sprite_frames > 1:
			sprite_animated = true
			hframes = sprite_frames
	
	if 'framerate' in properties:
		sprite_framerate = max(0.1, float(properties['framerate']))
	
	# Render layers
	if 'render_layer' in properties:
		layers = int(properties['render_layer'])
	
	# Alpha scissor
	if 'alpha_scissor' in properties:
		alpha_scissor_threshold = float(properties['alpha_scissor'])

func _update_animation_frame() -> void:
	frame = _current_frame

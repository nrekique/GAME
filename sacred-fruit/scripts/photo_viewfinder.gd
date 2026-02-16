extends Control

@export var border_color: Color = Color(1, 1, 1, 0.9)
@export var mask_color: Color = Color(0, 0, 0, 0.35)
@export var border_thickness: float = 2.0

var _crop_rect: Rect2 = Rect2()
var _enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled
	queue_redraw()


func set_crop_rect(rect: Rect2) -> void:
	_crop_rect = rect
	queue_redraw()


func _draw() -> void:
	if not _enabled:
		return
	if size.x <= 1.0 or size.y <= 1.0:
		return
	if _crop_rect.size.x <= 1.0 or _crop_rect.size.y <= 1.0:
		return

	var crop_pos := Vector2(
		clampf(_crop_rect.position.x, 0.0, size.x),
		clampf(_crop_rect.position.y, 0.0, size.y)
	)
	var crop_size := Vector2(
		minf(_crop_rect.size.x, size.x - crop_pos.x),
		minf(_crop_rect.size.y, size.y - crop_pos.y)
	)
	var crop := Rect2(crop_pos, crop_size)

	if mask_color.a > 0.001:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, crop.position.y)), mask_color, true)
		draw_rect(Rect2(Vector2.ZERO, Vector2(crop.position.x, size.y)), mask_color, true)
		draw_rect(
			Rect2(Vector2(crop.position.x + crop.size.x, 0.0), Vector2(size.x - (crop.position.x + crop.size.x), size.y)),
			mask_color,
			true
		)
		draw_rect(
			Rect2(Vector2(0.0, crop.position.y + crop.size.y), Vector2(size.x, size.y - (crop.position.y + crop.size.y))),
			mask_color,
			true
		)

	draw_rect(crop, border_color, false, border_thickness)

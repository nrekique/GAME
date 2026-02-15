extends Control

@export var show_guides: bool = true
@export var show_thirds: bool = true
@export var show_golden: bool = false
@export var show_safe_frame: bool = false
@export var line_color: Color = Color(1, 1, 1, 0.5)
@export var line_width: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _draw() -> void:
	if not show_guides:
		return

	var size := get_size()
	if show_thirds:
		var x1 := size.x / 3.0
		var x2 := size.x * 2.0 / 3.0
		var y1 := size.y / 3.0
		var y2 := size.y * 2.0 / 3.0
		draw_line(Vector2(x1, 0), Vector2(x1, size.y), line_color, line_width)
		draw_line(Vector2(x2, 0), Vector2(x2, size.y), line_color, line_width)
		draw_line(Vector2(0, y1), Vector2(size.x, y1), line_color, line_width)
		draw_line(Vector2(0, y2), Vector2(size.x, y2), line_color, line_width)

	if show_golden:
		var phi := 1.6180339887
		var gx := size.x / phi
		var gy := size.y / phi
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), line_color, line_width)
		draw_line(Vector2(0, gy), Vector2(size.x, gy), line_color, line_width)

	if show_safe_frame:
		var margin: float = min(size.x, size.y) * 0.05
		draw_rect(Rect2(Vector2(margin, margin), size - Vector2(margin * 2.0, margin * 2.0)), line_color, false, line_width)


func set_guides_enabled(enabled: bool) -> void:
	show_guides = enabled
	queue_redraw()


func set_thirds_enabled(enabled: bool) -> void:
	show_thirds = enabled
	queue_redraw()


func set_golden_enabled(enabled: bool) -> void:
	show_golden = enabled
	queue_redraw()


func set_safe_frame_enabled(enabled: bool) -> void:
	show_safe_frame = enabled
	queue_redraw()

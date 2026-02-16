extends Control

@export var show_guides: bool = true
@export var show_thirds: bool = false
@export var show_golden: bool = false
@export var show_diagonals: bool = false
@export var show_diagonals_alt: bool = false
@export var show_spiral: bool = false
@export var show_safe_frame: bool = false
@export var line_color: Color = Color(1, 1, 1, 0.5)
@export var line_opacity: float = 0.5
@export var line_width: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _draw() -> void:
	if not show_guides:
		return

	var size := get_size()
	var draw_color := line_color
	draw_color.a = clampf(line_opacity, 0.05, 1.0)
	if show_thirds:
		var x1 := size.x / 3.0
		var x2 := size.x * 2.0 / 3.0
		var y1 := size.y / 3.0
		var y2 := size.y * 2.0 / 3.0
		draw_line(Vector2(x1, 0), Vector2(x1, size.y), draw_color, line_width)
		draw_line(Vector2(x2, 0), Vector2(x2, size.y), draw_color, line_width)
		draw_line(Vector2(0, y1), Vector2(size.x, y1), draw_color, line_width)
		draw_line(Vector2(0, y2), Vector2(size.x, y2), draw_color, line_width)

	if show_golden:
		var phi := 1.6180339887
		var gx := size.x / phi
		var gy := size.y / phi
		var gx2 := size.x - gx
		var gy2 := size.y - gy
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), draw_color, line_width)
		draw_line(Vector2(gx2, 0), Vector2(gx2, size.y), draw_color, line_width)
		draw_line(Vector2(0, gy), Vector2(size.x, gy), draw_color, line_width)
		draw_line(Vector2(0, gy2), Vector2(size.x, gy2), draw_color, line_width)

	if show_diagonals:
		draw_line(Vector2(0, 0), Vector2(size.x, size.y), draw_color, line_width)
		draw_line(Vector2(size.x, 0), Vector2(0, size.y), draw_color, line_width)

	if show_diagonals_alt:
		var x3 := size.x / 3.0
		var x32 := size.x * 2.0 / 3.0
		var y3 := size.y / 3.0
		var y32 := size.y * 2.0 / 3.0
		draw_line(Vector2(0, 0), Vector2(size.x, y3), draw_color, line_width)
		draw_line(Vector2(0, 0), Vector2(x3, size.y), draw_color, line_width)
		draw_line(Vector2(size.x, 0), Vector2(0, y3), draw_color, line_width)
		draw_line(Vector2(size.x, 0), Vector2(x32, size.y), draw_color, line_width)
		draw_line(Vector2(0, size.y), Vector2(size.x, y32), draw_color, line_width)
		draw_line(Vector2(0, size.y), Vector2(x3, 0), draw_color, line_width)
		draw_line(Vector2(size.x, size.y), Vector2(0, y32), draw_color, line_width)
		draw_line(Vector2(size.x, size.y), Vector2(x32, 0), draw_color, line_width)

	if show_spiral:
		_draw_golden_spiral(size, draw_color)

	if show_safe_frame:
		var margin: float = min(size.x, size.y) * 0.05
		draw_rect(Rect2(Vector2(margin, margin), size - Vector2(margin * 2.0, margin * 2.0)), draw_color, false, line_width)


func set_guides_enabled(enabled: bool) -> void:
	show_guides = enabled
	queue_redraw()


func set_thirds_enabled(enabled: bool) -> void:
	show_thirds = enabled
	queue_redraw()


func set_golden_enabled(enabled: bool) -> void:
	show_golden = enabled
	queue_redraw()


func set_diagonals_enabled(enabled: bool) -> void:
	show_diagonals = enabled
	queue_redraw()


func set_diagonals_alt_enabled(enabled: bool) -> void:
	show_diagonals_alt = enabled
	queue_redraw()


func set_spiral_enabled(enabled: bool) -> void:
	show_spiral = enabled
	queue_redraw()


func set_opacity(value: float) -> void:
	line_opacity = clampf(value, 0.05, 1.0)
	queue_redraw()


func _draw_golden_spiral(size: Vector2, color: Color) -> void:
	var phi: float = 1.6180339887
	var center: Vector2 = size * 0.5
	var min_dim: float = min(size.x, size.y)
	var theta_max: float = PI * 4.0
	var a: float = (min_dim * 0.45) / pow(phi, theta_max / (PI * 0.5))
	var points: PackedVector2Array = []
	var step: float = PI / 64.0
	var t: float = 0.0
	while t <= theta_max:
		var r: float = a * pow(phi, t / (PI * 0.5))
		var p: Vector2 = center + Vector2(cos(t), sin(t)) * r
		points.append(p)
		t += step
	if points.size() > 1:
		draw_polyline(points, color, line_width, true)


func set_safe_frame_enabled(enabled: bool) -> void:
	show_safe_frame = enabled
	queue_redraw()

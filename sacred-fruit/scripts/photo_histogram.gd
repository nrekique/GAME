extends Control

@export var sample_interval: float = 0.25
@export var bins: int = 256
@export var downsample_size: Vector2i = Vector2i(192, 108)
@export var show_luma: bool = true
@export var show_rgb: bool = true
@export var background_color: Color = Color(0, 0, 0, 0.55)
@export var luma_color: Color = Color(1, 1, 1, 0.9)
@export var red_color: Color = Color(1, 0.3, 0.3, 0.8)
@export var green_color: Color = Color(0.3, 1, 0.3, 0.8)
@export var blue_color: Color = Color(0.4, 0.6, 1, 0.8)
@export var line_width: float = 1.0

var _time_accum: float = 0.0
var _hist_r: PackedFloat32Array = PackedFloat32Array()
var _hist_g: PackedFloat32Array = PackedFloat32Array()
var _hist_b: PackedFloat32Array = PackedFloat32Array()
var _hist_l: PackedFloat32Array = PackedFloat32Array()
var _max_val: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(0, 64)
	_set_hist_size(bins)


func _process(delta: float) -> void:
	if not visible:
		return
	_time_accum += delta
	if _time_accum >= sample_interval:
		_time_accum = 0.0
		_update_histogram()


func _update_histogram() -> void:
	var tex: Texture2D = get_viewport().get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	if downsample_size.x > 0 and downsample_size.y > 0:
		img.resize(downsample_size.x, downsample_size.y, Image.INTERPOLATE_NEAREST)
	_clear_hist()

	var w: int = img.get_width()
	var h: int = img.get_height()
	var step: int = max(1, int(h / 72))
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c: Color = img.get_pixel(x, y)
			var r: float = c.r
			var g: float = c.g
			var b: float = c.b
			var l: float = 0.2126 * r + 0.7152 * g + 0.0722 * b
			var br: int = clampi(int(r * float(bins - 1)), 0, bins - 1)
			var bg: int = clampi(int(g * float(bins - 1)), 0, bins - 1)
			var bb: int = clampi(int(b * float(bins - 1)), 0, bins - 1)
			var bl: int = clampi(int(l * float(bins - 1)), 0, bins - 1)
			_hist_r[br] += 1.0
			_hist_g[bg] += 1.0
			_hist_b[bb] += 1.0
			_hist_l[bl] += 1.0

	_max_val = 1.0
	for i in range(bins):
		_max_val = max(_max_val, _hist_r[i])
		_max_val = max(_max_val, _hist_g[i])
		_max_val = max(_max_val, _hist_b[i])
		_max_val = max(_max_val, _hist_l[i])
	queue_redraw()


func _draw() -> void:
	var size: Vector2 = get_size()
	draw_rect(Rect2(Vector2.ZERO, size), background_color, true)
	if bins <= 1:
		return
	var dx: float = size.x / float(bins - 1)
	var scale: float = size.y / _max_val

	if show_luma:
		_draw_channel(_hist_l, luma_color, dx, scale, size.y)
	if show_rgb:
		_draw_channel(_hist_r, red_color, dx, scale, size.y)
		_draw_channel(_hist_g, green_color, dx, scale, size.y)
		_draw_channel(_hist_b, blue_color, dx, scale, size.y)


func _draw_channel(hist: PackedFloat32Array, color: Color, dx: float, scale: float, height: float) -> void:
	for i in range(hist.size()):
		var x: float = float(i) * dx
		var h: float = hist[i] * scale
		draw_line(Vector2(x, height), Vector2(x, height - h), color, line_width)


func _clear_hist() -> void:
	for i in range(bins):
		_hist_r[i] = 0.0
		_hist_g[i] = 0.0
		_hist_b[i] = 0.0
		_hist_l[i] = 0.0


func _set_hist_size(count: int) -> void:
	_hist_r.resize(count)
	_hist_g.resize(count)
	_hist_b.resize(count)
	_hist_l.resize(count)
	_clear_hist()

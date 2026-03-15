@tool
extends VBoxContainer
class_name LabeledSlider

## Reusable slider component with label and value display
## Auto-updates value label when slider changes

@export var label_text: String = "Setting":
	set(value):
		label_text = value
		if is_node_ready():
			$TopRow/Label.text = value

@export var min_value: float = 0.0:
	set(value):
		min_value = value
		if is_node_ready():
			$Slider.min_value = value

@export var max_value: float = 100.0:
	set(value):
		max_value = value
		if is_node_ready():
			$Slider.max_value = value

@export var current_value: float = 50.0:
	set(value):
		current_value = value
		if is_node_ready():
			$Slider.value = value
			_update_value_label()

@export var step_size: float = 1.0:
	set(value):
		step_size = value
		if is_node_ready():
			$Slider.step = value

@export var value_format: String = "%.0f":
	set(value):
		value_format = value
		if is_node_ready():
			_update_value_label()

@export var value_suffix: String = "":
	set(value):
		value_suffix = value
		if is_node_ready():
			_update_value_label()

signal value_changed(new_value: float)


func _ready() -> void:
	$TopRow/Label.text = label_text
	$Slider.min_value = min_value
	$Slider.max_value = max_value
	$Slider.value = current_value
	$Slider.step = step_size
	$Slider.value_changed.connect(_on_slider_changed)
	_update_value_label()


func _on_slider_changed(new_value: float) -> void:
	current_value = new_value
	_update_value_label()
	value_changed.emit(new_value)


func _update_value_label() -> void:
	var formatted := value_format % current_value
	$TopRow/Value.text = formatted + value_suffix


func set_value(new_value: float) -> void:
	current_value = new_value

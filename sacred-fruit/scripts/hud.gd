extends CanvasLayer

@onready var objective_label: Label = $Margin/VBox/Objective
@onready var collect_label: Label = $Margin/VBox/Collect


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# GAME is the autoload singleton (see project.godot)
	var game := get_node_or_null("/root/GAME")
	if game == null:
		return

	game.objective_text_changed.connect(_on_objective_text_changed)
	game.collectible_count_changed.connect(_on_collectible_count_changed)

	# Prime UI with current state
	_on_objective_text_changed(game._default_objective_text())
	_on_collectible_count_changed(game.collected_collectibles, game.required_collectibles)


func _on_objective_text_changed(text: String) -> void:
	if objective_label:
		objective_label.text = text


func _on_collectible_count_changed(collected: int, required: int) -> void:
	if collect_label:
		collect_label.text = "%d/%d" % [collected, required]

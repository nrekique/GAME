extends CanvasLayer
const Util := preload("res://scripts/core/util.gd")

@onready var objective_label: Label = $Margin/VBox/Objective
@onready var collect_label: Label = $Margin/VBox/Collect
@onready var health_label: Label = $Margin/VBox/Health


func _ready() -> void:
	if Util.editor_hint():
		return

	# GAME is the autoload singleton (see project.godot)
	var game := get_node_or_null("/root/GAME")
	if game == null:
		return

	game.objective_text_changed.connect(_on_objective_text_changed)
	game.collectible_count_changed.connect(_on_collectible_count_changed)
	if game.has_signal("player_health_changed"):
		game.player_health_changed.connect(_on_player_health_changed)

	# Prime UI with current state
	_on_objective_text_changed(game._default_objective_text())
	_on_collectible_count_changed(game.collected_collectibles, game.required_collectibles)
	if "player_health" in game and "player_max_health" in game and "player_max_overhealth" in game:
		_on_player_health_changed(game.player_health, game.player_max_health, game.player_max_overhealth)


func _on_objective_text_changed(text: String) -> void:
	if objective_label:
		objective_label.text = text


func _on_collectible_count_changed(collected: int, required: int) -> void:
	if collect_label:
		collect_label.text = "%d/%d" % [collected, required]



func _on_player_health_changed(current: int, max_health: int, max_overhealth: int) -> void:
	if not health_label:
		return
	# Show overhealth in a Quake-ish way (e.g. 125/100)
	if max_health <= 0:
		health_label.text = "HP: %d" % current
		return
	if current > max_health:
		health_label.text = "HP: %d/%d" % [current, max_health]
	else:
		health_label.text = "HP: %d" % current

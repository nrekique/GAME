extends Control

@export var start_scene_path: String = "res://scenes/HOME_play.tscn"
@export var options_scene_path: String = "res://scenes/ui/options_menu.tscn"

var play_button: Button
var options_button: Button
var quit_button: Button


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Defensive: ensure the scene truly occupies the full viewport so CenterContainer can center.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := get_node_or_null("Background") as Control
	if bg:
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := get_node_or_null("Center") as Control
	if center:
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Users may move/rename buttons in the scene. Don't rely solely on %UniqueName lookup.
	play_button = _find_button("PlayButton", "Play")
	options_button = _find_button("OptionsButton", "Options")
	quit_button = _find_button("QuitButton", "Quit")

	# If nodes were dragged out (or containers deleted), rebuild layout chain.
	call_deferred("_ensure_layout")

	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	# Focus for keyboard/controller navigation
	if play_button:
		play_button.grab_focus()


func _ensure_layout() -> void:
	var center := _get_or_create_container("Center", CenterContainer, self) as Control
	if center:
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := _get_or_create_container("Panel", PanelContainer, center)
	var margin := _get_or_create_container("Margin", MarginContainer, panel)
	var vbox := _get_or_create_container("VBox", VBoxContainer, margin)
	if vbox is VBoxContainer:
		(vbox as VBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
		(vbox as VBoxContainer).add_theme_constant_override("separation", 10)

	if margin is MarginContainer:
		(margin as MarginContainer).add_theme_constant_override("margin_left", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_right", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_top", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_bottom", 24)

	_reparent_by_name("Title", vbox)
	_reparent_by_name("PlayButton", vbox)
	_reparent_by_name("OptionsButton", vbox)
	_reparent_by_name("QuitButton", vbox)

	# Sweep any stray Controls that got dragged to the root or Margin.
	var top_level := get_children().duplicate()
	for ch in top_level:
		if ch is Control and ch != center and ch.name != "Background":
			_reparent(ch, vbox)
	var margin_children := margin.get_children().duplicate() if margin else []
	for ch in margin_children:
		if ch is Control and ch != vbox:
			_reparent(ch, vbox)


func _reparent_by_name(name_hint: String, new_parent: Node) -> void:
	if new_parent == null:
		return
	var node := find_child(name_hint, true, false)
	if node == null:
		for n in find_children("*", "", true, false):
			if String(n.name).find(name_hint) != -1:
				node = n
				break
	if node != null:
		_reparent(node, new_parent)
		if node is Control:
			(node as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(node as Control).layout_mode = 2


func _get_or_create_container(name_hint: String, type_class: Variant, parent: Node) -> Node:
	if parent == null:
		return null
	# Prefer direct child by name
	var direct := parent.get_node_or_null(name_hint)
	if direct != null:
		return direct
	# Otherwise find anywhere and reparent
	var found := find_child(name_hint, true, false)
	if found != null:
		_reparent(found, parent)
		return found
	# Create new
	var node: Node = type_class.new() as Node
	if node == null:
		return null
	node.name = name_hint
	parent.add_child(node)
	return node


func _reparent(node: Node, new_parent: Node) -> void:
	if node == null or new_parent == null:
		return
	if node.get_parent() == new_parent:
		return
	var old_parent := node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	new_parent.add_child(node)


func _find_button(name_hint: String, text_hint: String) -> Button:
	# First: exact name match anywhere under this Control.
	var by_name := find_child(name_hint, true, false)
	if by_name is Button:
		return by_name as Button

	# Next: substring match (helps when node names get mangled like "...#PlayButton").
	var buttons := find_children("*", "Button", true, false)
	for b in buttons:
		if b is Button and String(b.name).find(name_hint) != -1:
			return b as Button

	# Finally: match by displayed text.
	for b in buttons:
		if b is Button and (b as Button).text.strip_edges().to_lower() == text_hint.to_lower():
			return b as Button
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()


func _on_play_pressed() -> void:
	if start_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(start_scene_path)


func _on_options_pressed() -> void:
	if options_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(options_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()

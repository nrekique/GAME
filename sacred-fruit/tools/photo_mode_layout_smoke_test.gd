extends SceneTree

const SETTINGS_VBOX_PATH := "CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox"
const ALWAYS_ROWS: PackedStringArray = ["HistogramCard", "Title", "Status"]
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Photo mode layout smoke: starting")
	var scene_res: PackedScene = load("res://scenes/photo_mode.tscn")
	if scene_res == null:
		print("ERROR: could not load photo_mode.tscn")
		quit(1)
		return
	var pm: Node = scene_res.instantiate()
	get_root().add_child(pm)

	for _i in range(6):
		await process_frame

	var vbox := pm.get_node_or_null(SETTINGS_VBOX_PATH) as VBoxContainer
	if vbox == null:
		print("ERROR: canonical settings vbox missing at ", SETTINGS_VBOX_PATH)
		quit(1)
		return

	var tab_contents: Dictionary = pm.get("_tab_contents")
	if tab_contents.is_empty():
		print("ERROR: _tab_contents is empty")
		quit(1)
		return
	for tab in tab_contents.keys():
		var tab_key: String = String(tab)
		pm.call("_set_active_tab", tab_key)
		await process_frame
		for n in ALWAYS_ROWS:
			var always_node := vbox.get_node_or_null(String(n)) as CanvasItem
			if always_node == null or not always_node.visible:
				print("ERROR: always-visible node broken for tab=", tab_key, " node=", n)
				quit(1)
				return

		var rows: Array = tab_contents[tab] as Array
		if rows.is_empty():
			print("ERROR: empty tab content for tab=", tab_key)
			quit(1)
			return
		for row in rows:
			var ci := row as CanvasItem
			if ci == null:
				print("ERROR: tab content has non-CanvasItem for tab=", tab_key)
				quit(1)
				return
			if not ci.visible:
				print("ERROR: tab row not visible for tab=", tab_key, " row=", ci.name)
				quit(1)
				return

	print("Photo mode layout smoke: PASS")
	quit(0)

extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Tab-visibility test: starting")
	var scene_res = load("res://scenes/photo_mode.tscn")
	if not scene_res:
		print("ERROR: could not load photo_mode.tscn")
		quit()
		return
	var pm = scene_res.instantiate()
	get_root().add_child(pm)
	# Ensure nodes and UI setup run
	if pm.has_method("_resolve_nodes"):
		pm._resolve_nodes()
	if pm.has_method("_setup_ui"):
		pm._setup_ui()
	var tabs = ["camera","exposure","guides","capture","passes","light","environment","export","color","effects","composition","presets"]
	for t in tabs:
		if pm.has_method("_set_active_tab"):
			pm._set_active_tab(t)
		# synchronous check — _set_active_tab enforces visibility immediately
		# locate Settings VBox (use the scene's helper where available so reparenting doesn't break the test)
		var scroll = null
		if pm.has_method("_find_node"):
			scroll = pm._find_node("SettingsScroll", "ScrollContainer")
		else:
			scroll = pm.get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll")
		var ss = null
		if scroll:
			ss = scroll.get_node_or_null("VBox") if scroll else null
		if ss == null and pm.has_method("_find_node"):
			ss = pm._find_node("VBox", "VBoxContainer")
		var visible_count = 0
		if ss:
			print(" test: settings_vbox=", ss, " path=", ss.get_path(), " child_count=", ss.get_child_count())
			for child in ss.get_children():
				if child is CanvasItem and child.visible:
					visible_count += 1
		print("tab=%s visible_count=%d" % [t, visible_count])
		# Print representative sample rows
		var checks = ["FOVRow","ExposureRow","GuidesRow","CaptureHeaderRow","PassesHeaderRow","LightRigHeaderRow","EnvironmentHeaderRow","ColorHeaderRow","EffectsHeaderRow","CompositionHeaderRow","PresetsHeaderRow"]
		var visible_names = []
		for name in checks:
			var node = null
			if pm.has_method("_find_node"):
				node = pm._find_node(name, "")
			else:
				node = pm.find_child(name, true, false)
			if node and node is CanvasItem:
				visible_names.append("%s=%s" % [name, str(node.visible)])
			else:
				visible_names.append("%s=missing" % name)
		print(" tab=%s samples: %s" % [t, ", ".join(visible_names)])

	quit()

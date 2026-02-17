extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Smoke test: starting")
	var scene_res = load("res://scenes/photo_mode.tscn")
	if not scene_res:
		print("ERROR: could not load photo_mode.tscn")
		quit()
		return
	var pm = scene_res.instantiate()
	get_root().add_child(pm)
	# Trigger capture if available
	# Create a dummy thumbnail and add it to the filmstrip via the PhotoMode helper to avoid headless rendering
	var img := Image.new()
	img.create(160, 88, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var tex := ImageTexture.create_from_image(img)
	var capture := {"path": "user://photos/test_dummy.png", "thumb": tex, "camera": {"position": Vector3(), "rotation": Vector3(), "fov": 60.0}}
	if pm.has_variable("_session_captures"):
		pm._session_captures.append(capture)
	if pm.has_method("_add_capture_thumbnail"):
		pm._add_capture_thumbnail(capture)
	# No rendering in headless smoke test; we simulated a thumbnail and added it above
	# Check session captures
	var count := 0
	if pm.has_variable("_session_captures"):
		count = pm._session_captures.size()
	print("Smoke test: captures=" + str(count))
	# Print saved files under user://photos (globalize path)
	var dir_path = ProjectSettings.globalize_path("user://photos")
	var dir = DirAccess.open(dir_path)
	if dir:
		print("Files in user://photos:")
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			print(" - " + f)
			f = dir.get_next()
		dir.list_dir_end()
	else:
		print("user://photos directory not present or inaccessible: " + dir_path)
	quit()

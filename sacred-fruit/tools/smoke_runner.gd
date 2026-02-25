extends RefCounted
const FUNC_PORTAL_SCRIPT: Script = preload("res://entities/funcs/func_portal.gd")

const SETTINGS_VBOX_PATH := "CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox"
const ALWAYS_ROWS: PackedStringArray = ["HistogramCard", "Title", "Status"]
const REQUIRED_PORTAL_FRAMES: int = 8


static func run_all(host: Node) -> Dictionary:
	var portal_result: Dictionary = await run_portal_pair(host)
	if not bool(portal_result.get("ok", false)):
		return portal_result
	var photo_result: Dictionary = await run_photo_mode_layout(host)
	if not bool(photo_result.get("ok", false)):
		return photo_result
	return {"ok": true, "name": "all", "message": "PASS"}


static func run_portal_pair(host: Node) -> Dictionary:
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return {"ok": false, "name": "portal", "message": "missing SceneTree"}

	var root := Node3D.new()
	root.name = "PortalSmokeRoot"
	tree.root.add_child(root)

	var cam := Camera3D.new()
	cam.name = "SmokeCamera"
	cam.current = true
	cam.near = 0.01
	cam.far = 500.0
	cam.position = Vector3(0.0, 1.2, -2.5)
	root.add_child(cam)

	var p1: Node3D = _make_portal("PortalA", "portal_a", "portal_b", Vector3(0.0, 1.2, 0.0), Vector3(0.0, 0.0, 1.0))
	var p2: Node3D = _make_portal("PortalB", "portal_b", "portal_a", Vector3(0.0, 1.2, 4.0), Vector3(0.0, 0.0, -1.0))
	root.add_child(p1)
	root.add_child(p2)

	for _i in range(REQUIRED_PORTAL_FRAMES):
		await tree.process_frame

	if p1.get("_plugin_portal") == null or p2.get("_plugin_portal") == null:
		_dispose_node(root)
		return {"ok": false, "name": "portal", "message": "plugin runtime portals were not created"}
	if p1.get("_linked_portal") == null or p2.get("_linked_portal") == null:
		_dispose_node(root)
		return {"ok": false, "name": "portal", "message": "portal link resolution failed"}

	var sample := Transform3D(Basis.IDENTITY, Vector3(0.25, 1.35, -0.4))
	var mapped: Transform3D = p1.call("_map_transform_to_link", sample)
	var roundtrip: Transform3D = p2.call("_map_transform_to_link", mapped)
	var seam_dist: float = sample.origin.distance_to(roundtrip.origin)
	if seam_dist > 0.05:
		_dispose_node(root)
		return {"ok": false, "name": "portal", "message": "roundtrip seam mismatch dist=%s" % str(seam_dist)}

	var body := CharacterBody3D.new()
	body.name = "SmokeBody"
	body.velocity = Vector3(1.0, 0.0, 2.0)
	body.global_transform = Transform3D(Basis.IDENTITY, p1.global_position + p1.global_basis.z * 0.1)
	root.add_child(body)
	var before_pos: Vector3 = body.global_position
	p1.call("_teleport_entity", body)
	await tree.process_frame
	if body.global_position.distance_to(before_pos) < 0.5:
		_dispose_node(root)
		return {"ok": false, "name": "portal", "message": "teleport did not move body"}

	_dispose_node(root)
	await tree.process_frame
	return {"ok": true, "name": "portal", "message": "PASS"}


static func run_photo_mode_layout(host: Node) -> Dictionary:
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return {"ok": false, "name": "photo_mode", "message": "missing SceneTree"}

	var scene_res: PackedScene = load("res://scenes/photo_mode.tscn")
	if scene_res == null:
		return {"ok": false, "name": "photo_mode", "message": "could not load photo_mode.tscn"}

	var pm: Node = scene_res.instantiate()
	tree.root.add_child(pm)
	if pm is CanvasItem:
		(pm as CanvasItem).visible = false

	for _i in range(6):
		await tree.process_frame

	var vbox := pm.get_node_or_null(SETTINGS_VBOX_PATH) as VBoxContainer
	if vbox == null:
		_dispose_node(pm)
		return {"ok": false, "name": "photo_mode", "message": "canonical settings vbox missing"}

	var tab_contents_v: Variant = pm.get("_tab_contents")
	if not (tab_contents_v is Dictionary):
		_dispose_node(pm)
		return {"ok": false, "name": "photo_mode", "message": "_tab_contents missing"}
	var tab_contents: Dictionary = tab_contents_v
	if tab_contents.is_empty():
		_dispose_node(pm)
		return {"ok": false, "name": "photo_mode", "message": "_tab_contents is empty"}

	for tab in tab_contents.keys():
		var tab_key: String = String(tab)
		pm.call("_set_active_tab", tab_key)
		await tree.process_frame
		for n in ALWAYS_ROWS:
			var always_node := vbox.get_node_or_null(String(n)) as CanvasItem
			if always_node == null or not always_node.visible:
				_dispose_node(pm)
				return {"ok": false, "name": "photo_mode", "message": "always-visible row broken tab=%s row=%s" % [tab_key, n]}

			var rows_v: Variant = tab_contents[tab]
			if not (rows_v is Array):
				_dispose_node(pm)
				return {"ok": false, "name": "photo_mode", "message": "tab content is not an Array tab=%s" % tab_key}
			var rows: Array = rows_v
			if rows.is_empty():
				_dispose_node(pm)
				return {"ok": false, "name": "photo_mode", "message": "empty tab content tab=%s" % tab_key}
			for row in rows:
				var ci := row as CanvasItem
				if ci == null:
					_dispose_node(pm)
					return {"ok": false, "name": "photo_mode", "message": "non-CanvasItem in tab=%s" % tab_key}
				if not ci.visible:
					_dispose_node(pm)
					return {"ok": false, "name": "photo_mode", "message": "tab row not visible tab=%s row=%s" % [tab_key, ci.name]}

	_dispose_node(pm)
	await tree.process_frame
	return {"ok": true, "name": "photo_mode", "message": "PASS"}


static func _make_portal(node_name: String, targetname: String, target: String, world_pos: Vector3, world_normal: Vector3) -> Node3D:
	var portal := FUNC_PORTAL_SCRIPT.new() as Node3D
	if portal == null:
		return Node3D.new()
	portal.name = node_name
	portal.targetname = targetname
	portal.target = target
	portal.portal_debug = false
	portal.plugin_face_from_portal_texture = true
	portal.use_portals_plugin = true
	portal.position = world_pos
	portal.set_meta("func_godot_mesh_data", {
		"normals": PackedVector3Array([world_normal.normalized()]),
		"positions": PackedVector3Array([world_pos]),
		"textures": PackedInt32Array([0]),
		"texture_names": ["portal_surface"]
	})
	return portal


static func _dispose_node(node: Node) -> void:
	if node == null:
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()

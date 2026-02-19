extends SceneTree

const REQUIRED_FRAMES := 8


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Portal smoke: starting")

	var root := Node3D.new()
	root.name = "PortalSmokeRoot"
	get_root().add_child(root)

	var cam := Camera3D.new()
	cam.name = "SmokeCamera"
	cam.current = true
	cam.near = 0.01
	cam.far = 500.0
	cam.position = Vector3(0.0, 1.2, -2.5)
	root.add_child(cam)

	var p1 := _make_portal("PortalA", "portal_a", "portal_b", Vector3(0.0, 1.2, 0.0), Vector3(0.0, 0.0, 1.0))
	var p2 := _make_portal("PortalB", "portal_b", "portal_a", Vector3(0.0, 1.2, 4.0), Vector3(0.0, 0.0, -1.0))
	root.add_child(p1)
	root.add_child(p2)

	for _i in range(REQUIRED_FRAMES):
		await process_frame

	if p1.get("_plugin_portal") == null or p2.get("_plugin_portal") == null:
		print("ERROR: plugin runtime portals were not created")
		quit(1)
		return
	if p1.get("_linked_portal") == null or p2.get("_linked_portal") == null:
		print("ERROR: portal link resolution failed")
		quit(1)
		return

	var sample := Transform3D(Basis.IDENTITY, Vector3(0.25, 1.35, -0.4))
	var mapped: Transform3D = p1.call("_map_transform_to_link", sample)
	var roundtrip: Transform3D = p2.call("_map_transform_to_link", mapped)
	if sample.origin.distance_to(roundtrip.origin) > 0.05:
		print("ERROR: portal roundtrip seam mismatch, dist=", sample.origin.distance_to(roundtrip.origin))
		quit(1)
		return

	var body := CharacterBody3D.new()
	body.name = "SmokeBody"
	body.velocity = Vector3(1.0, 0.0, 2.0)
	body.global_transform = Transform3D(Basis.IDENTITY, p1.global_position + p1.global_basis.z * 0.1)
	root.add_child(body)
	var before_pos: Vector3 = body.global_position
	p1.call("_teleport_entity", body)
	await process_frame
	if body.global_position.distance_to(before_pos) < 0.5:
		print("ERROR: teleport did not move body")
		quit(1)
		return

	print("Portal smoke: PASS")
	quit(0)


func _make_portal(node_name: String, targetname: String, target: String, world_pos: Vector3, world_normal: Vector3) -> FuncPortal:
	var portal := FuncPortal.new()
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

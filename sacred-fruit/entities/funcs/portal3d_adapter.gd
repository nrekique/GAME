class_name Portal3DAdapter
extends RefCounted

const PORTAL3D_SCRIPT_PATH := "res://addons/portals/scripts/portal_3d.gd"
const REQUIRED_PROPERTIES: PackedStringArray = [
	"portal_size",
	"is_teleport",
	"teleport_collision_mask",
	"teleport_interactions",
	"keep_viewports_hot",
	"view_direction",
	"portal_render_layer",
	"start_deactivated",
	"player_camera",
	"exit_portal",
]

const REQUIRED_METHODS: PackedStringArray = [
	"activate",
	"deactivate",
	"_setup_mesh",
	"_setup_teleport",
]


func validate_or_error() -> bool:
	var probe: Node3D = _instantiate_portal()
	if probe == null:
		push_error("Portal3DAdapter: failed to load/instantiate %s." % PORTAL3D_SCRIPT_PATH)
		return false
	var property_set := {}
	for p in probe.get_property_list():
		if p is Dictionary and (p as Dictionary).has("name"):
			property_set[String((p as Dictionary)["name"])] = true
	for required_property in REQUIRED_PROPERTIES:
		if not property_set.has(required_property):
			push_error("Portal3DAdapter: Plugin API mismatch, missing property '%s'." % required_property)
			return false
	for required_method in REQUIRED_METHODS:
		if not probe.has_method(required_method):
			push_error("Portal3DAdapter: Plugin API mismatch, missing method '%s'." % required_method)
			return false
	return true


func create_runtime_portal(parent: Node, node_name: String, portal_size: Vector2, src_cam: Camera3D,
		enabled: bool, teleport_collision_mask: int, render_layer_mask: int) -> Node3D:
	if parent == null:
		push_error("Portal3DAdapter: parent is null.")
		return null
	if src_cam == null:
		push_error("Portal3DAdapter: source camera is null.")
		return null
	if not validate_or_error():
		return null

	var portal: Node3D = _instantiate_portal()
	if portal == null:
		push_error("Portal3DAdapter: failed to instantiate %s." % PORTAL3D_SCRIPT_PATH)
		return null
	portal.name = node_name
	portal.set("portal_size", portal_size)
	portal.set("is_teleport", enabled)
	portal.set("teleport_collision_mask", teleport_collision_mask)
	portal.set("teleport_interactions", 1) # CALLBACK
	portal.set("keep_viewports_hot", true)
	portal.set("view_direction", 0) # FRONT_AND_BACK
	portal.set("portal_render_layer", render_layer_mask)
	portal.set("start_deactivated", true)
	portal.set("player_camera", src_cam)
	portal.call("_setup_mesh")
	portal.call("_setup_teleport")
	parent.add_child(portal)
	return portal


func configure_runtime_portal(portal: Node, src_cam: Camera3D, enabled: bool,
		teleport_collision_mask: int) -> void:
	if portal == null or src_cam == null:
		return
	portal.set("is_teleport", enabled)
	portal.set("teleport_collision_mask", teleport_collision_mask)
	portal.set("teleport_interactions", 1) # CALLBACK
	portal.set("keep_viewports_hot", true)
	portal.set("player_camera", src_cam)


func link_portals(portal: Node, exit_portal: Node, src_cam: Camera3D) -> bool:
	if portal == null or exit_portal == null or src_cam == null:
		return false
	portal.set("exit_portal", exit_portal)
	portal.set("player_camera", src_cam)
	portal.call("activate")
	return true


func deactivate_portal(portal: Node) -> void:
	if portal == null:
		return
	portal.call("deactivate")


func _instantiate_portal() -> Node3D:
	var portal_script: Script = load(PORTAL3D_SCRIPT_PATH)
	if portal_script == null:
		return null
	var portal_obj: Variant = portal_script.new()
	if portal_obj is Node3D:
		return portal_obj as Node3D
	return null

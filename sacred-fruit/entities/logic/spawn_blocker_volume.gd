@tool
class_name SpawnBlockerVolume
extends Volume

# Prevents spawning of actors inside this area; adds itself to the
# `spawn_blocker` group so code can query active blockers.

func _ready() -> void:
	# call base setup then join group
	. _ready()
	add_to_group("spawn_blocker")

func _process_body(body: Node, entered: bool) -> void:
	# no-op by default; spawning code should query this volume's overlaps.
	pass

# check whether a global position lies inside this volume's collision shape
func blocks_point(point: Vector3) -> bool:
	var state := get_world_3d().direct_space_state
	var params := PhysicsPointQueryParameters3D.new()
	params.position = point
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.exclude = []
	var results := state.intersect_point(params)
	for item in results:
		if item.collider == self:
			return true
	return false

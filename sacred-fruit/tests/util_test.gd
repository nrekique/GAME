extends Node

const Util := preload("res://scripts/core/util.gd")

func _ready():
	# simple boolean conversions
	assert(Util.to_bool(true) == true)
	assert(Util.to_bool(false) == false)
	assert(Util.to_bool(1) == true)
	assert(Util.to_bool(0) == false)
	assert(Util.to_bool("yes") == true)
	assert(Util.to_bool("no") == false)
	assert(Util.to_bool("", true) == true)

	print("[TEST] Util.to_bool passed")

	# node property helper
	var n = Node.new()
	n.someprop = 123
	assert(Util.get_node_prop(n, "someprop", 0) == 123)
	assert(Util.get_node_prop(n, "missing", 5) == 5)
	print("[TEST] Util.get_node_prop passed")

	# editor hint proxy
	assert(Util.editor_hint() in [true, false])
	print("[TEST] Util.editor_hint returned boolean")

	get_tree().quit()

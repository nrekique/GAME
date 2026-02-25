extends Node

# simple smoke test for IO manager

const IO := preload("res://scripts/core/io_manager.gd")

func _ready():
	var mgr := IO.new()
	# basic property
	mgr.io_debug_logging = true
	mgr.io_trace_capacity = 4
	# confirm trace works
	mgr._append_io_trace({"source_name":"a","target_group":"b","input":"use","delay":0.0,"invoked_count":1,"target_count":2})
	assert(mgr.io_get_trace().size() == 1)
	mgr.io_clear_trace()
	assert(mgr.io_get_trace().empty())
	print("[TEST] IO trace operations passed")

	# master lock and killtarget behavior tests require scene nodes; skip for smoke
	get_tree().quit()

extends Node


func _ready() -> void:
	var dm := preload("res://scripts/core/dialogue_manager.gd").new()
	dm.name = "DIALOGUE"
	get_tree().root.add_child(dm)
	await get_tree().process_frame

	dm.set_skill("speech", 30)
	dm.set_faction_rep("settlers", 2)
	dm.set_quest_stage("water", 1)

	var conv := {
		"id": "dialogue_integration",
		"speaker": "Tester",
		"start": "intro",
		"nodes": {
			"intro": {
				"text": "Choose route",
				"choices": [
					{
						"text": "Advance quest gate",
						"min_quest_stage": {"water": 1},
						"faction": "settlers",
						"min_faction_rep": 2,
						"set_quest_stage": {"water": 2},
						"add_faction_rep": {"settlers": 1},
						"set_fact": ["accepted_water_upgrade"],
						"next": "after"
					},
					{
						"text": "Blocked route",
						"require_quest": ["missing_quest"],
						"next": "after"
					}
				]
			},
			"after": {
				"text": "Done",
				"choices": [
					{"text": "Bye", "end": true}
				]
			}
		}
	}

	assert(dm.start_dialogue("dialogue_integration", conv))
	await get_tree().process_frame
	assert(dm.is_dialogue_active())
	dm.choose_option(0)
	await get_tree().process_frame
	assert(dm.get_quest_stage("water", 0) == 2)
	assert(dm.get_faction_rep("settlers", 0) == 3)
	assert(dm.has_fact("accepted_water_upgrade"))
	print("[TEST] Dialogue quest/faction effects applied")

	# Restart and verify blocked choice remains locked while valid route works.
	assert(dm.start_dialogue("dialogue_integration", conv))
	await get_tree().process_frame
	dm.choose_option(1) # should be blocked and ignored
	await get_tree().process_frame
	assert(dm.is_dialogue_active())
	dm.choose_option(0)
	await get_tree().process_frame
	assert(dm.get_quest_stage("water", 0) == 2)
	print("[TEST] Dialogue gating prevents blocked quest route")

	dm.end_dialogue()
	dm.queue_free()
	get_tree().quit()

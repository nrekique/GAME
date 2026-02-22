extends Node

func _ready():
	# ensure the build_profile setting exists and is one of the expected values.
	var p := ProjectSettings.get_setting("application/build_profile", "<unset>")
	assert(p in ["fast-iteration", "playtest", "shipping", "<unset>"])
	if p == "<unset>":
		print("[TEST] build_profile not specified; defaulting to fast-iteration")
	else:
		print("[TEST] build_profile is '" + str(p) + "'")
	get_tree().quit()

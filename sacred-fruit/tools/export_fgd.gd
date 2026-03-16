## Headless FGD export tool.
## Regenerates the TrenchBroom FGD from res://tb/fgd/game_cfg.tres without
## opening the Godot editor.
##
## Usage:
##   godot --headless --path <project_root> --script res://tools/export_fgd.gd
##
## Or use tools/export_fgd.sh which handles Godot binary detection automatically.
@tool
extends SceneTree

# TrenchBroom sacred-fruit game config folder.
# This is the folder that contains GameConfig.cfg and the FGD files TB reads.
const TB_GAME_CONFIG_FOLDER := "/Users/nre/Library/Application Support/TrenchBroom/games/sacredFruit"

# FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM = 1
const TARGET_TRENCHBROOM := 1


func _init() -> void:
	var game_cfg = load("res://tb/fgd/game_cfg.tres")
	if game_cfg == null:
		printerr("export_fgd: failed to load res://tb/fgd/game_cfg.tres")
		quit(1)
		return

	var fgd_file = game_cfg.get("fgd_file")
	if fgd_file == null:
		printerr("export_fgd: game_cfg.tres has no fgd_file property")
		quit(1)
		return

	var fgd_name: String = fgd_file.get("fgd_name")
	if fgd_name.is_empty():
		printerr("export_fgd: fgd_file has no fgd_name")
		quit(1)
		return

	# do_export_file() checks Engine.is_editor_hint() and returns early when
	# run headlessly. Call build_class_text() directly and write the file ourselves.
	var fgd_text: String = fgd_file.build_class_text(TARGET_TRENCHBROOM)
	var out_path := TB_GAME_CONFIG_FOLDER + "/" + fgd_name + ".fgd"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("export_fgd: failed to open output file: ", out_path)
		quit(1)
		return
	f.store_string(fgd_text)
	f.close()
	print("export_fgd: done → " + out_path)
	quit(0)

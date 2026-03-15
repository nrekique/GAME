class_name Settings
extends Node

signal settings_applied
signal settings_changed

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_BACKUP_PATH := CONFIG_PATH + ".bak"

# Defaults (match current gameplay feel)
var fullscreen: bool = false
var vsync: bool = true
var window_size: Vector2i = Vector2i(1439, 960)

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.9

var mouse_sens: float = 0.25
var mouse_smoothing: float = 0.0
var gameplay_fov: float = 90.0


func _ready() -> void:
	load_settings()
	apply_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		var backup_err := cfg.load(CONFIG_BACKUP_PATH)
		if backup_err != OK:
			# First run or unreadable config: keep defaults.
			return
		push_warning("SETTINGS: primary config load failed; using backup copy (%s)" % str(err))

	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	window_size = Vector2i(
		int(cfg.get_value("display", "window_width", window_size.x)),
		int(cfg.get_value("display", "window_height", window_size.y))
	)

	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)

	mouse_sens = clampf(float(cfg.get_value("controls", "mouse_sens", mouse_sens)), 0.05, 2.0)
	mouse_smoothing = clampf(float(cfg.get_value("controls", "mouse_smoothing", mouse_smoothing)), 0.0, 0.25)
	gameplay_fov = clampf(float(cfg.get_value("controls", "gameplay_fov", gameplay_fov)), 75.0, 110.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "window_width", window_size.x)
	cfg.set_value("display", "window_height", window_size.y)

	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)

	cfg.set_value("controls", "mouse_sens", mouse_sens)
	cfg.set_value("controls", "mouse_smoothing", mouse_smoothing)
	cfg.set_value("controls", "gameplay_fov", gameplay_fov)
	_save_config_atomic(cfg, CONFIG_PATH, CONFIG_BACKUP_PATH, "settings")


func _save_config_atomic(cfg: ConfigFile, target_path: String, backup_path: String, label: String) -> bool:
	var tmp_path := target_path + ".tmp"
	var tmp_save_err := cfg.save(tmp_path)
	if tmp_save_err != OK:
		push_warning("SETTINGS %s save failed (tmp): %s" % [label, str(tmp_save_err)])
		return false

	var abs_target := ProjectSettings.globalize_path(target_path)
	var abs_backup := ProjectSettings.globalize_path(backup_path)
	var abs_tmp := ProjectSettings.globalize_path(tmp_path)

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(abs_backup)
	if FileAccess.file_exists(target_path):
		var backup_err := DirAccess.rename_absolute(abs_target, abs_backup)
		if backup_err != OK:
			push_warning("SETTINGS %s save failed (backup rotate): %s" % [label, str(backup_err)])
			DirAccess.remove_absolute(abs_tmp)
			return false

	var promote_err := DirAccess.rename_absolute(abs_tmp, abs_target)
	if promote_err != OK:
		push_warning("SETTINGS %s save failed (promote tmp): %s" % [label, str(promote_err)])
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(target_path):
			DirAccess.rename_absolute(abs_backup, abs_target)
		return false

	return true


func apply_settings() -> void:
	_apply_display()
	_apply_audio()
	emit_signal("settings_applied")


func apply_and_save() -> void:
	emit_signal("settings_changed")
	apply_settings()
	save_settings()


func _apply_display() -> void:
	# Window mode
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if window_size.x > 0 and window_size.y > 0:
			DisplayServer.window_set_size(window_size)

	# VSync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)


func _apply_audio() -> void:
	# Ensure expected buses exist so volume sliders work even in a fresh project.
	# Note: Audio nodes still need their `bus` property set to route to these.
	_ensure_bus_exists("Master")
	_ensure_bus_exists("Music", "Master")
	_ensure_bus_exists("SFX", "Music")

	_set_bus_volume_linear("Master", master_volume)
	_set_bus_volume_linear("Music", music_volume)
	_set_bus_volume_linear("SFX", sfx_volume)


func _set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		# Bus doesn't exist (fine) - skip.
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, linear)))


func _ensure_bus_exists(bus_name: String, after_bus_name: String = "") -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	# Add to end.
	AudioServer.add_bus(AudioServer.get_bus_count())
	var idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)

	# Route through Master by default.
	if bus_name != "Master":
		var master_idx := AudioServer.get_bus_index("Master")
		if master_idx != -1:
			AudioServer.set_bus_send(idx, "Master")

	# Optional ordering (purely cosmetic).
	if not after_bus_name.is_empty():
		var after_idx := AudioServer.get_bus_index(after_bus_name)
		if after_idx != -1:
			AudioServer.move_bus(idx, after_idx + 1)

extends Node

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULT_MASTER_VOLUME   := 1.0
const DEFAULT_SFX_UI_VOLUME   := 1.0
const DEFAULT_SFX_GAME_VOLUME := 1.0
const DEFAULT_WINDOW_MODE     := DisplayServer.WINDOW_MODE_WINDOWED
const DEFAULT_RESOLUTION      := Vector2i(1280, 720)

var master_volume   : float    = DEFAULT_MASTER_VOLUME
var sfx_ui_volume   : float    = DEFAULT_SFX_UI_VOLUME
var sfx_game_volume : float    = DEFAULT_SFX_GAME_VOLUME
var window_mode     : int      = DEFAULT_WINDOW_MODE
var resolution      : Vector2i = DEFAULT_RESOLUTION

func _ready() -> void:
	load_settings()
	apply_all()

func set_master_volume(linear: float) -> void:
	master_volume = clampf(linear, 0.0, 1.0)
	_apply_volume("Master", master_volume)
	save_settings()

func set_sfx_ui_volume(linear: float) -> void:
	sfx_ui_volume = clampf(linear, 0.0, 1.0)
	_apply_volume("SFX_UI", sfx_ui_volume)
	save_settings()

func set_sfx_game_volume(linear: float) -> void:
	sfx_game_volume = clampf(linear, 0.0, 1.0)
	_apply_volume("SFX_Game", sfx_game_volume)
	save_settings()

func set_window_mode(mode: int) -> void:
	window_mode = mode
	_apply_window_mode(window_mode)
	save_settings()

func set_resolution(res: Vector2i) -> void:
	resolution = res
	_apply_resolution(resolution)
	save_settings()

func apply_all() -> void:
	_apply_volume("Master", master_volume)
	_apply_volume("SFX_UI", sfx_ui_volume)
	_apply_volume("SFX_Game", sfx_game_volume)
	_apply_window_mode(window_mode)
	if window_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		_apply_resolution(resolution)

func _apply_volume(bus_name: String, linear: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))
	AudioServer.set_bus_mute(bus_idx, linear <= 0.0)

func _apply_window_mode(mode: int) -> void:
	DisplayServer.window_set_mode(mode)

func _apply_resolution(res: Vector2i) -> void:
	DisplayServer.window_set_size(res)
	var screen_size := DisplayServer.screen_get_size()
	var centered := Vector2i(
		int((screen_size.x - res.x) / 2.0),
		int((screen_size.y - res.y) / 2.0)
	)
	DisplayServer.window_set_position(centered)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio",   "master_volume",   master_volume)
	cfg.set_value("audio",   "sfx_ui_volume",   sfx_ui_volume)
	cfg.set_value("audio",   "sfx_game_volume", sfx_game_volume)
	cfg.set_value("display", "window_mode",     window_mode)
	cfg.set_value("display", "resolution_x",    resolution.x)
	cfg.set_value("display", "resolution_y",    resolution.y)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: failed to save settings (err %d)" % err)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	master_volume   = cfg.get_value("audio",   "master_volume",   DEFAULT_MASTER_VOLUME)
	sfx_ui_volume   = cfg.get_value("audio",   "sfx_ui_volume",   DEFAULT_SFX_UI_VOLUME)
	sfx_game_volume = cfg.get_value("audio",   "sfx_game_volume", DEFAULT_SFX_GAME_VOLUME)
	window_mode     = cfg.get_value("display", "window_mode",     DEFAULT_WINDOW_MODE)
	var rx : int    = cfg.get_value("display", "resolution_x",    DEFAULT_RESOLUTION.x)
	var ry : int    = cfg.get_value("display", "resolution_y",    DEFAULT_RESOLUTION.y)
	resolution      = Vector2i(rx, ry)

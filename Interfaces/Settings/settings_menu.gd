extends CanvasLayer

@onready var master_slider    : HSlider      = $Panel/VBox/MasterRow/MasterSlider
@onready var master_value     : Label        = $Panel/VBox/MasterRow/MasterValue
@onready var sfx_ui_slider    : HSlider      = $Panel/VBox/SFXUIRow/SFXUISlider
@onready var sfx_ui_value     : Label        = $Panel/VBox/SFXUIRow/SFXUIValue
@onready var sfx_game_slider  : HSlider      = $Panel/VBox/SFXGameRow/SFXGameSlider
@onready var sfx_game_value   : Label        = $Panel/VBox/SFXGameRow/SFXGameValue
@onready var window_mode_opt  : OptionButton = $Panel/VBox/WindowModeRow/WindowModeOption
@onready var resolution_row   : HBoxContainer = $Panel/VBox/ResolutionRow
@onready var resolution_opt   : OptionButton = $Panel/VBox/ResolutionRow/ResolutionOption
@onready var close_btn        : Button       = $Panel/VBox/CloseButton

const WINDOW_MODES := [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
]
const WINDOW_LABELS := [
	"Windowed",
	"Fullscreen",
]

const ALL_RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var _available_resolutions : Array[Vector2i] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_resolution_list()
	_populate_window_options()
	_populate_resolution_options()
	_load_current_values()
	_connect_signals()
	_connect_button_sounds(close_btn)

func _connect_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_hover))
	button.pressed.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_click))

func _build_resolution_list() -> void:
	var monitor_size := DisplayServer.screen_get_size()
	_available_resolutions.clear()
	for res in ALL_RESOLUTIONS:
		if res.x <= monitor_size.x and res.y <= monitor_size.y:
			_available_resolutions.append(res)
	if _available_resolutions.is_empty():
		_available_resolutions.append(Vector2i(1280, 720))

func _populate_window_options() -> void:
	window_mode_opt.clear()
	for label in WINDOW_LABELS:
		window_mode_opt.add_item(label)

func _populate_resolution_options() -> void:
	resolution_opt.clear()
	for res in _available_resolutions:
		resolution_opt.add_item("%d × %d" % [res.x, res.y])

func _load_current_values() -> void:
	master_slider.value   = SettingsConfig.master_volume
	sfx_ui_slider.value   = SettingsConfig.sfx_ui_volume
	sfx_game_slider.value = SettingsConfig.sfx_game_volume

	master_value.text   = "%d%%" % roundi(SettingsConfig.master_volume   * 100)
	sfx_ui_value.text   = "%d%%" % roundi(SettingsConfig.sfx_ui_volume   * 100)
	sfx_game_value.text = "%d%%" % roundi(SettingsConfig.sfx_game_volume * 100)

	var mode_idx := WINDOW_MODES.find(SettingsConfig.window_mode)
	window_mode_opt.selected = max(mode_idx, 0)

	var res_idx := _available_resolutions.find(SettingsConfig.resolution)
	if res_idx == -1:
		res_idx = _find_closest_resolution(SettingsConfig.resolution)
	resolution_opt.selected = res_idx

	_update_resolution_visibility(window_mode_opt.selected)

func _find_closest_resolution(target: Vector2i) -> int:
	var best_idx := 0
	var best_diff : int = INF
	for i in _available_resolutions.size():
		var res := _available_resolutions[i]
		var diff : int = abs(res.x - target.x) + abs(res.y - target.y)
		if diff < best_diff:
			best_diff = diff
			best_idx = i
	return best_idx

func _update_resolution_visibility(mode_idx: int) -> void:
	resolution_row.visible = (WINDOW_MODES[mode_idx] == DisplayServer.WINDOW_MODE_WINDOWED)

func _connect_signals() -> void:
	master_slider.value_changed.connect(_on_master_changed)
	sfx_ui_slider.value_changed.connect(_on_sfx_ui_changed)
	sfx_game_slider.value_changed.connect(_on_sfx_game_changed)
	window_mode_opt.item_selected.connect(_on_window_mode_selected)
	resolution_opt.item_selected.connect(_on_resolution_selected)
	close_btn.pressed.connect(_on_close_pressed)

func _on_master_changed(value: float) -> void:
	master_value.text = "%d%%" % roundi(value * 100)
	SettingsConfig.set_master_volume(value)

func _on_sfx_ui_changed(value: float) -> void:
	sfx_ui_value.text = "%d%%" % roundi(value * 100)
	SettingsConfig.set_sfx_ui_volume(value)

func _on_sfx_game_changed(value: float) -> void:
	sfx_game_value.text = "%d%%" % roundi(value * 100)
	SettingsConfig.set_sfx_game_volume(value)

func _on_window_mode_selected(index: int) -> void:
	_update_resolution_visibility(index)
	SettingsConfig.set_window_mode(WINDOW_MODES[index])

func _on_resolution_selected(index: int) -> void:
	SettingsConfig.set_resolution(_available_resolutions[index])

func _on_close_pressed() -> void:
	queue_free()

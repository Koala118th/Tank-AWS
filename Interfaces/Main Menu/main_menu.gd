extends Control
class_name Main_menu

@onready var name_line_edit    = $MenuScreen/VBoxContainer/LineEdit
@onready var divider_label     = $MenuScreen/VBoxContainer/DividerLabel
@onready var menu_screen       = $MenuScreen
@onready var connecting_screen = $ConnectingScreen
@onready var status_label      = $ConnectingScreen/VBoxContainer/TextBlock/StatusLabel
@onready var spinner           = $ConnectingScreen/VBoxContainer/SpinnerWrapper/SpinnerRect
@onready var spinner_inner     = $ConnectingScreen/VBoxContainer/SpinnerWrapper/SpinnerInner

func _ready():
	_connect_button_sounds($MenuScreen/VBoxContainer/PlayButton)
	_connect_button_sounds($MenuScreen/VBoxContainer/SettingsButton)
	_connect_button_sounds($MenuScreen/VBoxContainer/QuitButton)
	# wait one frame for layout to calculate the actual size
	await get_tree().process_frame
	spinner.pivot_offset       = spinner.size / 2
	spinner_inner.pivot_offset = spinner_inner.size / 2

	if GameServer.pending_error_message != "":
		divider_label.text = GameServer.pending_error_message
		divider_label.add_theme_color_override("font_color", Color.RED)
		GameServer.pending_error_message = ""

func _process(delta):
	if connecting_screen.visible:
		spinner.rotation_degrees       += 180.0 * delta   # forward
		spinner_inner.rotation_degrees -= 260.0 * delta   # backward, faster

func _on_start_button_pressed() -> void:
	if name_line_edit.text.strip_edges() == "":
		divider_label.text = "ENTER A USERNAME"
		divider_label.add_theme_color_override("font_color", Color.RED)
	else:
		GameServer.start_client(name_line_edit.text)

func _on_settings_button_pressed() -> void:
	var scene := preload("res://Interfaces/Settings/settings_menu.tscn")
	add_child(scene.instantiate())

func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _connect_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_hover))
	button.pressed.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_click))


func _on_line_edit_text_changed(new_text: String) -> void:
	if new_text.strip_edges() != "":
		divider_label.text = "·    ·    ·    ·    ·    ·    ·    ·    ·    ·    ·    ·    ·"
		divider_label.add_theme_color_override("font_color", Color(0.227, 0.353, 0.227))

func show_connecting(status: String = "Reaching server..."):
	menu_screen.hide()
	connecting_screen.show()
	status_label.text = status

func show_menu():
	connecting_screen.hide()
	menu_screen.show()

func set_status(status: String):
	status_label.text = status

func _on_cancel_button_pressed():
	# teammate fills this in with disconnect logic
	show_menu()

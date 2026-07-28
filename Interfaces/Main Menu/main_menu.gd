extends Control
class_name Main_menu

@onready var name_line_edit = $CenterContainer/VBoxContainer/LineEdit
@onready var divider_label = $CenterContainer/VBoxContainer/DividerLabel

func _ready():
	_connect_button_sounds($CenterContainer/VBoxContainer/PlayButton)
	_connect_button_sounds($CenterContainer/VBoxContainer/SettingsButton)
	_connect_button_sounds($CenterContainer/VBoxContainer/QuitButton)

func _on_start_button_pressed() -> void:
	if name_line_edit.text.strip_edges() == "":
		divider_label.text = "ENTER A USERNAME"
		divider_label.add_theme_color_override("font_color", Color.RED)
		divider_label
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

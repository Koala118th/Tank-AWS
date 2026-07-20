extends Control
class_name Main_menu

func _ready():
	_connect_button_sounds($CenterContainer/VBoxContainer/PlayButton)
	_connect_button_sounds($CenterContainer/VBoxContainer/SettingsButton)
	_connect_button_sounds($CenterContainer/VBoxContainer/QuitButton)

func _on_start_button_pressed() -> void:
	GameServer.start_client()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _connect_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_hover))
	button.pressed.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_click))

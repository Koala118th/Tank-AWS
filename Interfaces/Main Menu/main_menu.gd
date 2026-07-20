extends Control
class_name Main_menu

func _ready():
	var buttons = get_tree().get_nodes_in_group("ui_buttons")
	print("[MainMenu] Found %d buttons in ui_buttons group" % buttons.size())
	for button in buttons:
		print("[MainMenu] Connecting sounds to: ", button.name)
		_connect_button_sounds(button)

func _on_start_button_pressed() -> void:
	GameServer.start_client()

func _connect_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_hover))
	button.pressed.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_click))

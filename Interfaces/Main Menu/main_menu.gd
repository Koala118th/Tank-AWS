extends Control
class_name Main_menu
@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var socketNode: Node = $SocketNode

# ─────────────────────────────────────────
#  LIFE CYCLE
# ─────────────────────────────────────────
func _ready():
	#Connect sound 
	_connect_button_sounds($CenterContainer/VBoxContainer/PlayButton)
	_connect_button_sounds($CenterContainer/VBoxContainer/SettingsButton)
	_connect_button_sounds($CenterContainer/VBoxContainer/QuitButton)
	
	if GameServer.is_server_mode():
		GameLiftBridge.InitGameLift(GameServer.get_port_from_args())

func _on_start_button_pressed() -> void:
	play_button.disabled = true
	socketNode.open_client() 
	
func _on_game_start() -> void:
	print("game start")
	socketNode.close_client()
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

# ─────────────────────────────────────────
#  HELPER FUNCTIONS
# ─────────────────────────────────────────
func _connect_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_hover))
	button.pressed.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_click))

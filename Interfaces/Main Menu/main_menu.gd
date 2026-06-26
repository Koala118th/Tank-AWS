extends Control
class_name Main_menu
# ─────────────────────────────────────────
#  SCENE
# ─────────────────────────────────────────
func _ready() -> void:
	GameServer.game_started.connect(_on_game_start)
	
func _on_start_button_pressed() -> void:
	GameServer.start_client()

func _on_game_start() -> void:
	print("game start")
	get_tree().change_scene_to_file("res://Scenes/game.tscn")
	

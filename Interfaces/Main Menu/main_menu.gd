extends Control
class_name Main_menu

func _on_start_button_pressed() -> void:
	GameServer.start_client()

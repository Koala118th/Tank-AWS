extends Node2D
class_name Maze

func _ready() -> void:
	#Server nodes
	var playerManager = GameServer.playerManager
	playerManager.game_reloaded.connect(reload_self)

func reload_self() -> void:
	get_tree().reload_current_scene()

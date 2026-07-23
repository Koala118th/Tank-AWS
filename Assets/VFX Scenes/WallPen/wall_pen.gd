extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(0.07).timeout
	
	queue_free()

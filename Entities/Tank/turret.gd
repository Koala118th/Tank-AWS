extends Node2D


func _process(delta):
	look_at(get_global_mouse_position())
	rotation += deg_to_rad(90)

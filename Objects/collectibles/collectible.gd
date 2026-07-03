extends Node2D
class_name Collectible

var bullet_scene: PackedScene = null

func _ready() -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("tank"):
		return
	if bullet_scene == null:
		push_warning("Collectible: bullet_scene not set on %s" % name)
		return
	body.current_ammo = bullet_scene
	queue_free()

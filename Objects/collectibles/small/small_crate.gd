extends Collectible

@export var small_bullet: PackedScene

func _ready() -> void:
	bullet_scene = small_bullet
	super._ready()

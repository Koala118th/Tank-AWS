extends Collectible
@export var sniper_bullet: PackedScene

func _ready() -> void:
	bullet_scene = sniper_bullet
	ammo_type = 1
	super._ready()

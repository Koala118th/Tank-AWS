extends Collectible

@export var chaser_bullet: PackedScene

func _ready() -> void:
	bullet_scene = GameServer.projectileManager.AmmoType.CHASER
	super._ready()

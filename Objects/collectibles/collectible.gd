extends Node2D
class_name Collectible

var bullet_scene = null
var crate_id: int = -1
var ammo_type: int = 0

func _ready() -> void:
	if not $Area2D.body_entered.is_connected(_on_body_entered):
		$Area2D.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("tank"):
		return
	if not body.is_multiplayer_authority():
		return

	# Apply locally for instant feedback
	body.current_ammo = ammo_type
	body.flash_grey()

	if crate_id != -1:
		GameServer.collectibleManager.notify_crate_picked_up_rpc.rpc_id(1, crate_id, body.owner_id)

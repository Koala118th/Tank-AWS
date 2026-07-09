extends Node2D
class_name Collectible

var bullet_scene = null
var crate_id: int = -1

func _ready() -> void:
	if not $Area2D.body_entered.is_connected(_on_body_entered):
		$Area2D.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("tank"):
		return

	if not body.is_multiplayer_authority():
		return

	if bullet_scene == null:
		return

	body.current_ammo = bullet_scene
	body.flash_grey()

	if crate_id != -1:
		GameServer.collectibleManager.notify_crate_picked_up_rpc.rpc_id(1, crate_id)
	else:
		push_warning("[Collectible] crate_id is -1, cannot notify server!")

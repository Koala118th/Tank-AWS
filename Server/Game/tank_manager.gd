extends Node

signal tank_spawned(peer_id: int, assigned_slot)

# Called by a client once its (post-reload) TankSpawner is ready. The server
# replies with deliver_spawns, targeted only at that peer, so the client
# never receives a spawn before its own TankSpawner exists to receive it.
@rpc("any_peer", "call_remote", "reliable")
func request_spawns(requesting_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var playerManager = GameServer.playerManager
	var slots: Dictionary = playerManager.slots
	for slot in slots.keys():
		if slots[slot] != null:
			deliver_spawns.rpc_id(requesting_peer_id, slots[slot], slot)

@rpc("authority", "call_remote", "reliable")
func deliver_spawns(peer_id: int, assigned_slot) -> void:
	tank_spawned.emit(peer_id, assigned_slot)
	print(multiplayer.get_unique_id() , " received spawn for ", peer_id, " at slot ", assigned_slot)

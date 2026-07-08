extends Node

signal tank_spawned(peer_id: int, assigned_slot)
signal tank_moved(peer_id: int, pos: Vector2, body_rot: float, turret_rot: float)
var tanks := {}

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


@rpc("any_peer", "call_remote", "unreliable_ordered")
func update_transform(peer_id: int, pos: Vector2, body_rot: float, turret_rot: float) -> void:
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		if sender_id != peer_id:
			return  # reject anyone trying to move someone else's tank
		tank_moved.emit(peer_id, pos, body_rot, turret_rot)
		for p in multiplayer.get_peers():
			if p != sender_id:
				update_transform.rpc_id(p, peer_id, pos, body_rot, turret_rot)
	else:
		tank_moved.emit(peer_id, pos, body_rot, turret_rot)


@rpc("authority", "call_remote", "reliable")
func sync_health(id: int, new_health: float):
	if multiplayer.is_server():
		return
	
	var tank = find_tank_by_owner(id)
	if not tank:
		return

	var was_alive = tank._health > 0
	
	tank._health = new_health

	# Trigger death on client
	if was_alive and new_health == 0:
		tank.die()


func find_tank_by_owner(peer_id: int) -> Node:
	for tank in get_tree().get_nodes_in_group("tank"):
		if tank.owner_id == peer_id:
			return tank
	return null

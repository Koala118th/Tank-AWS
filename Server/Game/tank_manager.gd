extends Node

signal tank_spawned(peer_id: int, assigned_slot: int, spawn_pos: Vector2)
signal tank_moved(peer_id: int, pos: Vector2, body_rot: float, turret_rot: float)
signal spawns_ready
var tanks := {}

@rpc("authority", "call_remote", "reliable")
func notify_spawns_ready() -> void:
	spawns_ready.emit()

@rpc("any_peer", "call_remote", "reliable")
func request_spawns(requesting_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var playerManager = GameServer.playerManager
	var spawner = get_tree().get_nodes_in_group("tank_spawner")
	if spawner.is_empty():
		return
	var tank_spawner = spawner[0]
	for pid in playerManager.actives_players:
		var slot = playerManager.get_player_slot(pid)
		var pos: Vector2 = tank_spawner.get_spawn_position(pid)
		deliver_spawns.rpc_id(requesting_peer_id, pid, slot, pos)

@rpc("authority", "call_remote", "reliable")
func deliver_spawns(peer_id: int, assigned_slot: int, spawn_pos: Vector2) -> void:
	tank_spawned.emit(peer_id, assigned_slot, spawn_pos)
	print(multiplayer.get_unique_id(), " received spawn for ", peer_id, " at slot ", assigned_slot)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func update_transform(peer_id: int, pos: Vector2, body_rot: float, turret_rot: float) -> void:
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		if sender_id != peer_id:
			return
		tank_moved.emit(peer_id, pos, body_rot, turret_rot)
		for p in multiplayer.get_peers():
			if p != sender_id:
				update_transform.rpc_id(p, peer_id, pos, body_rot, turret_rot)
	else:
		tank_moved.emit(peer_id, pos, body_rot, turret_rot)

@rpc("authority", "call_remote", "reliable")
func clear_tanks() -> void:
	var spawners = get_tree().get_nodes_in_group("tank_spawner")
	if spawners.size() > 0:
		spawners[0].clear_tanks_client()

@rpc("authority", "call_remote", "reliable")
func sync_health(id: int, new_health: float):
	if multiplayer.is_server():
		return
	
	var tank = find_tank_by_owner(id)
	if not tank:
		return

	var was_alive = tank._health > 0
	
	tank._health = new_health
	tank.flash_red()

	if was_alive and new_health == 0:
		tank.die()

@rpc("authority", "call_remote", "reliable")
func sync_delete_tank(owner_peer_id: int) -> void:
	if multiplayer.is_server():
		return

	print("sync_delete_tank received on peer ", multiplayer.get_unique_id(), " for owner ", owner_peer_id)
	var spawners = get_tree().get_nodes_in_group("tank_spawner")
	if spawners.size() > 0:
		spawners[0].remove_tank_by_owner(owner_peer_id)
	else:
		print("sync_delete_tank found no tank_spawner for owner ", owner_peer_id)


func find_tank_by_owner(peer_id: int) -> Node:
	print("find_tank_by_owner on peer ", multiplayer.get_unique_id(), " searching for owner ", peer_id)
	for tank in get_tree().get_nodes_in_group("tank"):
		if tank.owner_id == peer_id:
			print("find_tank_by_owner matched tank ", tank, " for owner ", peer_id)
			return tank
	print("find_tank_by_owner did not find owner ", peer_id)
	return null

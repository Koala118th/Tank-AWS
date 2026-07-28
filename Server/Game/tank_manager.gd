extends Node

signal tank_spawned(peer_id: int, assigned_slot: int, spawn_pos: Vector2)
signal spawns_ready
var tanks := {}
var tank_ammo: Dictionary = {}
var tank_ammo_remaining: Dictionary = {}

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


var last_processed_seq: int = 0
@rpc("any_peer", "call_remote", "unreliable")
func send_input(input: Dictionary):
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	var tank = find_tank_by_owner(sender_id)
	
	if tank == null:
		print("Tank not found for peer: ", sender_id)
		return
	
	tank.current_input = input


@rpc("authority", "call_remote", "unreliable")
func sync_state(id: int, pos: Vector2, body_rot: float, turret_rot: float, last_seq: int):
	if multiplayer.is_server():
		return
	
	var tank = find_tank_by_owner(id)
	
	if not is_instance_valid(tank):
		return
	
	tank.apply_server_state(pos, body_rot, turret_rot, last_seq)


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
	var death_pos: Vector2 = tank.global_position
	AudioManager.play_game(AudioManager.sfx_impact, death_pos)

	if was_alive and new_health == 0:
		tank.die()

@rpc("authority", "call_remote", "reliable")
func sync_delete_tank(owner_peer_id: int) -> void:
	if multiplayer.is_server():
		return

	var spawners = get_tree().get_nodes_in_group("tank_spawner")
	if spawners.size() > 0:
		spawners[0].remove_tank_by_owner(owner_peer_id)
	else:
		print("sync_delete_tank found no tank_spawner for owner ", owner_peer_id)


# Broadcast ammo change to all peers so they render the correct bullet visually
@rpc("authority", "call_local", "reliable")
func sync_ammo(tank_peer_id: int, ammo_type: int) -> void:
	var tank = find_tank_by_owner(tank_peer_id)
	if tank:
		tank.current_ammo = ammo_type


func find_tank_by_owner(peer_id: int) -> Node:
	for tank in get_tree().get_nodes_in_group("tank"):
		if tank.owner_id == peer_id:
			return tank
	return null


func set_tank_ammo(tank_peer_id: int, ammo_type: int, remaining: int) -> void:
	tank_ammo[tank_peer_id] = ammo_type
	tank_ammo_remaining[tank_peer_id] = remaining


func get_tank_ammo(tank_peer_id: int) -> int:
	return tank_ammo.get(tank_peer_id, 0)


func consume_ammo(tank_peer_id: int) -> void:
	if not tank_ammo_remaining.has(tank_peer_id):
		return
	var remaining: int = tank_ammo_remaining[tank_peer_id]
	if remaining == -1:
		return  # unlimited, do nothing
	remaining -= 1
	tank_ammo_remaining[tank_peer_id] = remaining
	if remaining <= 0:
		_reset_to_default(tank_peer_id)


func _reset_to_default(tank_peer_id: int) -> void:
	tank_ammo[tank_peer_id] = 0
	tank_ammo_remaining[tank_peer_id] = -1
	sync_ammo.rpc(tank_peer_id, 0)


# Clear ammo state between matches
func reset_ammo() -> void:
	tank_ammo.clear()
	tank_ammo_remaining.clear()

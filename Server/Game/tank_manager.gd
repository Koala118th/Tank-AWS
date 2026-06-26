extends Node

signal tank_spawned(peer_id: int, assigned_slot)

@rpc("authority", "call_remote")
func relay_spawn_tank(peer_id: int, assigned_slot) -> void:
	tank_spawned.emit(peer_id, assigned_slot)

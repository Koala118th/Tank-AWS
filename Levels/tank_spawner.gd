extends Node2D

@export var tank_scene: PackedScene
@export var tank_count: int = 4
@export var maze_generator: Node2D
var tanks: Dictionary = {} 

func _ready():
	await get_tree().process_frame

	#Server nodes
	var playerManager = GameServer.playerManager
	var tankManager = GameServer.tankManager
		
	if GameServer.is_server_mode():
		var slots: Dictionary = playerManager.slots
		for slot in slots.keys():
			if slots[slot] != null:
				spawn_tank(slots[slot], slot)
		playerManager.slot_filled.connect(spawn_tank)
	else:
		print("READY")
		print(self)
		print(get_path())
		print(multiplayer)
		print(multiplayer.multiplayer_peer)
		for c in tankManager.tank_spawned.get_connections():
			tankManager.tank_spawned.disconnect(c["callable"])
		
		tankManager.tank_spawned.connect(spawn_tank)
		tankManager.request_spawns.rpc_id(1, multiplayer.get_unique_id())


func spawn_tank():
	if maze_generator == null:
		push_error("TankSpawner: maze_generator is not assigned!")
		return

	var floor_positions: Array = maze_generator.get_floor_positions()

	if floor_positions.is_empty():
		push_error("TankSpawner: no floor positions found!")
		return

	if floor_positions.size() < tank_count:
		push_error("TankSpawner: not enough floor positions (", floor_positions.size(), ") for ", tank_count, " tanks!")
		return

	floor_positions.shuffle()

	for i in range(tank_count):
		var tank: Tank = tank_scene.instantiate()
		tank.set_multiplayer_authority(owner_peer_id)
		print("SPAWN")
		print(self)
		print(get_path())
		print(multiplayer)
		print(multiplayer.multiplayer_peer)
		
		print(multiplayer.get_unique_id(), " spawn a tank for ", owner_peer_id, " at ", spawn_index, ": ", tank)
		var spawn_marker: Marker2D = _tank_spawn_locations.get_child(spawn_index)
		tank.position = floor_positions[i]
		add_child(tank)

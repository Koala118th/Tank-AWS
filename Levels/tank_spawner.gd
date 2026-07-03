extends Node2D

@export var tank_scene: PackedScene
@export var game_over_screen: CanvasLayer

@export var tank_count: int = 1
@export var maze_generator: Node2D
var tanks: Dictionary = {} 
var match_number: int = 1

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
		#print("READY")
		#print(self)
		#print(get_path())
		#print(multiplayer)
		#print(multiplayer.multiplayer_peer)
		for c in tankManager.tank_spawned.get_connections():
			tankManager.tank_spawned.disconnect(c["callable"])
		
		tankManager.tank_spawned.connect(spawn_tank)
		tankManager.request_spawns.rpc_id(1, multiplayer.get_unique_id())


func spawn_tank(owner_peer_id: int, spawn_index: int):
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

	var tank: Tank = tank_scene.instantiate()
	tank.set_multiplayer_authority(owner_peer_id)
	print("SPAWN")
	#print(self)
	#print(get_path())
	#print(multiplayer)
	#print(multiplayer.multiplayer_peer)
	
	print(multiplayer.get_unique_id(), " spawn a tank for ", owner_peer_id, " at ", spawn_index, ": ", tank)
	tank.position = floor_positions[spawn_index]
	tank.owner_id = owner_peer_id
	tank.tree_exited.connect(_on_tank_died)
	add_child(tank)



func get_tanks_alive() -> int:
	var count = 0
	for child in get_children():
		if child is Tank:
			count += 1
	return count

func _on_tank_died():
	if not is_inside_tree():
		return

	await get_tree().process_frame

	if not is_inside_tree():
		return

	var tanks_alive = get_tanks_alive()
	print("Tanks remaining: ", tanks_alive)
	
	if tanks_alive == 1:
		_on_round_over()

func _on_round_over():
	for child in get_children():
		if child is Tank:
			print("Winner: ", child.name)
			break
	
	if game_over_screen != null:
		game_over_screen.show_screen(game_over_screen.placeholder_scores, match_number)
	else:
		print("ERROR: game_over_screen not assigned in Inspector!")

func start_next_match():
	match_number += 1

	get_tree().change_scene_to_file("res://Scenes/game.tscn")

extends Node2D

@export var tank_scene: PackedScene
@export var game_over_screen: CanvasLayer
@export var tank_count: int = 1
@export var maze_generator: Node2D

var tanks: Dictionary = {}
var match_number: int = 1
var _match_active: bool = false

func _ready():
	add_to_group("tank_spawner")
	await get_tree().process_frame

	var playerManager = GameServer.playerManager
	var tankManager = GameServer.tankManager

	if GameServer.is_server_mode():
		playerManager.match_begun.connect(_on_match_begun_server)
	else:
		for c in tankManager.tank_spawned.get_connections():
			tankManager.tank_spawned.disconnect(c["callable"])
		tankManager.tank_spawned.connect(spawn_tank)

		for c in tankManager.spawns_ready.get_connections():
			tankManager.spawns_ready.disconnect(c["callable"])
		tankManager.spawns_ready.connect(_on_spawns_ready)

		var my_id = multiplayer.get_unique_id()
		print("TANKSPAWNER READY — peer: ", my_id,
			" pending_screen: ", GameServer.pending_screen,
			" pending_match_state: ", GameServer.pending_match_state)

func _on_spawns_ready():
	var my_id = multiplayer.get_unique_id()
	GameServer.tankManager.request_spawns.rpc_id(1, my_id)

func _on_match_begun_server():
	_clear_tanks()
	await get_tree().process_frame
	_match_active = true
	var playerManager = GameServer.playerManager
	for pid in playerManager.actives_players:
		var slot = playerManager.get_player_slot(pid)
		spawn_tank(pid, slot)

# ─────────────────────────────────────────
#  SERVER
# ─────────────────────────────────────────
func _on_game_reloaded_server():
	_clear_tanks()
	var playerManager = GameServer.playerManager
	for pid in playerManager.actives_players:
		var slot = playerManager.get_player_slot(pid)
		spawn_tank(pid, slot)

# ─────────────────────────────────────────
#  CLIENT
# ─────────────────────────────────────────
func _on_game_reloaded_client():
	GameServer.tankManager.request_spawns.rpc_id(1, multiplayer.get_unique_id())

# ─────────────────────────────────────────
#  SHARED
# ─────────────────────────────────────────
func spawn_tank(owner_peer_id: int, spawn_index: int):
	if maze_generator == null:
		push_error("TankSpawner: maze_generator is not assigned!")
		return
	var floor_positions: Array = maze_generator.get_floor_positions()
	if floor_positions.is_empty():
		push_error("TankSpawner: no floor positions found!")
		return

	floor_positions.shuffle()
	var tank: Tank = tank_scene.instantiate()
	tank.set_multiplayer_authority(owner_peer_id)
	tank.position = floor_positions[spawn_index]
	tank.owner_id = owner_peer_id
	tank.tree_exited.connect(_on_tank_died)
	add_child(tank)

	print(multiplayer.get_unique_id(), " spawn a tank for ", owner_peer_id, " at slot ", spawn_index)

	if multiplayer.is_server():
		if get_tanks_alive() == 1:
			GameServer.collectibleManager.start_timer()

func _clear_tanks():
	_match_active = false
	for child in get_children():
		if child is Tank:
			child.tree_exited.disconnect(_on_tank_died)
			child.free()

func clear_tanks_client():
	for child in get_children():
		if child is Tank:
			child.tree_exited.disconnect(_on_tank_died)
			child.queue_free()

# ─────────────────────────────────────────
#  ROUND END
# ─────────────────────────────────────────
func get_tanks_alive() -> int:
	var count = 0
	for child in get_children():
		if child is Tank:
			count += 1
	return count

func _on_tank_died():
	if not _match_active:
		return
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var tanks_alive = get_tanks_alive()
	print("Tanks remaining: ", tanks_alive)
	if tanks_alive == 1:
		_match_active = false
		_on_round_over()

func _on_round_over():
	if not multiplayer.is_server():
		return
	
	var winner_id = -1
	for child in get_children():
		if child is Tank:
			winner_id = child.owner_id
			break
	
	print("SERVER: Round over. Winner id: ", winner_id)
	GameServer.on_match_ended(winner_id)

func start_next_match():
	match_number += 1

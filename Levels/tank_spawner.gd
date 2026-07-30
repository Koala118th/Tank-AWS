extends Node2D

@export var tank_scene: PackedScene
@export var game_over_screen: CanvasLayer
@export var tank_count: int = 1
@export var maze_generator: Node2D

var tanks: Dictionary = {}
var match_number: int = 1
var _match_active: bool = false
var _spawn_positions: Dictionary = {}
var _spawns_requested: bool = false

func _ready():
	add_to_group("tank_spawner")
	_spawns_requested = false  # reset on every scene load
	await get_tree().process_frame

	var playerManager = GameServer.playerManager
	var tankManager = GameServer.tankManager

	if GameServer.is_server_mode():
		if playerManager.match_begun.is_connected(_on_match_begun_server):
			playerManager.match_begun.disconnect(_on_match_begun_server)
		playerManager.match_begun.connect(_on_match_begun_server)
		return

	for c in tankManager.tank_spawned.get_connections():
		tankManager.tank_spawned.disconnect(c["callable"])
	tankManager.tank_spawned.connect(
		func(peer_id: int, slot: int, pos: Vector2):
			spawn_tank(peer_id, slot, pos)
	)

	for c in tankManager.spawns_ready.get_connections():
		tankManager.spawns_ready.disconnect(c["callable"])

	var my_id = multiplayer.get_unique_id()
	print("TANKSPAWNER READY — peer: ", my_id,
		" pending_screen: ", GameServer.matchManager.pending_screen,
		" pending_match_state: ", GameServer.matchManager.pending_match_state)

	if GameServer.matchManager.pending_screen == "spectator" \
	and GameServer.matchManager.pending_match_state == 2:
		# IN_MATCH spectator — request immediately
		_request_spawns_once()
	else:
		tankManager.spawns_ready.connect(_on_spawns_ready)

func _on_spawns_ready():
	_request_spawns_once()

func _request_spawns_once() -> void:
	if _spawns_requested:
		return
	_spawns_requested = true
	GameServer.tankManager.request_spawns.rpc_id(1, multiplayer.get_unique_id())

func _on_match_begun_server():
	_clear_tanks()
	await get_tree().process_frame
	_match_active = true
	var playerManager = GameServer.playerManager

	# Server shuffles ONCE and records positions
	var floor_positions: Array = maze_generator.get_floor_positions()
	floor_positions.shuffle()

	for pid in playerManager.actives_players:
		var slot = playerManager.get_player_slot(pid)
		var pos: Vector2 = floor_positions[slot]
		_spawn_positions[pid] = pos
		spawn_tank(pid, slot, pos)

# ─────────────────────────────────────────
#  SERVER
# ─────────────────────────────────────────
func _on_game_reloaded_server():
	_clear_tanks()
	var playerManager = GameServer.playerManager
	for pid in playerManager.actives_players:
		var slot = playerManager.get_player_slot(pid)
		spawn_tank(pid, slot)

func _on_tank_removed_recheck_round_end() -> void:
	if not multiplayer.is_server():
		return
	if not _match_active:
		return
	await get_tree().process_frame
	if not _match_active:
		return
	var alive := get_tanks_alive()
	print("Recheck after removal — tanks alive: ", alive)
	if alive <= 1:
		_on_round_over()



# ─────────────────────────────────────────
#  CLIENT
# ─────────────────────────────────────────
func _on_game_reloaded_client():
	GameServer.tankManager.request_spawns.rpc_id(1, multiplayer.get_unique_id())

# ─────────────────────────────────────────
#  SHARED
# ─────────────────────────────────────────
func get_spawn_position(peer_id: int) -> Vector2:
	return _spawn_positions.get(peer_id, Vector2.ZERO)

func spawn_tank(owner_peer_id: int, spawn_index: int, spawn_pos: Vector2 = Vector2.ZERO):
	if maze_generator == null:
		push_error("TankSpawner: maze_generator is not assigned!")
		return

	# Server uses pre-shuffled position, clients use position sent from server
	var pos: Vector2
	if multiplayer.is_server():
		pos = spawn_pos
	else:
		pos = spawn_pos  # comes from deliver_spawns → tank_spawned signal

	var tank: Tank = tank_scene.instantiate()
	tank.set_multiplayer_authority(owner_peer_id)
	tank.position = pos
	tank.owner_id = owner_peer_id
	tank.tree_exited.connect(_on_tank_died)
	add_child(tank)
	tanks[owner_peer_id] = tank

	print(multiplayer.get_unique_id(), " spawn a tank for ", owner_peer_id, " at slot ", spawn_index)
	tank.setup_spawn_index(spawn_index)

	if multiplayer.is_server():
		if get_tanks_alive() == 1:
			GameServer.collectibleManager.start_timer()

func _clear_tanks():
	_match_active = false
	for child in get_children():
		if child is Tank:
			if child.tree_exited.is_connected(_on_tank_died):
				child.tree_exited.disconnect(_on_tank_died)
			child.free()
	tanks.clear()

func clear_tanks_client():
	for child in get_children():
		if child is Tank:
			child.tree_exited.disconnect(_on_tank_died)
			child.queue_free()
	tanks.clear()

func remove_tank_by_owner(owner_peer_id: int) -> void:
	for child in get_children():
		if child is Tank and child.owner_id == owner_peer_id:
			if child.tree_exited.is_connected(_on_tank_died):
				child.tree_exited.disconnect(_on_tank_died)
			child.queue_free()
			tanks.erase(owner_peer_id)
			print(multiplayer.get_unique_id(), " removed tank for owner ", owner_peer_id)
			if _match_active:
				call_deferred("_on_tank_removed_recheck_round_end")
			return
	print(multiplayer.get_unique_id(), " could not find tank for owner ", owner_peer_id, " to remove")



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
	if not _match_active:
		return

	var tanks_alive := get_tanks_alive()
	print("Tanks remaining: ", tanks_alive)
	if tanks_alive <= 1:
		_on_round_over()


func _on_round_over():
	if not multiplayer.is_server():
		return

	if not _match_active:
		return
	_match_active = false

	if get_tanks_alive() > 1:
		return


	var winner_id = -1
	for child in get_children():
		if child is Tank:
			winner_id = child.owner_id
			break

	print("SERVER: Round over. Winner id: ", winner_id)
	GameServer.matchManager.on_match_ended(winner_id)


func start_next_match():
	match_number += 1

extends Node

var maze_generator: Node2D = null

enum CrateType { SNIPER, CHASER, SMALL, LASER }

const MAX_COLLECTIBLES: int = 3
const SPAWN_INTERVAL: float = 10.0

# Server-side state
var _spawn_timer: Timer
var _active_crates: Dictionary = {}
var _next_id: int = 0

# Client-side spawner reference
var _collectible_spawner: Node2D = null

func _get_ammo_remaining(crate_type: int) -> int:
	match crate_type:
		1: return 3
		2: return 3
		3: return 30
		4: return 3
	return -1

func init_collectibles(spawner_node: Node) -> void:
	_collectible_spawner = spawner_node

func start_timer() -> void:
	if not multiplayer.is_server():
		return
	if _spawn_timer != null:
		return
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = SPAWN_INTERVAL
	_spawn_timer.autostart = false
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	_spawn_timer.start()
	print("[CollectibleManager] Timer started")

func _on_spawn_timer_timeout() -> void:
	if _active_crates.size() >= MAX_COLLECTIBLES:
		return
	_do_spawn()

func _do_spawn() -> void:
	if _collectible_spawner == null:
		return
	var floor_positions: Array = _collectible_spawner.maze_generator.get_floor_positions()
	if floor_positions.is_empty():
		return

	var valid_positions: Array = floor_positions.filter(func(pos):
		for data in _active_crates.values():
			if (data["position"] as Vector2).distance_to(pos) < 64.0:
				return false
	
		var tanks := get_tree().get_nodes_in_group("tank")
		for tank in tanks:
			if tank.global_position.distance_to(pos) < 150.0:
				return false
		return true
	)
	if valid_positions.is_empty():
		print("[CollectibleManager] No valid positions far enough from tanks, skipping spawn")
		return

	valid_positions.shuffle()
	var chosen_pos: Vector2 = valid_positions[0]
	var chosen_type: int = randi() % 4 + 1
	var crate_id: int = _next_id
	_next_id += 1

	_active_crates[crate_id] = { "type": chosen_type, "position": chosen_pos }
	receive_crate_spawned.rpc(crate_id, chosen_type, chosen_pos)

func reset() -> void:
	if not multiplayer.is_server():
		return

	if _spawn_timer != null:
		_spawn_timer.stop()
		_spawn_timer.queue_free()
		_spawn_timer = null
	_active_crates.clear()
	receive_clear_all.rpc()

@rpc("authority", "call_local", "reliable")
func receive_clear_all() -> void:
	if _collectible_spawner == null:
		return
	_collectible_spawner.clear_all()

@rpc("any_peer", "call_remote", "reliable")
func notify_crate_picked_up_rpc(crate_id: int, tank_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not _active_crates.has(crate_id):
		push_warning("[CollectibleManager] crate_id %d not found!" % crate_id)
		return

	var crate_type: int = _active_crates[crate_id]["type"]
	_active_crates.erase(crate_id)

	var ammo_remaining: int = _get_ammo_remaining(crate_type)
	GameServer.tankManager.set_tank_ammo(tank_peer_id, crate_type, ammo_remaining)
	GameServer.tankManager.sync_ammo.rpc(tank_peer_id, crate_type)
	receive_crate_removed.rpc(crate_id)

	if is_inside_tree() and _spawn_timer != null:
		_spawn_timer.stop()
		_spawn_timer.start()

@rpc("authority", "call_local", "reliable")
func receive_crate_spawned(crate_id: int, crate_type: int, pos: Vector2) -> void:
	if _collectible_spawner == null:
		push_warning("[CollectibleManager] _collectible_spawner is null!")
		return
	_collectible_spawner.spawn_crate(crate_id, crate_type, pos)

@rpc("authority", "call_local", "reliable")
func receive_crate_removed(crate_id: int) -> void:
	if _collectible_spawner == null:
		push_warning("[CollectibleManager] _collectible_spawner is null!")
		return
	_collectible_spawner.remove_crate(crate_id)

@rpc("any_peer", "call_remote", "reliable")
func request_crates() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	for crate_id in _active_crates:
		var data = _active_crates[crate_id]
		receive_crate_spawned.rpc_id(sender_id, crate_id, data["type"], data["position"])

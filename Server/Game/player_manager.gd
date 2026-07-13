extends Node
# ─────────────────────────────────────────
#  SIGNALS
# ─────────────────────────────────────────

signal slot_filled(peer_id: int, slot: int)
signal player_needs_waiting_screen(peer_id: int)
signal player_needs_spectator_screen(peer_id: int, current_match_state: int)
signal ready_to_start
signal game_reloaded
signal match_begun

# ─────────────────────────────────────────
#  SLOT MANAGEMENT
# ─────────────────────────────────────────
var slots: Dictionary = {
	0: null,
	1: null,
	2: null,
	3: null,
}

func assign_slot(peer_id: int, match_state: int) -> int:
	var slot = get_empty_slot()
	if slot == -1:
		return -1
	slots[slot] = peer_id
	player_count += 1
	slot_filled.emit(peer_id, slot)

	_route_new_player(peer_id, match_state)
	load_game_scene.rpc_id(peer_id)

	return slot

func remove_slot(peer_id: int) -> void:
	for slot in slots.keys():
		if slots[slot] == peer_id:
			slots[slot] = null
			player_count -= 1
			actives_players.erase(peer_id)
			spectators.erase(peer_id)
			disconnected_players.erase(peer_id)
			print("SERVER: Player ", peer_id, " removed from slot ", slot)
			return

func get_player_slot(peer_id: int) -> int:
	for slot in slots.keys():
		if slots[slot] == peer_id:
			return slot
	return -1

func get_empty_slot() -> int:
	for slot in slots.keys():
		if slots[slot] == null:
			return slot
	return -1

# ─────────────────────────────────────────
#  ROUTING
# ─────────────────────────────────────────
func _route_new_player(peer_id: int, match_state: int) -> void:
	match match_state:
		0: # WAITING
			if player_count == 1:
				make_active_player(peer_id)
				player_needs_waiting_screen.emit(peer_id)
			elif player_count == 2:
				make_active_player(peer_id)
				ready_to_start.emit()
		1, 2:
			make_spectator(peer_id)
			player_needs_spectator_screen.emit(peer_id, match_state)

# ─────────────────────────────────────────
#  PLAYER MANAGEMENT
# ─────────────────────────────────────────
var player_count: int = 0
var actives_players: Array = []
var spectators: Array = []
var disconnected_players: Array = []

func mark_disconnected(peer_id: int) -> void:
	if peer_id not in disconnected_players:
		disconnected_players.append(peer_id)
	print("SERVER: Player ", peer_id, " marked as disconnected — tank stays alive")

func make_active_player(peer_id: int) -> void:
	spectators.erase(peer_id)
	if peer_id not in actives_players:
		actives_players.append(peer_id)

func make_spectator(peer_id: int) -> void:
	actives_players.erase(peer_id)
	if peer_id not in spectators:
		spectators.append(peer_id)

# ─────────────────────────────────────────
#  GAME MANAGEMENT
# ─────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func begin_match() -> void:
	if multiplayer.is_server():
		sync_active_players.rpc(actives_players)
		match_begun.emit()

@rpc("authority", "call_remote", "reliable")
func sync_active_players(active_list: Array) -> void:
	actives_players = active_list
	print("SYNC — actives: ", actives_players, " on peer: ", multiplayer.get_unique_id())
	match_begun.emit()

@rpc("authority", "call_local", "reliable")
func reload_game() -> void:
	actives_players.clear()
	spectators.clear()
	for slot in slots.keys():
		if slots[slot] != null:
			make_active_player(slots[slot])
	print("RELOAD — actives: ", actives_players, " spectators: ", spectators, " on peer: ", multiplayer.get_unique_id())
	game_reloaded.emit()

@rpc("authority", "call_remote", "reliable")
func load_game_scene():
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

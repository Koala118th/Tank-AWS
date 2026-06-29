extends Node
# ─────────────────────────────────────────
#  SLOT MANAGEMENT
# ─────────────────────────────────────────
signal slot_filled(peer_id: int, slot: int)
var slots: Dictionary = {
	0: null,
	1: null,
	2: null,
	3: null,
}
func assign_slot(peer_id: int):
	var slot = get_empty_slot()
	if slot != -1:
		slots[slot] = peer_id
		player_count += 1
		slot_filled.emit(peer_id, slot)
		return slot
		
		#if player_count <= 2:
			#reload_game.rpc()
		#elif player_count >=3:
			#make_spectator(peer_id)
	return -1


func remove_slot(peer_id: int) -> void:
	var slot = get_player_slot(peer_id)
	if slot != -1:
		slots[slot] = null
		player_count -= 1

func get_player_slot(peer_id) -> int:
	for slot in slots.keys():
		if slots[slot] == peer_id:
			slots[slot] = null
			return slot
	
	return -1
	
func get_empty_slot() -> int:
	for slot in slots.keys():
		if slots[slot] == null:
			return slot
	return -1
# ─────────────────────────────────────────
# PLAYER MANAGEMENT
# ─────────────────────────────────────────
var player_count: int = 0
var actives_players: Array = []
var spectators: Array = []

func make_active_player(peer_id: int) -> void:
	spectators.erase(peer_id)
	actives_players.append(peer_id)

func make_spectator(peer_id: int) -> void:
	actives_players.erase(peer_id)
	spectators.append(peer_id)

# ─────────────────────────────────────────
#  GAME MANAGEMENT
# ─────────────────────────────────────────
signal game_reloaded

@rpc("authority","call_local")
func reload_game() -> void:
	actives_players.clear()
	spectators.clear()
	
	for slot in slots.keys():
		if slots[slot] != null:
			make_active_player(slots[slot])
	
	game_reloaded.emit()

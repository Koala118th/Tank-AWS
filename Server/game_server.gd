extends Node
# ─────────────────────────────────────────
#  MATCH STATE
# ─────────────────────────────────────────
enum MatchState { WAITING, STARTING, IN_MATCH }
var match_state: MatchState = MatchState.WAITING

var _countdown_timer: Timer = null
const COUNTDOWN_SECONDS = 5
const GAME_OVER_COUNTDOWN = 8

# ─────────────────────────────────────────
#  LIFE CYCLE
# ─────────────────────────────────────────
func _ready():
	if is_server_mode():
		pass
		
func is_server_mode() -> bool:
	return "--server" in OS.get_cmdline_args() \
		or DisplayServer.get_name() == "headless"

# ─────────────────────────────────────────
#  SERVER CONFIG
# ─────────────────────────────────────────
const PORT = 7777
const MAX_CLIENTS = 4
const SERVER_IP = "127.0.0.1"

@onready var playerManager      = $PlayerManager
@onready var tankManager        = $TankManager
@onready var mapManager         = $MapManager
@onready var collectibleManager = $CollectibleManager
@onready var projectileManager  = $ProjectileManager

func start_server():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		print("SERVER: Failed to start: ", err)
		return
	multiplayer.multiplayer_peer = peer
	print("SERVER: Listening on port ", PORT)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Listen to PlayerManager signals
	playerManager.player_needs_waiting_screen.connect(_on_player_needs_waiting_screen)
	playerManager.player_needs_spectator_screen.connect(_on_player_needs_spectator_screen)
	playerManager.player_needs_game_over_screen.connect(_on_player_needs_game_over_screen)
	playerManager.ready_to_start.connect(_on_ready_to_start)

	mapManager.start_maze()
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/game.tscn")

# ─────────────────────────────────────────
#  PEER EVENTS
# ─────────────────────────────────────────
func _on_peer_connected(id: int):
	print("SERVER: Player connected — id: ", id)
	playerManager.assign_slot(id, match_state)
	LeaderboardManager.register_player(id)

func _on_peer_disconnected(id: int):
	print("SERVER: Player disconnected — id: ", id)
	var tank_spawner = _get_tank_spawner()
	if tank_spawner:
		print("SERVER: deleting tank for disconnected peer ", id)
		tank_spawner.remove_tank_by_owner(id)
		for peer_id in multiplayer.get_peers():
			tankManager.sync_delete_tank.rpc_id(peer_id, id)
	GameLiftBridge.RemovePlayerSession(player_session_store[id])
	player_session_store.erase(id)
	playerManager.remove_slot(id)
	# If server is now empty, full reset
	if playerManager.player_count == 0:
		_reset_server()
	
	LeaderboardManager.remove_player(id)

func _reset_server() -> void:
	print("SERVER: No players remaining — resetting server state")
	# Cancel any running timers
	if _countdown_timer:
		_countdown_timer.stop()
		_countdown_timer.queue_free()
		_countdown_timer = null
	if _game_over_timer:
		_game_over_timer.stop()
		_game_over_timer.queue_free()
		_game_over_timer = null
	# Reset all state
	match_state = MatchState.WAITING
	collectibleManager.reset()
	playerManager._spectators_next_match.clear()
	playerManager._keep_spectator_next_match.clear()
	# Clear tanks and projectiles on server
	var tank_spawner = _get_tank_spawner()
	if tank_spawner:
		tank_spawner._clear_tanks()
	projectileManager.clear_all_projectiles()
	# Generate fresh maze ready for next players
	mapManager.start_maze()
	mapManager.pick_background()
	print("SERVER: Reset complete — waiting for players")

# ─────────────────────────────────────────
#  SIGNAL HANDLERS FROM PLAYER MANAGER
# ─────────────────────────────────────────
func _on_player_needs_waiting_screen(peer_id: int):
	notify_waiting.rpc_id(peer_id)

func _on_player_needs_spectator_screen(peer_id: int, current_match_state: int):
	var remaining: float = float(COUNTDOWN_SECONDS)
	if current_match_state == 1 and _countdown_timer != null:
		remaining = _countdown_timer.time_left
		print("SERVER: spectator joining, timer.time_left: ", remaining)
	notify_spectator.rpc_id(peer_id, current_match_state, remaining)

func _on_player_needs_game_over_screen(peer_id: int, remaining_time: float):
	notify_game_over_join.rpc_id(peer_id, remaining_time)

func _on_ready_to_start():
	_begin_countdown()

# ─────────────────────────────────────────
#  COUNTDOWN
# ─────────────────────────────────────────
var _countdown_start_time: float = 0.0
var _match_start_time: float = 0.0
var _game_over_timer: Timer = null

func _begin_countdown():
	match_state = MatchState.STARTING
	tankManager.clear_tanks.rpc()
	projectileManager.receive_clear_all.rpc()
	print("_begin_countdown — notifying actives: ", playerManager.actives_players)
	for pid in playerManager.actives_players:
		print("  sending notify_starting to: ", pid)
		notify_starting.rpc_id(pid, float(COUNTDOWN_SECONDS))
	for pid in playerManager.spectators:
		notify_spectator.rpc_id(pid, MatchState.STARTING, float(COUNTDOWN_SECONDS))

	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = COUNTDOWN_SECONDS
	_countdown_timer.one_shot = true
	_countdown_timer.timeout.connect(_on_countdown_finished)
	add_child(_countdown_timer)
	_countdown_timer.start()

func _cancel_countdown():
	if _countdown_timer:
		_countdown_timer.stop()
		_countdown_timer.queue_free()
		_countdown_timer = null
	match_state = MatchState.WAITING
	for pid in playerManager.actives_players:
		notify_waiting.rpc_id(pid)

func _on_countdown_finished():
	_countdown_timer.queue_free()
	_countdown_timer = null
	match_state = MatchState.IN_MATCH
	_start_match()

func _start_match():
	print("SERVER: Match starting!")
	playerManager.begin_match.rpc()
	await get_tree().process_frame
	await get_tree().process_frame
	tankManager.notify_spawns_ready.rpc()
	for pid in playerManager.spectators:
		notify_spectator.rpc_id(pid, MatchState.IN_MATCH, 0.0)

# ─────────────────────────────────────────
#  MATCH END
# ─────────────────────────────────────────

func on_match_ended(winner_id: int):
	match_state = MatchState.WAITING
	print("SERVER: Match ended. Winner: ", winner_id)
	LeaderboardManager.add_win(winner_id)
	LeaderboardManager.sync_leaderboard.rpc(LeaderboardManager.leaderboard)
	show_game_over(winner_id, float(GAME_OVER_COUNTDOWN))
	show_game_over.rpc(winner_id, float(GAME_OVER_COUNTDOWN))
	_start_game_over_countdown()

func _start_game_over_countdown():
	_game_over_timer = Timer.new()
	_game_over_timer.wait_time = GAME_OVER_COUNTDOWN
	_game_over_timer.one_shot = true
	_game_over_timer.timeout.connect(_on_game_over_finished)
	add_child(_game_over_timer)
	_game_over_timer.start()

func _on_game_over_finished():
	_game_over_timer.queue_free()
	_game_over_timer = null

	var future_actives: int = playerManager.actives_players.size() \
		+ playerManager.spectators.size() \
		+ playerManager._spectators_next_match.size()

	if future_actives <= 1:
		match_state = MatchState.WAITING
		playerManager._promote_queued_spectators()
		tankManager.clear_tanks.rpc()
		projectileManager.receive_clear_all.rpc()
		collectibleManager.reset()
		tankManager.reset_ammo()
		for pid in playerManager.actives_players + playerManager.spectators:
			notify_waiting.rpc_id(pid)
		return

	var needs_countdown: bool = playerManager._spectators_next_match.size() > 0
	print("needs_countdown: ", needs_countdown,
		" _spectators_next_match: ", playerManager._spectators_next_match,
		" _keep_spectator_next_match: ", playerManager._keep_spectator_next_match)

	collectibleManager.reset()
	tankManager.reset_ammo()
	projectileManager.receive_clear_all.rpc()
	playerManager.reload_game.rpc()
	mapManager.start_maze()
	mapManager.pick_background()
	await get_tree().process_frame

	if needs_countdown:
		match_state = MatchState.STARTING
		for pid in playerManager.actives_players:
			notify_starting.rpc_id(pid, float(COUNTDOWN_SECONDS))
		for pid in playerManager.spectators:
			notify_spectator.rpc_id(pid, MatchState.STARTING, float(COUNTDOWN_SECONDS))
		await get_tree().create_timer(float(COUNTDOWN_SECONDS)).timeout

	match_state = MatchState.IN_MATCH
	playerManager.begin_match.rpc()
	await get_tree().process_frame
	await get_tree().process_frame
	tankManager.clear_tanks.rpc()
	await get_tree().process_frame
	tankManager.notify_spawns_ready.rpc()

@rpc("authority", "call_remote", "reliable")
func show_game_over(winner_id: int, countdown_seconds: float):
	pending_screen = ""
	
	for node in get_tree().get_nodes_in_group("tank"):
		node.set_physics_process(false)
	for node in get_tree().get_nodes_in_group("projectile"):
		node.set_physics_process(false)
	
	var ui = _get_match_ui()
	if ui:
		ui.hide_all()
	
	var result = LeaderboardManager.get_sorted_leaderboard()
	var go_screen = _get_game_over_screen()
	if go_screen:
		go_screen.show_screen(result, 1, countdown_seconds)

func _get_game_over_screen():
	var nodes = get_tree().get_nodes_in_group("game_over_screen")
	return nodes[0] if nodes.size() > 0 else null

# ─────────────────────────────────────────
#  CLIENT NOTIFICATIONS
# ─────────────────────────────────────────
var pending_screen: String = ""
var pending_countdown: float = 0.0
var pending_match_state: int = -1
var _pending_game_over_retries: int = 0

@rpc("authority", "call_remote", "reliable")
func notify_waiting():
	pending_screen = "waiting"
	var ui = _get_match_ui()
	if ui:
		ui.show_waiting()

@rpc("authority", "call_remote", "reliable")
func notify_starting(seconds: float):
	pending_screen = "starting"
	pending_countdown = seconds
	print("notify_starting received — seconds: ", seconds, " pending_countdown now: ", pending_countdown)
	var ui = _get_match_ui()
	if ui:
		ui._screen_applied = false
		ui._apply_pending_screen()

@rpc("authority", "call_remote", "reliable")
func notify_spectator(current_match_state: int, match_start_time: float):
	pending_screen = "spectator"
	pending_match_state = current_match_state
	pending_countdown = match_start_time
	var ui = _get_match_ui()
	if ui:
		ui._apply_pending_screen()

	if current_match_state == 2: # IN_MATCH
		GameServer.tankManager.request_spawns.rpc_id(1, multiplayer.get_unique_id())

@rpc("authority", "call_remote", "reliable")
func notify_game_over_join(remaining_time: float):
	pending_screen = "game_over"
	pending_countdown = remaining_time
	_pending_game_over_retries = 10
	var ui = _get_match_ui()
	if ui:
		ui.show_spectator()
	var go_screen = _get_game_over_screen()
	if go_screen:
		go_screen.show_screen(go_screen.placeholder_scores, 1, remaining_time)
		_pending_game_over_retries = 0
	else:
		call_deferred("_try_show_pending_game_over_join")

func _try_show_pending_game_over_join() -> void:
	if pending_screen != "game_over":
		return
	var go_screen = _get_game_over_screen()
	if go_screen:
		go_screen.show_screen(go_screen.placeholder_scores, 1, pending_countdown)
		_pending_game_over_retries = 0
		return
	if _pending_game_over_retries > 0:
		_pending_game_over_retries -= 1
		call_deferred("_try_show_pending_game_over_join")

func _get_tank_spawner():
	var nodes = get_tree().get_nodes_in_group("tank_spawner")
	return nodes[0] if nodes.size() > 0 else null

func _get_match_ui():
	var nodes = get_tree().get_nodes_in_group("match_ui")
	return nodes[0] if nodes.size() > 0 else null

# ─────────────────────────────────────────
#  CLIENT
# ─────────────────────────────────────────
var my_id = null

func _reset_client_session_state() -> void:
	my_id = null
	pending_screen = ""
	pending_countdown = 0.0
	pending_match_state = -1
	match_state = MatchState.WAITING

#Player session client
var _player_session = null
#Player sessions server
var player_session_store: Dictionary = {}

func start_client(server_ip, port, player_session, game_session):
	_reset_client_session_state()
	var peer = ENetMultiplayerPeer.new()
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	var err = peer.create_client(server_ip, port)
	if err != OK:
		print("CLIENT: Failed to connect: ", err)
		return
	multiplayer.multiplayer_peer = peer

	_player_session = player_session

@rpc("any_peer", "call_remote")
func send_player_session(player_session_id: String, peer_id):
	print("CLIENT: Sending player session ID to server: ", player_session_id)
	player_session_store[peer_id] = player_session_id
	GameLiftBridge.AcceptPlayerSession(player_session_id)

func _on_connected_to_server():
	my_id = multiplayer.get_unique_id()
	send_player_session.rpc_id(1, _player_session, my_id)
	
	print("CLIENT: Connected! My ID is ", my_id)

func _on_connection_failed():
	print("CLIENT: Connection failed.")

func _on_server_disconnected():
	print("CLIENT: Server disconnected.")
	_reset_client_session_state()

func disconnect_client() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_reset_client_session_state()

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
		start_server()

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
	playerManager.ready_to_start.connect(_on_ready_to_start)

	mapManager.start_maze()
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/game.tscn")

# ─────────────────────────────────────────
#  PEER EVENTS
# ─────────────────────────────────────────
func _on_peer_connected(id: int):
	print("SERVER: Player connected — id: ", id)
	playerManager.assign_slot(id, match_state)

func _on_peer_disconnected(id: int):
	print("SERVER: Player disconnected — id: ", id)
	if match_state == MatchState.IN_MATCH and id in playerManager.actives_players:
		# Leave tank alive as AFK during match — just mark them as disconnected
		playerManager.mark_disconnected(id)
	else:
		# Not in match or was spectator — clean up fully
		playerManager.remove_slot(id)

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
	print("_begin_countdown — notifying actives: ", playerManager.actives_players)
	for pid in playerManager.actives_players:
		print("  sending notify_starting to: ", pid)
		notify_starting.rpc_id(pid, float(COUNTDOWN_SECONDS))

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

# ─────────────────────────────────────────
#  MATCH END
# ─────────────────────────────────────────

func on_match_ended(winner_id: int):
	match_state = MatchState.WAITING
	print("SERVER: Match ended. Winner: ", winner_id)
	show_game_over.rpc(winner_id)
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
	# Clean up disconnected players
	for pid in playerManager.disconnected_players.duplicate():
		playerManager.remove_slot(pid)
	playerManager.disconnected_players.clear()

	# Check if enough players remain for a new match
	if playerManager.player_count < 2:
		match_state = MatchState.WAITING
		# Notify remaining player to show waiting screen
		for pid in playerManager.actives_players + playerManager.spectators:
			notify_waiting.rpc_id(pid)
		return

	collectibleManager.reset()
	playerManager.reload_game.rpc()
	mapManager.start_maze()
	mapManager.pick_background()
	await get_tree().create_timer(0.5).timeout
	playerManager.begin_match.rpc()
	await get_tree().process_frame
	await get_tree().process_frame
	tankManager.clear_tanks.rpc()
	await get_tree().process_frame
	tankManager.notify_spawns_ready.rpc()

@rpc("authority", "call_local", "reliable")
func show_game_over(winner_id: int):
	pending_screen = ""
	var ui = _get_match_ui()
	if ui:
		ui.hide_all()
	var go_screen = _get_game_over_screen()
	if go_screen:
		go_screen.show_screen(go_screen.placeholder_scores, 1)

func _get_game_over_screen():
	var nodes = get_tree().get_nodes_in_group("game_over_screen")
	return nodes[0] if nodes.size() > 0 else null

# ─────────────────────────────────────────
#  CLIENT NOTIFICATIONS
# ─────────────────────────────────────────
var pending_screen: String = ""
var pending_countdown: float = 0.0
var pending_match_state: int = -1

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

func start_client():
	_reset_client_session_state()
	var peer = ENetMultiplayerPeer.new()
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	var err = peer.create_client(SERVER_IP, PORT)
	if err != OK:
		print("CLIENT: Failed to connect: ", err)
		return
	multiplayer.multiplayer_peer = peer

func _on_connected_to_server():
	my_id = multiplayer.get_unique_id()
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

extends Node
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
@onready var leaderboardManager = $LeaderboardManager
@onready var matchManager       = $MatchManager

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

	# Listen to PlayerManager signals — delegate to MatchManager
	playerManager.player_needs_waiting_screen.connect(matchManager._on_player_needs_waiting_screen)
	playerManager.player_needs_spectator_screen.connect(matchManager._on_player_needs_spectator_screen)
	playerManager.player_needs_game_over_screen.connect(matchManager._on_player_needs_game_over_screen)
	playerManager.ready_to_start.connect(matchManager._on_ready_to_start)

	mapManager.start_maze()
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/game.tscn")

# ─────────────────────────────────────────
#  PEER EVENTS
# ─────────────────────────────────────────
func _on_peer_connected(id: int):
	print("SERVER: Player connected — id: ", id)
	playerManager.assign_slot(id, matchManager.match_state)

func _on_peer_disconnected(id: int):
	print("SERVER: Player disconnected — id: ", id)
	var tank_spawner = matchManager._get_tank_spawner()
	if tank_spawner:
		print("SERVER: deleting tank for disconnected peer ", id)
		tank_spawner.remove_tank_by_owner(id)
		for peer_id in multiplayer.get_peers():
			tankManager.sync_delete_tank.rpc_id(peer_id, id)
	playerManager.remove_slot(id)
	leaderboardManager.remove_player(id)
	if playerManager.player_count == 0:
		matchManager._reset_server()

# ─────────────────────────────────────────
#  CLIENT
# ─────────────────────────────────────────
var my_id = null
var pending_player_name: String
var pending_error_message: String = ""

func _reset_client_session_state() -> void:
	my_id = null
	matchManager.pending_screen = ""
	matchManager.pending_countdown = 0.0
	matchManager.pending_match_state = -1
	matchManager.match_state = matchManager.MatchState.WAITING

func start_client(player_name: String):
	pending_player_name = player_name
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
	leaderboardManager.register_player_request.rpc_id(1, pending_player_name)

func _on_connection_failed():
	print("CLIENT: Connection failed.")

func _on_server_disconnected() -> void:
	print("CLIENT: Server disconnected.")
	multiplayer.multiplayer_peer = null
	pending_error_message = "SERVER ERROR"
	get_tree().change_scene_to_file("res://Interfaces/Main Menu/main_menu.tscn")

func disconnect_client() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_reset_client_session_state()

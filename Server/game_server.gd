extends Node
# ─────────────────────────────────────────
#  LIFE CYCLE
# ─────────────────────────────────────────
func _ready() -> void:
	if is_server_mode():
		# Listen for peer connection signals
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	else: 
		#Listen to server connection signals
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)

# ─────────────────────────────────────────
#  SERVER HELPER FUNCTIONS
# ─────────────────────────────────────────
#Server opens with arg --headless or --server
func is_server_mode() -> bool:
	return "--server" in OS.get_cmdline_args() \
		or DisplayServer.get_name() == "headless"

#Server opens with --port number (default is 7777)
func get_port_from_args() -> int:
	var args = OS.get_cmdline_args()
	for i in range(args.size() - 1):
		if args[i] == "--port":
			return int(args[i + 1])
	return 7777  # local dev fallback
	
func get_connected_peer_count() -> int:
	return multiplayer.get_peers().size()

# ─────────────────────────────────────────
#  SERVER CONFIG
# ─────────────────────────────────────────
var PORT: int = get_port_from_args()
const MAX_CLIENTS = 4
const SERVER_IP = "127.0.0.1" # local dev fallback

#Player sessions server
var player_session_store: Dictionary = {}

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
	
	# Listen to PlayerManager signals — delegate to MatchManager
	playerManager.player_needs_waiting_screen.connect(matchManager._on_player_needs_waiting_screen)
	playerManager.player_needs_spectator_screen.connect(matchManager._on_player_needs_spectator_screen)
	playerManager.player_needs_game_over_screen.connect(matchManager._on_player_needs_game_over_screen)
	playerManager.ready_to_start.connect(matchManager._on_ready_to_start)
	
	#Start Game
	mapManager.start_maze()
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/game.tscn")

func _on_peer_connected(id: int):
	print("SERVER: Player connected — id: ", id)
	GameLiftBridge.StopEmptyServerTimer()
	playerManager.assign_slot(id, matchManager.match_state)

func _on_peer_disconnected(id: int):
	print("SERVER: Player disconnected — id: ", id)
	var tank_spawner = matchManager._get_tank_spawner()
	if tank_spawner:
		print("SERVER: deleting tank for disconnected peer ", id)
		tank_spawner.remove_tank_by_owner(id)
		for peer_id in multiplayer.get_peers():
			tankManager.sync_delete_tank.rpc_id(peer_id, id)
	GameLiftBridge.RemovePlayerSession(player_session_store[id])
	player_session_store.erase(id)
	playerManager.remove_slot(id)
	leaderboardManager.remove_player(id)
	if playerManager.player_count == 0:
		matchManager._reset_server()
		GameLiftBridge.StartEmptyServerTimer()
	

# ─────────────────────────────────────────
#  CLIENT
# ─────────────────────────────────────────
var my_id = null
#Player session client
var _player_session = null
var pending_player_name: String
var pending_error_message: String = ""

func _reset_client_session_state() -> void:
	my_id = null
	matchManager.pending_screen = ""
	matchManager.pending_countdown = 0.0
	matchManager.pending_match_state = -1
	matchManager.match_state = matchManager.MatchState.WAITING
	
func start_client(player_name, server_ip, port, player_session, game_session):
	pending_player_name = player_name
	_reset_client_session_state()
	var peer = ENetMultiplayerPeer.new()
	
	var err = peer.create_client(server_ip, port)
	if err != OK:
		print("CLIENT: Failed to connect: ", err)
		return
	multiplayer.multiplayer_peer = peer
	_player_session = player_session

@rpc("any_peer", "call_remote")
func send_player_session(player_session_id: String):
	print("CLIENT: Sending player session ID to server: ", player_session_id)
	player_session_store[multiplayer.get_remote_sender_id()] = player_session_id
	GameLiftBridge.AcceptPlayerSession(player_session_id)

func _on_connected_to_server():
	print("CLIENT: Connected! My ID is ", multiplayer.get_unique_id())
	send_player_session.rpc_id(1, _player_session)
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

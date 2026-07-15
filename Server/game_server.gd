extends Node

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

@onready var playerManager = $PlayerManager
@onready var tankManager = $TankManager
@onready var mapManager = $MapManager
signal game_started

func start_server():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		print("SERVER: Failed to start: ", err)
		return
	multiplayer.multiplayer_peer = peer
	print("SERVER: Listening on port ", PORT)

	# Listen for connections/disconnections
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/game.tscn")
	mapManager.start_maze()


func _on_peer_connected(id: int):
	var slot = playerManager.assign_slot(id)
	print("SERVER: Player ", id, " assigned slot ", slot)


func _on_peer_disconnected(id: int):
	print("SERVER: Player disconnected — id: ", id)
	playerManager.remove_slot(id)


# ─────────────────────────────────────────
#  CLIENT
# ─────────────────────────────────────────
var my_id = null
var _player_session = null
func start_client(server_ip, port, player_session, game_session):
	var peer = ENetMultiplayerPeer.new()
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	var err = peer.create_client(server_ip, port)
	if err != OK:
		print("CLIENT: Failed to connect: ", err)
		return
	multiplayer.multiplayer_peer = peer

	_player_session = player_session

@rpc("any_peer", "call_remote")
func send_player_session(player_session_id: String):
	print("CLIENT: Sending player session ID to server: ", player_session_id)
	GameLiftBridge.AcceptPlayerSession(player_session_id)

func _on_connected_to_server():
	my_id = multiplayer.get_unique_id()
	send_player_session.rpc_id(1, _player_session)
	
	print("CLIENT: Connected! My ID is ", my_id)

func _on_connection_failed():
	print("CLIENT: Connection failed.")

func _on_server_disconnected():
	print("CLIENT: Server disconnected.")

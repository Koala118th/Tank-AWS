extends Control
class_name Main_menu

const PORT = 7777
const MAX_CLIENTS = 8
const SERVER_IP = "127.0.0.1"

func _ready():
	if is_server_mode():
		start_server()
	else:
		start_client()
		
func is_server_mode() -> bool:
	return "--server" in OS.get_cmdline_args() \
		or DisplayServer.get_name() == "headless"

# ─────────────────────────────────────────
#  SERVER
# ─────────────────────────────────────────
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

func _on_peer_connected(id: int):
	print("SERVER: Player connected — id: ", id)

func _on_peer_disconnected(id: int):
	print("SERVER: Player disconnected — id: ", id)

# ─────────────────────────────────────────
#  CLIENT
# ─────────────────────────────────────────
func start_client():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(SERVER_IP, PORT)
	if err != OK:
		print("CLIENT: Failed to connect: ", err)
		return
	multiplayer.multiplayer_peer = peer

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connected_to_server():
	var my_id = multiplayer.get_unique_id()
	print("CLIENT: Connected! My ID is ", my_id)

func _on_connection_failed():
	print("CLIENT: Connection failed.")

func _on_server_disconnected():
	print("CLIENT: Server disconnected.")

# ─────────────────────────────────────────
#  SCENE
# ─────────────────────────────────────────
func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

extends Control
class_name Main_menu
# ─────────────────────────────────────────
#  SCENE
# ─────────────────────────────────────────

const WEBSOCKET_URL = "wss://v4wok52voc.execute-api.ap-southeast-2.amazonaws.com/production/"
@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton

var _client: WebSocketPeer
var _waiting_for_open := false

func _ready() -> void:
	#GameServer.game_started.connect(_on_game_start)
	pass

func _on_start_button_pressed() -> void:
	play_button.disabled = true
	_client = WebSocketPeer.new()

	var err = _client.connect_to_url(WEBSOCKET_URL)
	if err == OK:
		_waiting_for_open = true
	else:
		print("WebSocket connect_to_url failed with error: ", err)
		play_button.disabled = false
		_client = null

func _process(_delta: float) -> void:
	if _client == null:
		return

	_client.poll()
	var state = _client.get_ready_state()

	if _waiting_for_open and state == WebSocketPeer.STATE_OPEN:
		_waiting_for_open = false
		print("WebSocket open — requesting match")
		send_message({ "request": "find_match" })

	if state == WebSocketPeer.STATE_OPEN:
		while _client.get_available_packet_count() > 0:
			var packet = _client.get_packet()
			_on_message(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = _client.get_close_code()
		var reason = _client.get_close_reason()
		print("WebSocket closed. Code: ", code, " Reason: ", reason)
		_client = null
		play_button.disabled = false

func send_message(msg: Dictionary) -> void:
	if _client != null and _client.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_client.send_text(JSON.stringify(msg))

func _on_message(text: String) -> void:
	var data = JSON.parse_string(text)

	if data == null:
		print("Failed to parse message")
		return

	print("Received: ", data)

	var server_ip = data.get("serverIp", "")
	var port = data.get("port", 0)
	var player_session_id = data.get("playerSessionId", "")
	var game_session_id = data.get("gameSessionId", "")

	if server_ip.is_empty():
		print("Missing server IP")
		play_button.disabled = false
		return
		
	GameServer.start_client(server_ip, port, player_session_id, game_session_id)

func _on_game_start() -> void:
	print("game start")
	get_tree().change_scene_to_file("res://Scenes/game.tscn")
	_client.close()
	_client = null

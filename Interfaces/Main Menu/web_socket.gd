extends Node
@onready var play_button: Button = $"../CenterContainer/VBoxContainer/PlayButton"
# ─────────────────────────────────────────
#  WEBSOCKET
# ─────────────────────────────────────────
const WEBSOCKET_URL = "wss://v4wok52voc.execute-api.ap-southeast-2.amazonaws.com/production/"
var _client: WebSocketPeer
var _waiting_for_open := false

func open_client() -> void: 
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
		send_message({ "action": "find_match" })

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
	match data["type"]:
		"route":
			connect_to_server(data)
		"retry_request":
			retry()
		"message":
			print(data["content"])
	
func connect_to_server(data) -> void:
	var server_ip = data["serverIp"]
	var port = data["port"]
	var player_session_id = data["playerSessionId"]
	var game_session_id = data["gameSessionId"]
	
	if server_ip == null or port == null or player_session_id == null or game_session_id == null:
		print("Server Ip: ", server_ip)
		print("Port: ", port)
		print("Player session ", player_session_id)
		print("Game session: ", game_session_id)
		
		play_button.disabled = false
		return
	
	GameServer.start_client(server_ip, port, player_session_id, game_session_id)


var attempt: int = 0
func retry() -> void:
	while attempt <= 5:
		print("attemp to retry")
		var time: float = (attempt+1)*10.0 
		await get_tree().create_timer(time).timeout
		attempt +=1
		send_message({ "action": "find_match" })

func close_client():
	if _client != null:
		_client.close()
		_client = null

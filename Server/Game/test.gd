extends Node

# Called by clients
@rpc("any_peer", "call_remote", "reliable")
func send_message(message: String) -> void:
	var sender := multiplayer.get_remote_sender_id()

	if multiplayer.is_server():
		print("SERVER received from ", sender, ": ", message)
		# Broadcast to everyone
		receive_message.rpc(sender, message)


# Runs on every client
@rpc("authority", "call_remote", "reliable")
func receive_message(sender_id: int, message: String) -> void:
	print("CLIENT ", multiplayer.get_unique_id(),
		" received from ", sender_id, ": ", message)

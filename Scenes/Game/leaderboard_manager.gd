extends Node

# Structure:
# {
#   player_id: {
#       "name": player_name,
#       "wins": int,
#       "kills": int
#   }
# }
var leaderboard := {}

func register_player(player_id: int, player_name: String):
	if not multiplayer.is_server():
		return
	
	if not leaderboard.has(player_id):
		leaderboard[player_id] = {
			"name": player_name,
			"wins": 0,
			"kills": 0
		}


func remove_player(player_id: int):
	if not multiplayer.is_server():
		return
	
	if leaderboard.has(player_id):
		leaderboard.erase(player_id)


func add_kill(player_id: int):
	if leaderboard.has(player_id):
		leaderboard[player_id]["kills"] += 1


func add_win(player_id: int):
	if leaderboard.has(player_id):
		leaderboard[player_id]["wins"] += 1


func get_sorted_leaderboard():
	var arr = []

	for id in leaderboard:
		var data = leaderboard[id]
		arr.append({
			"name": id,
			"wins": data["wins"],
			"kills": data["kills"],
			"is_you": id == multiplayer.get_unique_id()
		})

	arr.sort_custom(func(a, b):
		if a["wins"] == b["wins"]:
			return a["kills"] > b["kills"]
		return a["wins"] > b["wins"]
	)

	return arr


@rpc("any_peer", "reliable")
func register_player_request(player_name: String):
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	register_player(sender_id, player_name)


@rpc("authority", "call_remote")
func sync_leaderboard(data):
	leaderboard = data

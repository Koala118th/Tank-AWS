extends Node
# ─────────────────────────────────────────
#  MATCH STATE
# ─────────────────────────────────────────
enum MatchState { WAITING, STARTING, IN_MATCH }
var match_state: MatchState = MatchState.WAITING

const COUNTDOWN_SECONDS = 5
const GAME_OVER_COUNTDOWN = 8

var _countdown_timer: Timer = null
var _game_over_timer: Timer = null

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
func _begin_countdown():
	match_state = MatchState.STARTING
	GameServer.tankManager.clear_tanks.rpc()
	GameServer.projectileManager.receive_clear_all.rpc()
	print("_begin_countdown — notifying actives: ", GameServer.playerManager.actives_players)
	for pid in GameServer.playerManager.actives_players:
		print("  sending notify_starting to: ", pid)
		notify_starting.rpc_id(pid, float(COUNTDOWN_SECONDS))
	for pid in GameServer.playerManager.spectators:
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
	for pid in GameServer.playerManager.actives_players:
		notify_waiting.rpc_id(pid)

func _on_countdown_finished():
	_countdown_timer.queue_free()
	_countdown_timer = null
	match_state = MatchState.IN_MATCH
	_start_match()

func _start_match():
	print("SERVER: Match starting!")
	GameServer.playerManager.begin_match.rpc()
	await get_tree().process_frame
	await get_tree().process_frame
	GameServer.tankManager.notify_spawns_ready.rpc()

# ─────────────────────────────────────────
#  MATCH END
# ─────────────────────────────────────────
func on_match_ended(winner_id: int):
	match_state = MatchState.WAITING
	print("SERVER: Match ended. Winner: ", winner_id)
	if winner_id != -1:
		GameServer.leaderboardManager.add_win(winner_id)
	GameServer.leaderboardManager.sync_leaderboard.rpc(
		GameServer.leaderboardManager.leaderboard)
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

	var playerManager = GameServer.playerManager

	var future_actives: int = playerManager.actives_players.size() \
		+ playerManager.spectators.size() \
		+ playerManager._spectators_next_match.size()

	if future_actives <= 1:
		match_state = MatchState.WAITING
		playerManager._promote_queued_spectators()
		GameServer.tankManager.clear_tanks.rpc()
		GameServer.projectileManager.receive_clear_all.rpc()
		GameServer.collectibleManager.reset()
		GameServer.tankManager.reset_ammo()
		for pid in playerManager.actives_players + playerManager.spectators:
			notify_waiting.rpc_id(pid)
		return

	var needs_countdown: bool = playerManager._spectators_next_match.size() > 0
	print("needs_countdown: ", needs_countdown,
		" _spectators_next_match: ", playerManager._spectators_next_match,
		" _keep_spectator_next_match: ", playerManager._keep_spectator_next_match)

	GameServer.collectibleManager.reset()
	GameServer.tankManager.reset_ammo()
	GameServer.projectileManager.receive_clear_all.rpc()
	playerManager.reload_game.rpc()
	GameServer.mapManager.start_maze()
	GameServer.mapManager.pick_background()
	await get_tree().process_frame

	# Recheck after await — a player may have disconnected during maze generation
	var recheck_actives: int = playerManager.actives_players.size() \
		+ playerManager.spectators.size()
	if recheck_actives <= 1:
		match_state = MatchState.WAITING
		for pid in playerManager.actives_players + playerManager.spectators:
			notify_waiting.rpc_id(pid)
		# Clean up the started systems
		GameServer.tankManager.clear_tanks.rpc()
		GameServer.collectibleManager.reset()
		return

	if needs_countdown:
		match_state = MatchState.STARTING
		for pid in playerManager.actives_players:
			notify_starting.rpc_id(pid, float(COUNTDOWN_SECONDS))
		for pid in playerManager.spectators:
			notify_spectator.rpc_id(pid, MatchState.STARTING, float(COUNTDOWN_SECONDS))
		await get_tree().create_timer(float(COUNTDOWN_SECONDS)).timeout

		# Recheck again after countdown — another player may have left
		var recheck_after_countdown: int = playerManager.actives_players.size() \
			+ playerManager.spectators.size()
		if recheck_after_countdown <= 1:
			match_state = MatchState.WAITING
			for pid in playerManager.actives_players + playerManager.spectators:
				notify_waiting.rpc_id(pid)
			GameServer.tankManager.clear_tanks.rpc()
			GameServer.collectibleManager.reset()
			return

	match_state = MatchState.IN_MATCH
	playerManager.begin_match.rpc()
	await get_tree().process_frame
	await get_tree().process_frame
	GameServer.tankManager.clear_tanks.rpc()
	await get_tree().process_frame
	GameServer.tankManager.notify_spawns_ready.rpc()

# ─────────────────────────────────────────
#  RESET
# ─────────────────────────────────────────
func _reset_server() -> void:
	print("SERVER: No players remaining — resetting server state")
	if _countdown_timer:
		_countdown_timer.stop()
		_countdown_timer.queue_free()
		_countdown_timer = null
	if _game_over_timer:
		_game_over_timer.stop()
		_game_over_timer.queue_free()
		_game_over_timer = null
	match_state = MatchState.WAITING
	GameServer.collectibleManager.reset()
	GameServer.playerManager._spectators_next_match.clear()
	GameServer.playerManager._keep_spectator_next_match.clear()
	var tank_spawner = _get_tank_spawner()
	if tank_spawner:
		tank_spawner._clear_tanks()
	GameServer.projectileManager.clear_all_projectiles()
	GameServer.mapManager.start_maze()
	GameServer.mapManager.pick_background()
	print("SERVER: Reset complete — waiting for players")

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
	print("notify_starting received — seconds: ", seconds,
		" pending_countdown now: ", pending_countdown)
	var ui = _get_match_ui()
	if ui:
		ui._screen_applied = false
		ui._apply_pending_screen()

@rpc("authority", "call_remote", "reliable")
func notify_spectator(current_match_state: int, match_start_time: float):
	var was_starting = (pending_match_state == 1)
	pending_screen = "spectator"
	pending_match_state = current_match_state
	pending_countdown = match_start_time
	var ui = _get_match_ui()
	if ui:
		ui._apply_pending_screen()
	if current_match_state == 2 and not was_starting:
		var spawner = _get_tank_spawner()
		if spawner != null:
			spawner._request_spawns_once()
		GameServer.projectileManager.request_projectiles.rpc_id(1)

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
	var result = GameServer.leaderboardManager.get_sorted_leaderboard()
	var go_screen = _get_game_over_screen()
	if go_screen:
		go_screen.show_screen(winner_id, result, 1, countdown_seconds)

# ─────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────
func _get_tank_spawner():
	var nodes = get_tree().get_nodes_in_group("tank_spawner")
	return nodes[0] if nodes.size() > 0 else null

func _get_match_ui():
	var nodes = get_tree().get_nodes_in_group("match_ui")
	return nodes[0] if nodes.size() > 0 else null

func _get_game_over_screen():
	var nodes = get_tree().get_nodes_in_group("game_over_screen")
	return nodes[0] if nodes.size() > 0 else null

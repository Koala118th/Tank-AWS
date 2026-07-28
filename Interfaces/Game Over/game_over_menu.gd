extends CanvasLayer

@export var tank_spawner: Node2D

var score_row_scene = preload("res://Interfaces/Game Over/score_row.tscn")
var _end_time: float = 0.0
var countdown_timer: Timer

@onready var winner_badge    = $Control/VBoxContainer/WinnerBadge
@onready var score_container = $Control/VBoxContainer/ScoreContainer
@onready var status_label    = $Control/VBoxContainer/NextStatus/StatusLabel
@onready var countdown_label = $Control/VBoxContainer/NextStatus/CountdownLabel
@onready var match_counter   = $Control/MatchCounter
@onready var quit_button     = $Control/VBoxContainer/QuitButton

func _ready():
	_connect_button_sounds($Control/VBoxContainer/QuitButton)
	
	add_to_group("game_over_screen")
	hide()
	quit_button.pressed.connect(_on_quit_pressed)
	_setup_countdown_timer()
	if GameServer.matchManager.pending_screen == "game_over":
		show_screen(-2, GameServer.leaderboardManager.get_sorted_leaderboard(), 1, GameServer.matchManager.pending_countdown)
func _connect_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_hover))
	button.pressed.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_click))

func show_screen(winner_id: int, scores: Array, match_number: int, countdown_seconds: float = 8.0):
	if winner_id == -1:
		winner_badge.text = "Nobody wins"
	elif winner_id == -2:
		winner_badge.text = ""
	else:
		winner_badge.text = "🏆  " + str(GameServer.leaderboardManager.leaderboard[winner_id]["name"]) + " wins the round"
	match_counter.text = "Match #" + str(match_number)
	_populate_scores(scores)
	show()
	_start_countdown(countdown_seconds)

func _populate_scores(scores: Array):
	for child in score_container.get_children():
		child.queue_free()
	for i in scores.size():
		var row = score_row_scene.instantiate()
		score_container.add_child(row)
		row.setup(i + 1, str(scores[i]["name"]), scores[i]["wins"],
			scores[i]["kills"], scores[i]["is_you"])

func _setup_countdown_timer():
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 0.1
	countdown_timer.timeout.connect(_on_countdown_tick)
	add_child(countdown_timer)

func _start_countdown(seconds: float):
	_end_time = Time.get_ticks_msec() / 1000.0 + seconds
	countdown_label.text = str(int(ceil(_get_remaining()))).pad_zeros(2)
	status_label.text = "Generating next map"
	countdown_timer.start()

func _get_remaining() -> float:
	return max(0.0, _end_time - Time.get_ticks_msec() / 1000.0)

func _on_countdown_tick():
	var remaining = _get_remaining()
	countdown_label.text = str(int(ceil(remaining))).pad_zeros(2)
	if remaining <= 3.0:
		status_label.text = "Starting match..."
	if remaining <= 0.0:
		countdown_timer.stop()
		hide()

func _on_quit_pressed():
	GameServer.disconnect_client()
	get_tree().change_scene_to_file("res://Interfaces/Main Menu/main_menu.tscn")

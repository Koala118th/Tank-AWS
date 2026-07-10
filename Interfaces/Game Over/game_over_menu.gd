extends CanvasLayer

@export var tank_spawner: Node2D

var placeholder_scores = [
	{"name": "VK_Tiger88", "wins": 5, "kills": 12, "is_you": true},
	{"name": "SteelWolf",  "wins": 3, "kills": 9,  "is_you": false},
	{"name": "T34_Ghost",  "wins": 2, "kills": 7,  "is_you": false},
	{"name": "IronBarrel", "wins": 1, "kills": 4,  "is_you": false},
]

var countdown_time := 8
var countdown_timer: Timer
var score_row_scene = preload("res://Interfaces/Game Over/score_row.tscn")

@onready var winner_badge    = $Control/VBoxContainer/WinnerBadge
@onready var score_container = $Control/VBoxContainer/ScoreContainer
@onready var status_label    = $Control/VBoxContainer/NextStatus/StatusLabel
@onready var countdown_label = $Control/VBoxContainer/NextStatus/CountdownLabel
@onready var match_counter   = $Control/MatchCounter
@onready var quit_button     = $Control/VBoxContainer/QuitButton

func _ready():
	add_to_group("game_over_screen")
	hide()
	quit_button.pressed.connect(_on_quit_pressed)
	_setup_countdown_timer()

func show_screen(scores: Array, match_number: int):
	scores.sort_custom(func(a, b): return a["wins"] > b["wins"])
	winner_badge.text = "🏆  " + scores[0]["name"] + " wins the round"
	match_counter.text = "Match #" + str(match_number)
	_populate_scores(scores)
	show()
	_start_countdown()

func _populate_scores(scores: Array):
	for child in score_container.get_children():
		child.queue_free()
	for i in scores.size():
		var row = score_row_scene.instantiate()
		score_container.add_child(row)
		row.setup(i + 1, scores[i]["name"], scores[i]["wins"],
			scores[i]["kills"], scores[i]["is_you"])

func _setup_countdown_timer():
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 1.0
	countdown_timer.timeout.connect(_on_countdown_tick)
	add_child(countdown_timer)

func _start_countdown():
	countdown_time = 8
	countdown_label.text = "08"
	status_label.text = "Generating next map"
	countdown_timer.start()

func _on_countdown_tick():
	countdown_time -= 1
	countdown_label.text = str(countdown_time).pad_zeros(2)
	if countdown_time <= 3:
		status_label.text = "Starting match..."
	if countdown_time <= 0:
		countdown_timer.stop()
		hide()

func _on_quit_pressed():
	countdown_timer.stop()
	get_tree().change_scene_to_file("res://Interfaces/Main Menu/main_menu.tscn")

extends CanvasLayer

@onready var waiting_screen    : Control = $WaitingScreen
@onready var starting_screen   : Control = $StartingScreen
@onready var countdown_label: Label = $StartingScreen/Center/VBox/CountdownLabel
@onready var spectator_overlay : Control = $SpectatorOverlay

var _countdown_tween: Tween = null
var _screen_applied: bool = false
var _countdown_end_time: float = 0.0

func _ready():
	add_to_group("match_ui")
	hide_all()
	await get_tree().process_frame
	if not _screen_applied:
		_apply_pending_screen()

func _apply_pending_screen():
	_screen_applied = true
	var gs = GameServer
	print("MatchUI applying screen: ", gs.pending_screen,
		" match_state: ", gs.pending_match_state,
		" pending_countdown: ", gs.pending_countdown)
	match gs.pending_screen:
		"waiting":
			show_waiting()
		"starting":
			show_starting(gs.pending_countdown)
		"spectator":
			if gs.pending_match_state == 1:
				show_starting(gs.pending_countdown, false)
				_show_spectator_after_countdown(gs.pending_countdown)
			else:
				show_spectator()
		"game_over":
			show_spectator()

func _get_remaining() -> float:
	var now = Time.get_ticks_msec() / 1000.0
	return max(0.0, _countdown_end_time - now)

func _show_spectator_after_countdown(seconds: float):
	await get_tree().create_timer(seconds).timeout
	if _countdown_tween:
		_countdown_tween.kill()
		_countdown_tween = null
	hide_all()
	show_spectator()

func show_waiting():
	if _countdown_tween:
		_countdown_tween.kill()
		_countdown_tween = null
	hide_all()
	waiting_screen.visible = true

func show_starting(seconds: float, hide_on_end: bool = true):
	hide_all()
	starting_screen.visible = true
	_countdown_end_time = Time.get_ticks_msec() / 1000.0 + seconds
	_run_countdown(seconds, hide_on_end)

func show_spectator():
	if _countdown_tween:
		_countdown_tween.kill()
		_countdown_tween = null
	print("show_spectator called — overlay node: ", spectator_overlay)
	if spectator_overlay == null:
		push_error("spectator_overlay is null!")
		return
	spectator_overlay.visible = true
	print("spectator_overlay visible set to true, is_visible: ", spectator_overlay.visible)

func hide_spectator():
	spectator_overlay.visible = false

func hide_all():
	waiting_screen.visible    = false
	starting_screen.visible   = false
	spectator_overlay.visible = false

func _run_countdown(total_seconds: float, hide_on_end: bool = true):
	countdown_label.text = str(int(ceil(_get_remaining())))
	if _countdown_tween:
		_countdown_tween.kill()
	_countdown_tween = create_tween()
	var steps = int(total_seconds / 0.1)
	for i in range(steps):
		_countdown_tween.tween_callback(
			func():
				countdown_label.text = str(int(ceil(_get_remaining())))
		).set_delay(0.1)
	_countdown_tween.tween_callback(func():
		if _countdown_tween:
			_countdown_tween.kill()
			_countdown_tween = null
		if hide_on_end:
			hide_all()
	)
	

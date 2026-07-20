extends CanvasLayer

signal resumed

var _paused := false

func _ready() -> void:
	var buttons = get_tree().get_nodes_in_group("ui_buttons")
	print("[PauseMenu] Found %d buttons in ui_buttons group" % buttons.size())
	for button in buttons:
		print("[PauseMenu] Connecting sounds to: ", button.name)
		_connect_button_sounds(button)
	
	hide()
	$Control/CenterContainer/VBoxContainer/ResumeButton.pressed.connect(_on_resume)
	$Control/CenterContainer/VBoxContainer/QuitButton.pressed.connect(_on_quit)

	set_process_unhandled_input(true)

func _connect_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_hover))
	button.pressed.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_click))

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if _paused:
		_resume()
	else:
		_pause()

func _pause() -> void:
	_paused = true
	get_tree().paused = true
	open()


func _resume() -> void:
	_paused = false
	get_tree().paused = false
	close()
	resumed.emit()


func open() -> void:
	show()

func close() -> void:
	hide()

func _on_resume() -> void:
	_resume()

func _on_quit() -> void:
	get_tree().paused = false
	_paused = false
	GameServer.disconnect_client()
	get_tree().change_scene_to_file("res://Interfaces/Main Menu/main_menu.tscn")

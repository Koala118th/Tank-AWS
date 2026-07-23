extends CanvasLayer

signal resumed

var _paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	var resume_btn := $Control/CenterContainer/VBoxContainer/ResumeButton
	var settings_btn := $Control/CenterContainer/VBoxContainer/SettingsButton
	var quit_btn := $Control/CenterContainer/VBoxContainer/QuitButton
	
	_connect_button_sounds(resume_btn)
	_connect_button_sounds(settings_btn)
	_connect_button_sounds(quit_btn)
	
	resume_btn.pressed.connect(_on_resume)
	quit_btn.pressed.connect(_on_quit)
	
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
	AudioManager.play_ui(AudioManager.sfx_button_click)
	_paused = true
	open()  # no get_tree().paused — just show the menu

func _resume() -> void:
	_paused = false
	close()
	resumed.emit()

func open() -> void:
	show()

func close() -> void:
	hide()

func _on_resume() -> void:
	_resume()

func _on_quit() -> void:
	_paused = false
	GameServer.disconnect_client()
	get_tree().change_scene_to_file("res://Interfaces/Main Menu/main_menu.tscn")

func is_paused() -> bool:
	return _paused

extends CanvasLayer

signal resumed  # add this

func _ready():
	hide()
	$Control/CenterContainer/VBoxContainer/ResumeButton.pressed.connect(_on_resume)
	$Control/CenterContainer/VBoxContainer/QuitButton.pressed.connect(_on_quit)

func open():
	show()

func close():
	hide()

func _on_resume():
	resumed.emit()

func _on_quit():
	get_tree().change_scene_to_file("res://Interfaces/Main Menu/main_menu.tscn")

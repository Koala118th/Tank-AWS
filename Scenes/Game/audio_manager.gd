extends Node

# UI sounds
var sfx_button_hover: AudioStream = preload("res://Audio/Hover.ogg")
var sfx_button_click: AudioStream = preload("res://Audio/Click.ogg")
var sfx_countdown_tick: AudioStream = preload("res://Audio/countdown_tick.ogg")
var sfx_countdown_go: AudioStream = preload("res://Audio/countdown_go.ogg")

# Game sounds
var sfx_shoot: AudioStream = preload("res://Audio/NormalBullet.ogg")
var sfx_shoot_sniper: AudioStream = preload("res://Audio/NormalBullet.ogg")
var sfx_shoot_laser: AudioStream = preload("res://Audio/NormalBullet.ogg")
var sfx_impact: AudioStream = preload("res://Audio/BulletImpactMetal01.ogg")
var sfx_explosion: AudioStream = preload("res://Audio/Explosion.mp3")
var sfx_pickup: AudioStream = preload("res://Audio/Collectible.ogg")

func play_ui(stream: AudioStream) -> void:
	if not stream:
		print("[AudioManager] play_ui: stream is null, skipping")
		return
	#print("[AudioManager] play_ui: playing %s" % stream.resource_path)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "SFX_UI"
	p.autoplay = true
	p.finished.connect(p.queue_free)
	add_child(p)

func play_game(stream: AudioStream, pos: Vector2) -> void:
	if not stream:
		print("[AudioManager] play_game: stream is null, skipping")
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.position = pos
	p.bus = "SFX_Game"
	p.autoplay = true
	p.finished.connect(p.queue_free)
	get_tree().current_scene.add_child(p)

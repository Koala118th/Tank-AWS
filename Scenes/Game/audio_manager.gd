# audio_manager.gd
extends Node

# Assign these in the Inspector after adding as autoload
@export var sfx_shoot: AudioStream = preload("res://Audio/NormalBullet.ogg")
@export var sfx_shoot_small: AudioStream = preload("res://Audio/SmallBullet.ogg")
@export var sfx_shoot_sniper: AudioStream = preload("res://Audio/SniperBullet.ogg")
@export var sfx_shoot_laser: AudioStream = preload("res://Audio/LaserBullet.ogg")
@export var sfx_impact: AudioStream = preload("res://Audio/BulletImpactMetal01.ogg")
@export var sfx_explosion: AudioStream = preload("res://Audio/Explosion.mp3")
@export var sfx_pickup: AudioStream = preload("res://Audio/Collectible.ogg")
@export var sfx_button_hover: AudioStream = preload("res://Audio/Hover.ogg")
@export var sfx_button_click: AudioStream = preload("res://Audio/Click.ogg")
@export var sfx_countdown_tick: AudioStream = preload("res://Audio/countdown_tick.ogg")
@export var sfx_countdown_go: AudioStream = preload("res://Audio/countdown_go.ogg")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_at(stream: AudioStream, pos: Vector2) -> void:
	if not stream:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.position = pos
	p.bus = "SFX"
	p.autoplay = true
	p.finished.connect(p.queue_free)
	get_tree().current_scene.add_child(p)

func play_ui(stream: AudioStream) -> void:
	if not stream:
		print("[AudioManager] play_ui: stream is null, skipping")
		return
	print("[AudioManager] play_ui: playing %s" % stream.resource_path)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "SFX"
	p.autoplay = true
	p.process_mode = Node.PROCESS_MODE_ALWAYS  # ← add this
	p.finished.connect(p.queue_free)
	add_child(p)

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

func play_at(stream: AudioStream, pos: Vector2) -> void:
	if not stream or multiplayer.is_server():
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.position = pos
	p.bus = "SFX"
	p.autoplay = true
	p.finished.connect(p.queue_free)
	get_tree().current_scene.add_child(p)

func play_ui(stream: AudioStream) -> void:
	if not stream or multiplayer.is_server():
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "SFX"
	p.autoplay = true
	p.finished.connect(p.queue_free)
	add_child(p)

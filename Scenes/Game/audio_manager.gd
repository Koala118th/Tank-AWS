extends Node

# UI sounds
var sfx_button_hover: AudioStream = preload("res://Audio/Hover.ogg")
var sfx_button_click: AudioStream = preload("res://Audio/Click.ogg")
var sfx_countdown_tick: AudioStream = preload("res://Audio/countdown_tick.ogg")
var sfx_countdown_go: AudioStream = preload("res://Audio/countdown_go.ogg")

# Game sounds
var sfx_shoot: AudioStream = preload("res://Audio/NormalBullet.ogg")
var sfx_shoot_sniper: AudioStream = preload("res://Audio/SniperBullet.ogg")
var sfx_shoot_laser: AudioStream = preload("res://Audio/LaserBullet.ogg")
var sfx_shoot_chaser: AudioStream = preload("res://Audio/ChaserBullet.ogg")
var sfx_shoot_small: AudioStream = preload("res://Audio/SmallBullet.ogg")
var sfx_impact: AudioStream = preload("res://Audio/BulletImpactMetal01.ogg")
var sfx_explosion: AudioStream = preload("res://Audio/Explosion.mp3")
var sfx_pickup: AudioStream = preload("res://Audio/Collectible.ogg")
var sfx_chaser_lock: AudioStream = preload("res://Audio/ChaserLock.ogg")

var _chaser_tick_player: AudioStreamPlayer = null

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

func start_chaser_tick() -> void:
	if _chaser_tick_player == null:
		_chaser_tick_player = AudioStreamPlayer.new()
		_chaser_tick_player.stream = sfx_chaser_lock
		_chaser_tick_player.bus = "SFX_Game"
		add_child(_chaser_tick_player)
	if not _chaser_tick_player.playing:
		_chaser_tick_player.play()

func stop_chaser_tick() -> void:
	var remaining := 0
	for p in GameServer.projectileManager.projectiles.values():
		if is_instance_valid(p) and p is Chaser:
			remaining += 1
	if remaining <= 0 and _chaser_tick_player != null:
		_chaser_tick_player.stop()

func reset_chaser_tick() -> void:
	if _chaser_tick_player != null:
		_chaser_tick_player.stop()

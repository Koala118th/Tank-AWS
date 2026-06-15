extends AnimatedSprite2D


func _ready():
	play("explode")
	animation_finished.connect(queue_free)

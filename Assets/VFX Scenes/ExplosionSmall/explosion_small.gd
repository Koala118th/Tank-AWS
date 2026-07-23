extends AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready():
	play("explode")
	animation_finished.connect(queue_free)

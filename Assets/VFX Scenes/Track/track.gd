extends Node2D

@export var lifetime := 2.0

func _ready():
	# fade out over time
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)

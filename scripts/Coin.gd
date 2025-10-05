extends Area2D

signal picked_up

func _ready():
	$AnimatedSprite2D.play("default")

func _on_body_entered(body):
	if body.is_in_group("player"):
		emit_signal("picked_up")
		queue_free()

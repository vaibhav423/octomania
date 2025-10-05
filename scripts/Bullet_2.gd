extends CharacterBody2D

signal hit_player

const SPEED = 300.0
var direction = Vector2.ZERO

func setup(start_direction):
	direction = start_direction

func _physics_process(delta):
	velocity = direction * SPEED
	var collision = move_and_collide(velocity * delta)
	if collision:
		if collision.get_collider().is_in_group("player"):
			emit_signal("hit_player")
		queue_free()

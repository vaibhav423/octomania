extends CharacterBody2D

signal bullet_stopped
signal hit_player(player)
signal hit_enemy(enemy)

@onready var pickup_area = $PickupArea
@onready var player_detector = $PlayerDetector
@onready var sprite = $bullet_sprite

const BULLET_SPEED = 400.0
var can_be_picked_up = false
var is_moving = true
var shooter = null
var ignore_shooter_timer = 0.0
const IGNORE_SHOOTER_TIME = 0.5
var bullet_velocity = Vector2.ZERO
var bounce_count = 0

func _ready():
	player_detector.body_entered.connect(_on_player_detector_body_entered)
	pickup_area.body_entered.connect(_on_pickup_area_body_entered)

func _process(delta):
	if ignore_shooter_timer > 0:
		ignore_shooter_timer -= delta

func _physics_process(delta):
	if is_moving:
		velocity = bullet_velocity
		move_and_slide()
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider:
				print("Bullet collision with: ", collider.name, " Type: ", collider.get_class())
			if collider and collider.has_method("die"):
				if can_be_picked_up:
					continue
				if collider == shooter and ignore_shooter_timer > 0:
					print("Ignoring shooter collision")
					continue
				print("Bullet hit character: ", collider.name)
				hit_character(collider)
				break
			elif collider is StaticBody2D:
				print("Bullet hit wall")
				bounce_off_wall(collision)
				break

func setup(direction: Vector2, shot_by = null):
	bullet_velocity = direction.normalized() * BULLET_SPEED
	is_moving = true
	can_be_picked_up = false
	shooter = shot_by
	ignore_shooter_timer = IGNORE_SHOOTER_TIME
	sprite.modulate = Color.WHITE
	print("Bullet setup - Direction: ", direction, " Velocity: ", bullet_velocity, " Shooter: ", shooter.name if shooter else "None")

func bounce_off_wall(collision):
	bounce_count += 1
	print("Bounce count: ", bounce_count)
	var wall_normal = collision.get_normal()
	bullet_velocity = bullet_velocity.bounce(wall_normal)
	if bounce_count >= 3:
		make_pickupable()
		bullet_velocity = bullet_velocity.normalized() * (BULLET_SPEED / 10.0)
		print("Bullet is now floating.")
	else:
		bullet_velocity = bullet_velocity.normalized() * BULLET_SPEED
		print("Bullet bounced! New velocity: ", bullet_velocity, " Normal: ", wall_normal)
	global_position += wall_normal * 5

func hit_character(character):
	bullet_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	is_moving = false
	if character:
		print("Bullet hit character: ", character.name, " - Emitting signals")
		if character.name == "Player":
			hit_player.emit(character)
		else:
			hit_enemy.emit(character)
		bullet_stopped.emit()

func _on_player_detector_body_entered(body):
	if is_moving and body.has_method("die"):
		if can_be_picked_up:
			return
		if body == shooter and ignore_shooter_timer > 0:
			print("Area2D: Ignoring shooter collision")
			return
		print("Area2D: Bullet hit character: ", body.name)
		hit_character(body)

func _on_pickup_area_body_entered(body):
	if can_be_picked_up and body.name == "Player":
		pickup()

func make_pickupable():
	can_be_picked_up = true
	sprite.modulate = Color(0, 1, 0, 1)

func pickup():
	if can_be_picked_up:
		queue_free()

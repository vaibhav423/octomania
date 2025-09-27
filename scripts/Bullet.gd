extends CharacterBody2D

signal bullet_stopped
signal hit_player(player)
signal hit_enemy(enemy)

@onready var pickup_area = $PickupArea
@onready var player_detector = $PlayerDetector
@onready var bullet_image = $BulletImage

const BULLET_SPEED = 400.0
var can_be_picked_up = false
var is_moving = true
var shooter = null
var ignore_shooter_timer = 0.0
const IGNORE_SHOOTER_TIME = 0.5
var bullet_velocity = Vector2.ZERO

func _ready():
	player_detector.body_entered.connect(_on_player_detector_body_entered)
	pickup_area.body_entered.connect(_on_pickup_area_body_entered)

func _process(delta):
	if ignore_shooter_timer > 0:
		ignore_shooter_timer -= delta

func _physics_process(delta):
	if is_moving:
		# Ensure bullet maintains constant speed
		if bullet_velocity.length() > 0:
			bullet_velocity = bullet_velocity.normalized() * BULLET_SPEED
		
		velocity = bullet_velocity
		move_and_slide()
		
		# Check for collisions
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			
			# Debug print for downward shooting issues
			if collider:
				print("Bullet collision with: ", collider.name, " Type: ", collider.get_class())
			
			# Check if it's a character (player or enemy)
			if collider and collider.has_method("die"):
				# Ignore the shooter for a short time after shooting
				if collider == shooter and ignore_shooter_timer > 0:
					print("Ignoring shooter collision")
					continue
				print("Bullet hit character: ", collider.name)
				hit_character(collider)
				break
			# Check if it's a wall (StaticBody2D)
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
	
	# Set bullet to black when moving
	bullet_image.color = Color.BLACK
	
	# Debug print to check setup
	print("Bullet setup - Direction: ", direction, " Velocity: ", bullet_velocity, " Shooter: ", shooter.name if shooter else "None")

func bounce_off_wall(collision):
	# Get the collision normal
	var wall_normal = collision.get_normal()
	# Reflect the velocity using the collision normal
	bullet_velocity = bullet_velocity.bounce(wall_normal)
	
	# Ensure bullet maintains speed after bounce
	bullet_velocity = bullet_velocity.normalized() * BULLET_SPEED
	
	# Move bullet away from wall to prevent sticking
	global_position += wall_normal * 5
	
	# Debug print to check bouncing
	print("Bullet bounced! New velocity: ", bullet_velocity, " Normal: ", wall_normal)

func hit_character(character):
	# Stop the bullet
	bullet_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	is_moving = false
	
	print("Bullet hit character: ", character.name, " - Emitting signals")
	
	# Emit appropriate signal
	if character.name == "Player":
		hit_player.emit(character)
	else:
		hit_enemy.emit(character)
	
	# Signal that bullet has stopped
	bullet_stopped.emit()

func _on_player_detector_body_entered(body):
	if is_moving and body.has_method("die"):
		# Ignore the shooter for a short time after shooting
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
	bullet_image.color = Color(0, 0.5, 0, 1)  # Dark green when pickupable

func pickup():
	if can_be_picked_up:
		queue_free()

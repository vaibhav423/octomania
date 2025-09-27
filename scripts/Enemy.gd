extends CharacterBody2D

signal died
signal bullet_shot(direction: Vector2, start_position: Vector2)

@onready var movement_timer = $MovementTimer
@onready var shoot_timer = $ShootTimer
@onready var bullet_detector = $BulletDetector
@onready var animated_sprite = $AnimatedSprite2D

const SPEED = 100.0
var is_alive = true
var move_direction = Vector2.ZERO
var has_bullet = false
var target_bullet = null
var player_ref = null
var last_shoot_direction = Vector2.RIGHT

func _ready():
	movement_timer.timeout.connect(_on_movement_timer_timeout)
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	bullet_detector.area_entered.connect(_on_bullet_detector_area_entered)
	_choose_random_direction()
	
	# Get player reference safely
	call_deferred("_get_player_reference")

func _get_player_reference():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		player_ref = game_manager.get_node("Player")
	else:
		# Fallback: find player by name in the scene tree
		player_ref = get_tree().get_nodes_in_group("player")[0] if get_tree().get_nodes_in_group("player").size() > 0 else null

func _physics_process(delta):
	if not is_alive:
		return
	
	# AI Decision making
	_update_ai_behavior()
	
	velocity = move_direction * SPEED
	
	# Keep enemy within arena bounds
	var arena_bounds = Rect2(20, 20, 760, 560)
	global_position.x = clamp(global_position.x, arena_bounds.position.x, arena_bounds.position.x + arena_bounds.size.x)
	global_position.y = clamp(global_position.y, arena_bounds.position.y, arena_bounds.position.y + arena_bounds.size.y)
	
	move_and_slide()
	
	# Check for bullet pickup through direct collision
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if is_alive and collider and collider.has_method("pickup") and collider.can_be_picked_up:
			get_tree().get_first_node_in_group("game_manager").pickup_bullet_for_enemy(self)
			break
	
	# Change direction if hitting walls
	if is_on_wall():
		_choose_random_direction()

func _on_movement_timer_timeout():
	_choose_random_direction()

func _update_ai_behavior():
	# Find the current bullet in the scene
	target_bullet = get_tree().get_first_node_in_group("game_manager").current_bullet
	
	if not has_bullet and target_bullet and target_bullet.can_be_picked_up:
		# Move toward the bullet if we don't have one
		_move_toward_bullet()
	elif has_bullet and player_ref and randf() < 0.3:  # 30% chance to target player
		# Sometimes aim toward the player
		_aim_toward_player()
	# Otherwise, continue with random movement

func _move_toward_bullet():
	if target_bullet:
		var direction_to_bullet = (target_bullet.global_position - global_position).normalized()
		move_direction = direction_to_bullet

func _aim_toward_player():
	if player_ref:
		var direction_to_player = (player_ref.global_position - global_position).normalized()
		last_shoot_direction = direction_to_player

func _choose_random_direction():
	var directions = [
		Vector2.UP,
		Vector2.DOWN,
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2.UP + Vector2.LEFT,
		Vector2.UP + Vector2.RIGHT,
		Vector2.DOWN + Vector2.LEFT,
		Vector2.DOWN + Vector2.RIGHT,
		Vector2.ZERO  # Sometimes stand still
	]
	move_direction = directions[randi() % directions.size()].normalized()
	# Also update shoot direction occasionally
	if randf() < 0.5:
		last_shoot_direction = move_direction if move_direction != Vector2.ZERO else Vector2.RIGHT

func _on_shoot_timer_timeout():
	if has_bullet and is_alive:
		_try_shoot()

func _try_shoot():
	# Don't shoot if too close to walls to avoid immediate bounce back
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + last_shoot_direction * 50)
	var result = space_state.intersect_ray(query)
	
	if not result or result.collider.get_class() != "StaticBody2D":
		_shoot()

func _shoot():
	if has_bullet:
		has_bullet = false
		# Start bullet away from enemy
		var bullet_start_pos = global_position + last_shoot_direction * 30
		bullet_shot.emit(last_shoot_direction, bullet_start_pos)
		# Visual feedback - tint sprite briefly
		animated_sprite.modulate = Color.ORANGE
		await get_tree().create_timer(0.3).timeout
		if is_alive:
			animated_sprite.modulate = Color.WHITE

func _on_bullet_detector_area_entered(area):
	if is_alive and area.get_parent().has_method("pickup") and area.get_parent().can_be_picked_up:
		# This is a pickupable bullet
		get_tree().get_first_node_in_group("game_manager").pickup_bullet_for_enemy(self)

func die():
	if is_alive:
		is_alive = false
		velocity = Vector2.ZERO
		died.emit()
		# Make enemy disappear after a brief moment
		await get_tree().create_timer(0.1).timeout
		queue_free()

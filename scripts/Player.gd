extends CharacterBody2D

signal bullet_shot(direction: Vector2, start_position: Vector2)
signal died

@onready var bullet_detector = $BulletDetector
@onready var animated_sprite = $AnimatedSprite2D

const SPEED = 200.0
var has_bullet = true
var is_alive = true
var last_move_direction = Vector2.RIGHT

func _ready():
	bullet_detector.area_entered.connect(_on_bullet_detector_area_entered)
	animated_sprite.play("new_animation")
	add_to_group("player")

func handle_movement():
	var input_dir = Vector2()
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if input_dir != Vector2.ZERO:
		last_move_direction = input_dir.normalized()
		velocity = input_dir.normalized() * SPEED
		if not animated_sprite.is_playing():
			animated_sprite.play("new_animation")
	else:
		velocity = Vector2.ZERO
		animated_sprite.pause()
	var arena_bounds = Rect2(20, 20, 760, 560)
	global_position.x = clamp(global_position.x, arena_bounds.position.x, arena_bounds.position.x + arena_bounds.size.x)
	global_position.y = clamp(global_position.y, arena_bounds.position.y, arena_bounds.position.y + arena_bounds.size.y)
	move_and_slide()

func handle_shooting():
	if Input.is_action_just_pressed("shoot") and has_bullet:
		shoot()

func shoot():
	if has_bullet:
		has_bullet = false
		var distance = 30
		if last_move_direction.y > 0:
			distance = 50
		var bullet_start_pos = global_position + last_move_direction * distance
		bullet_shot.emit(last_move_direction, bullet_start_pos)
		animated_sprite.modulate = Color.GRAY
		await get_tree().create_timer(0.2).timeout
		if is_alive:
			animated_sprite.modulate = Color.WHITE

func _on_bullet_detector_area_entered(area):
	if area.get_parent().has_method("pickup") and area.get_parent().can_be_picked_up:
		get_tree().get_first_node_in_group("game_manager").pickup_bullet()

func _physics_process(delta):
	if not is_alive:
		return
	handle_movement()
	handle_shooting()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.has_method("pickup") and collider.can_be_picked_up:
			get_tree().get_first_node_in_group("game_manager").pickup_bullet()
			break

func die():
	if is_alive:
		is_alive = false
		animated_sprite.modulate = Color.RED
		animated_sprite.stop()
		died.emit()

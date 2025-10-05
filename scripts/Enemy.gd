extends CharacterBody2D

signal died
signal bullet_shot(direction: Vector2, start_position: Vector2)

@onready var movement_timer = $MovementTimer
@onready var shoot_timer = $ShootTimer
@onready var animated_sprite = $AnimatedSprite2D

const SPEED = 100.0
var is_alive = true
var move_direction = Vector2.ZERO
var player_ref = null
var last_shoot_direction = Vector2.RIGHT

func _ready():
	movement_timer.timeout.connect(_on_movement_timer_timeout)
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	_choose_random_direction()
	animated_sprite.play("default")
	call_deferred("_get_player_reference")

func _get_player_reference():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		player_ref = game_manager.get_node("Player")
	else:
		player_ref = get_tree().get_nodes_in_group("player")[0] if get_tree().get_nodes_in_group("player").size() > 0 else null

func _physics_process(delta):
	if not is_alive:
		return
	_update_ai_behavior()
	velocity = move_direction * SPEED
	var arena_bounds = Rect2(20, 20, 760, 560)
	global_position.x = clamp(global_position.x, arena_bounds.position.x, arena_bounds.position.x + arena_bounds.size.x)
	global_position.y = clamp(global_position.y, arena_bounds.position.y, arena_bounds.position.y + arena_bounds.size.y)
	move_and_slide()
	if is_on_wall():
		_choose_random_direction()

func _on_movement_timer_timeout():
	_choose_random_direction()

func _update_ai_behavior():
	if player_ref:
		_aim_toward_player()

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
		Vector2.ZERO
	]
	move_direction = directions[randi() % directions.size()].normalized()

func _on_shoot_timer_timeout():
	if is_alive:
		_shoot()

func _shoot():
	var bullet_start_pos = global_position + last_shoot_direction * 50
	bullet_shot.emit(last_shoot_direction, bullet_start_pos)

func die():
	if is_alive:
		is_alive = false
		velocity = Vector2.ZERO
		died.emit()
		await get_tree().create_timer(0.1).timeout
		queue_free()

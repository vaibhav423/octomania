extends Node2D

@onready var player = $Player
@onready var enemies = $Enemies
@onready var game_over_label = $UI/GameOverLabel
@onready var win_label = $UI/WinLabel
@onready var score_label = $UI/ScorePanel/ScoreLabel
@onready var background_image = $Arena/BackgroundImage
@onready var start_screen = $UI/StartScreen
@onready var mobile_controls = $MobileControls
@onready var toggle_controls_check_button = $UI/ToggleControlsCheckButton
@onready var coin_timer = $CoinTimer
@onready var coins = $Coins

var bullet_scene = preload("res://scenes/Bullet.tscn")
var enemy_bullet_scene = preload("res://scenes/Bullet_2.tscn")
var enemy_scene = preload("res://scenes/Enemy.tscn")
var coin_scene = preload("res://scenes/coin.tscn")
var current_bullet = null
var enemy_can_shoot = true
var game_over = false
var game_started = false
var score = 0

func _ready():
	add_to_group("game_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_game()
	player.bullet_shot.connect(_on_bullet_shot)
	player.died.connect(_on_player_died)
	coin_timer.timeout.connect(_on_coin_timer_timeout)
	for enemy in enemies.get_children():
		enemy.died.connect(_on_enemy_died)
		enemy.bullet_shot.connect(_on_enemy_bullet_shot)
	toggle_controls_check_button.toggled.connect(_on_toggle_controls_toggled)
	mobile_controls.visible = false
	var dark_blue = Color(0, 0, 0.5, 1)
	toggle_controls_check_button.add_theme_color_override("font_color", dark_blue)
	toggle_controls_check_button.add_theme_color_override("font_hover_color", dark_blue)
	toggle_controls_check_button.add_theme_color_override("font_pressed_color", dark_blue)
	toggle_controls_check_button.add_theme_color_override("font_focus_color", dark_blue)
	toggle_controls_check_button.add_theme_color_override("font_disabled_color", dark_blue)

func _input(event):
	if not game_started and (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventScreenTouch and event.pressed):
		start_game()
	if game_over and (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventScreenTouch and event.pressed):
		restart_game()

func start_game():
	game_started = true
	start_screen.visible = false
	get_tree().paused = false
	print("Game Started!")

func pause_game():
	game_started = false
	start_screen.visible = true
	get_tree().paused = true

func _on_bullet_shot(direction: Vector2, start_position: Vector2):
	_create_bullet(direction, start_position, player)

func _on_enemy_bullet_shot(direction: Vector2, start_position: Vector2):
	if enemy_can_shoot:
		enemy_can_shoot = false
		var new_bullet = enemy_bullet_scene.instantiate()
		add_child(new_bullet)
		new_bullet.position = start_position
		new_bullet.setup(direction)
		new_bullet.hit_player.connect(_on_enemy_bullet_hit_player)
		await get_tree().create_timer(1.0).timeout
		enemy_can_shoot = true

func _on_enemy_bullet_hit_player():
	player.die()

func _create_bullet(direction: Vector2, start_position: Vector2, shooter):
	if current_bullet == null:
		current_bullet = bullet_scene.instantiate()
		add_child(current_bullet)
		current_bullet.position = start_position
		current_bullet.setup(direction, shooter)
		current_bullet.bullet_stopped.connect(_on_bullet_stopped)
		current_bullet.hit_player.connect(_on_bullet_hit_player)
		current_bullet.hit_enemy.connect(_on_bullet_hit_enemy)

func _on_bullet_stopped():
	if current_bullet:
		current_bullet.make_pickupable()

func _on_bullet_hit_player(player_node):
	if player_node == player:
		player.die()

func _on_bullet_hit_enemy(enemy_node):
	print("GameManager: Bullet hit enemy at position: ", enemy_node.global_position)
	var enemy_death_pos = enemy_node.global_position
	enemy_node.die()
	if current_bullet:
		print("GameManager: Moving bullet to death position: ", enemy_death_pos)
		current_bullet.global_position = enemy_death_pos
		await get_tree().create_timer(0.3).timeout
		if current_bullet:
			current_bullet.make_pickupable()
			print("GameManager: Bullet made pickupable at: ", current_bullet.global_position)
	else:
		print("GameManager: ERROR - No current bullet to reposition!")

func _on_player_died():
	game_over = true
	game_over_label.visible = true

func _on_enemy_died():
	await get_tree().create_timer(0.2).timeout
	var alive_enemies = enemies.get_child_count()
	if alive_enemies == 1:
		spawn_enemies()
	elif alive_enemies == 0:
		game_over = true
		win_label.visible = true

func spawn_enemies():
	print("Spawning 3 new enemies from top right corner")
	var spawn_positions = [
		Vector2(750, 50),
		Vector2(720, 80),
		Vector2(780, 100)
	]
	for i in range(3):
		var new_enemy = enemy_scene.instantiate()
		enemies.add_child(new_enemy)
		new_enemy.global_position = spawn_positions[i]
		new_enemy.died.connect(_on_enemy_died)
		new_enemy.bullet_shot.connect(_on_enemy_bullet_shot)
		print("Spawned enemy at: ", spawn_positions[i])

func pickup_bullet():
	if current_bullet and current_bullet.can_be_picked_up:
		current_bullet.queue_free()
		current_bullet = null
		player.has_bullet = true

func restart_game():
	get_tree().reload_current_scene()

func _on_toggle_controls_toggled(button_pressed):
	mobile_controls.visible = button_pressed

func _on_coin_timer_timeout():
	if coins.get_child_count() < 3:
		var new_coin = coin_scene.instantiate()
		coins.add_child(new_coin)
		new_coin.position = Vector2(randi_range(20, 780), randi_range(20, 580))
		new_coin.picked_up.connect(_on_coin_picked_up)

func _on_coin_picked_up():
	score += 1
	score_label.text = "Score: " + str(score)

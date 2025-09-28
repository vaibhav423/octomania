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

var bullet_scene = preload("res://scenes/Bullet.tscn")
var enemy_scene = preload("res://scenes/Enemy.tscn")
var current_bullet = null
var game_over = false
var game_started = false
var score = 0

func _ready():
	# Add to game_manager group for easy access
	add_to_group("game_manager")
	
	# Allow this node to process input even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load background image (uncomment and change path to your image)
	# background_image.texture = load("res://Assets/your_background_image.png")
	
	# Start with game paused and start screen visible
	pause_game()
	
	# Connect player signals
	player.bullet_shot.connect(_on_bullet_shot)
	player.died.connect(_on_player_died)
	
	# Connect enemy signals
	for enemy in enemies.get_children():
		enemy.died.connect(_on_enemy_died)
		enemy.bullet_shot.connect(_on_enemy_bullet_shot)
	
	# Connect the toggle check button's toggled signal
	toggle_controls_check_button.toggled.connect(_on_toggle_controls_toggled)
	# Set initial state
	mobile_controls.visible = false
	# Set the font color to dark blue for all states
	var dark_blue = Color(0, 0, 0.5, 1)
	toggle_controls_check_button.add_theme_color_override("font_color", dark_blue)
	toggle_controls_check_button.add_theme_color_override("font_hover_color", dark_blue)
	toggle_controls_check_button.add_theme_color_override("font_pressed_color", dark_blue)
	toggle_controls_check_button.add_theme_color_override("font_focus_color", dark_blue)
	toggle_controls_check_button.add_theme_color_override("font_disabled_color", dark_blue)

func _input(event):
	# Start game on mouse click or screen touch
	if not game_started and (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventScreenTouch and event.pressed):
		start_game()
	
	# Restart game on key press or touch
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
	# Find which enemy shot the bullet
	var shooter_enemy = null
	for enemy in enemies.get_children():
		if enemy.global_position.distance_to(start_position) < 50:  # Find closest enemy
			shooter_enemy = enemy
			break
	_create_bullet(direction, start_position, shooter_enemy)

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
	
	# Increase score
	score += 1
	score_label.text = "Score: " + str(score)
	
	# Store enemy position before they die
	var enemy_death_pos = enemy_node.global_position
	enemy_node.die()
	
	# Move bullet to enemy's death position and make it pickupable after a delay
	if current_bullet:
		print("GameManager: Moving bullet to death position: ", enemy_death_pos)
		current_bullet.global_position = enemy_death_pos
		# Add a brief delay before making bullet pickupable
		await get_tree().create_timer(0.3).timeout
		if current_bullet:  # Check if bullet still exists
			current_bullet.make_pickupable()
			print("GameManager: Bullet made pickupable at: ", current_bullet.global_position)
	else:
		print("GameManager: ERROR - No current bullet to reposition!")

func _on_player_died():
	game_over = true
	game_over_label.visible = true

func _on_enemy_died():
	# Wait a moment for enemy to be removed, then check enemy count
	await get_tree().create_timer(0.2).timeout
	
	var alive_enemies = enemies.get_child_count()
	
	if alive_enemies == 1:
		# Spawn 3 more enemies from top right corner
		spawn_enemies()
	elif alive_enemies == 0:
		game_over = true
		win_label.visible = true

func spawn_enemies():
	print("Spawning 3 new enemies from top right corner")
	var spawn_positions = [
		Vector2(750, 50),   # Top right corner area
		Vector2(720, 80),
		Vector2(780, 100)
	]
	
	for i in range(3):
		var new_enemy = enemy_scene.instantiate()
		enemies.add_child(new_enemy)
		new_enemy.global_position = spawn_positions[i]
		
		# Connect signals for the new enemy
		new_enemy.died.connect(_on_enemy_died)
		new_enemy.bullet_shot.connect(_on_enemy_bullet_shot)
		
		print("Spawned enemy at: ", spawn_positions[i])

func pickup_bullet():
	if current_bullet and current_bullet.can_be_picked_up:
		current_bullet.queue_free()
		current_bullet = null
		player.has_bullet = true

func pickup_bullet_for_enemy(enemy):
	if current_bullet and current_bullet.can_be_picked_up:
		current_bullet.queue_free()
		current_bullet = null
		enemy.has_bullet = true
		print("Enemy picked up bullet!")

func restart_game():
	get_tree().reload_current_scene()

func _on_toggle_controls_toggled(button_pressed):
	mobile_controls.visible = button_pressed

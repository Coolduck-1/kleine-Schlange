extends Node

@export var snake_scene : PackedScene

var score : int
var game_started : bool = false

var cells : int = 20
var cell_size : int = 50

var antifood_positions : Array = []
var antifood_nodes : Array = []
var food_pos : Vector2
var regen_food : bool = true

var old_data : Array
var snake_data : Array
var snake : Array

var start_pos = Vector2(9, 9)
var up = Vector2(0, -1)
var down = Vector2(0, 1)
var left = Vector2(-1, 0)
var right = Vector2(1, 0)
var move_direction : Vector2
var can_move : bool

func _ready() -> void:
	# Connect the custom signal 'start' from your MainMenu scene
	if has_node("MainMenu"):
		$MainMenu.start.connect(_on_main_menu_start)

	# Connect Game Over Buttons
	if $GameOverMenu.has_node("RestartButton"):
		$GameOverMenu.get_node("RestartButton").pressed.connect(_on_game_over_menu_restart)
	elif $GameOverMenu.has_node("Control/RestartButton"):
		$GameOverMenu.get_node("Control/RestartButton").pressed.connect(_on_game_over_menu_restart)

	# Connect Win Menu Buttons
	if $WinMenu.has_node("RestartButton"):
		$WinMenu.get_node("RestartButton").pressed.connect(_on_win_menu_replay)
	elif $WinMenu.has_node("Control/RestartButton"):
		$WinMenu.get_node("Control/RestartButton").pressed.connect(_on_win_menu_replay)

	# Initialize visual states for game startup
	$hud.hide()
	$Panel.hide()
	$GameOverMenu.hide()
	$WinMenu.hide()
	if has_node("Food"): $Food.hide()
	
	# Show the Main Menu on startup and freeze the snake loops
	if has_node("MainMenu"):
		$MainMenu.show()
		can_move = false
		game_started = false
	else:
		# Fallback safety if the MainMenu node is missing
		new_game()
	
func new_game():
	# Hide all UI menus and reveal the gameplay environment
	if has_node("MainMenu"):
		$MainMenu.hide()
	$GameOverMenu.hide()
	$WinMenu.hide()
	$hud.show()
	$Panel.show()
	if has_node("Food"): $Food.show()
	
	score = 2
	$hud.get_node("Scorelabel").text = "Score: " + str(score)
	move_direction = right
	game_started = false 
	can_move = true
	generate_schlange()
	move_food()
	
	clear_antifood()
	for i in range(3):
		spawn_single_antifood()
	
func generate_schlange():
	old_data.clear()
	snake_data.clear()
	
	for segment in snake:
		if is_instance_valid(segment):
			segment.queue_free()
	snake.clear()
	
	for i in range(3):
		add_segment(start_pos - Vector2(i, 0))
		
func lose_segment(pos):
	add_segment(pos)

func add_segment(pos):
	snake_data.append(pos)
	var Snakesegment = snake_scene.instantiate()
	Snakesegment.position = (pos * cell_size) + Vector2(0, cell_size)
	add_child(Snakesegment)
	snake.append(Snakesegment)

func _process(_delta: float) -> void:
	if game_started or can_move:
		move_snake()
		
func move_snake():
	if not can_move:
		return
		
	if Input.is_action_just_pressed("move_down") and move_direction != up:
		move_direction = down
		can_move = false
		if not game_started:
			start_game()
	elif Input.is_action_just_pressed("move_up") and move_direction != down:
		move_direction = up
		can_move = false
		if not game_started:
			start_game()
	elif Input.is_action_just_pressed("move_left") and move_direction != right:
		move_direction = left
		can_move = false
		if not game_started:
			start_game()
	elif Input.is_action_just_pressed("move_right") and move_direction != left:
		move_direction = right
		can_move = false
		if not game_started:
			start_game()

func start_game():
	game_started = true
	$MoveTimer.start()

func _on_move_timer_timeout() -> void:
	can_move = true
	old_data = [] + snake_data
	snake_data[0] += move_direction
	
	for i in range(len(snake_data)):
		if i > 0:
			snake_data[i] = old_data[i-1]
		snake[i].position = (snake_data[i] * cell_size) + Vector2(0, cell_size)
		
	check_out_of_bounds()
	
	if not game_started: 
		return
		
	check_self_eaten()
	if not game_started: 
		return
		
	check_food_eaten()
	check_antifood_eaten()
	
func check_out_of_bounds():
	if snake_data[0].x < 0 or snake_data[0].x > cells - 1 or snake_data[0].y < 0 or snake_data[0].y > cells - 1:
		end_game()

func check_self_eaten():
	for i in range(1, len(snake_data)):
		if snake_data[0] == snake_data[i]:
			end_game()
			return
			
func check_food_eaten():
	if snake_data[0] == food_pos:
		score += 1
		$hud.get_node("Scorelabel").text = "Score: " + str(score)
		
		if score >= 3:
			win_game()
			return
			
		add_segment(old_data[-1])
		move_food()

func check_antifood_eaten():
	for i in range(antifood_positions.size()):
		if snake_data[0] == antifood_positions[i]:
			var hit_node = antifood_nodes[i]
			if is_instance_valid(hit_node):
				hit_node.queue_free()
			antifood_nodes.remove_at(i)
			antifood_positions.remove_at(i)
			
			spawn_single_antifood()
			
			if len(snake_data) <= 1: 
				end_game()
				return
			var last_segment_node = snake.pop_back()
			if is_instance_valid(last_segment_node):
				last_segment_node.queue_free()
			snake_data.pop_back()
			score = max(0, score - 1)
			$hud.get_node("Scorelabel").text = "Score: " + str(score)
			break

func move_food():
	while regen_food:
		regen_food = false
		food_pos = Vector2(randi_range(0, cells - 1), randi_range(0, cells - 1))
		for i in snake_data:
			if food_pos == i:
				regen_food = true
		for pos in antifood_positions:
			if food_pos == pos:
				regen_food = true
	$Food.position = (food_pos * cell_size) + Vector2(0, cell_size)
	regen_food = true

func spawn_single_antifood():
	var new_pos = Vector2.ZERO
	var finding_pos = true
	while finding_pos:
		finding_pos = false
		new_pos = Vector2(randi_range(0, cells - 1), randi_range(0, cells - 1))
		if new_pos == food_pos:
			finding_pos = true
		for i in snake_data:
			if new_pos == i:
				finding_pos = true
		for pos in antifood_positions:
			if new_pos == pos:
				finding_pos = true
				
	antifood_positions.append(new_pos)
	var new_antifood = $AntiFood.duplicate()
	add_child(new_antifood)
	new_antifood.position = Vector2.ZERO 
	new_antifood.position = (new_pos * cell_size) + Vector2(0, cell_size)
	new_antifood.show()
	antifood_nodes.append(new_antifood)

func clear_antifood():
	for node in antifood_nodes:
		if is_instance_valid(node):
			node.queue_free()
	antifood_nodes.clear()
	antifood_positions.clear()

func win_game():
	game_started = false
	can_move = false
	$MoveTimer.stop()
	$WinMenu.show()
	if has_node("Food"): $Food.hide()
	
	for segment in snake:
		if is_instance_valid(segment):
			segment.queue_free()
	snake.clear()
	snake_data.clear()
	clear_antifood()

func end_game():
	game_started = false
	can_move = false
	$MoveTimer.stop()
	$GameOverMenu.show() 
	if has_node("Food"): $Food.hide()
	
	for segment in snake:
		if is_instance_valid(segment):
			segment.queue_free()
	snake.clear()
	snake_data.clear()
	clear_antifood()

# --- Signal Callback Functions ---

func _on_main_menu_start() -> void:
	new_game()

func _on_game_over_menu_restart() -> void:
	new_game()

func _on_win_menu_replay() -> void:
	new_game()

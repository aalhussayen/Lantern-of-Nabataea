extends CharacterBody2D 

# --- Health Variables ---
@export var health: int = 3 
@export var heart_texture: Texture2D 
var current_health: int

# UI References
@onready var heart_container = $UI/HeartsContainer
var hearts_list: Array = []

# --- Movement & Action Variables ---
@export var move_speed: float = 100.0 
@export var run_speed: float = 180.0 
@export var dodge_speed: float = 250.0 
@export var dodge_duration: float = 0.3 
@export var dodge_cooldown: float = 1.0 
@export var attack_duration: float = 0.4 
@export var starting_direction : Vector2 = Vector2(0,1) 

# --- Combat Variables ---
@export var attack_damage: int = 1
@export var attack_reach: float = 20.0 # How far the hitbox pushes out in front of the player

var is_dodging: bool = false 
var can_dodge: bool = true 
var is_attacking: bool = false 
var facing_direction: Vector2 = Vector2.ZERO 

# --- Animation Node References ---
@onready var animation_tree = $AnimationTree 
@onready var state_machine = animation_tree.get("parameters/playback") 
@onready var weapon_hitbox = $WeaponHitbox # Connects the invisible damage zone

func _ready():
	current_health = health
	
	for child in heart_container.get_children():
		child.queue_free()
		
	hearts_list.clear()
	
	for i in range(health):
		var heart = TextureRect.new()
		heart.texture = heart_texture
		
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED 
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST 
		heart.custom_minimum_size = Vector2(24, 24) 
		
		heart_container.add_child(heart)
		hearts_list.append(heart)

	facing_direction = starting_direction
	update_animation_parameters(starting_direction) 

func _physics_process(_delta: float): 
	if is_dodging:
		velocity = facing_direction * dodge_speed
		move_and_slide()
		return 
		
	if is_attacking:
		velocity = Vector2.ZERO 
		move_and_slide()
		return

	var Input_direction = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"), 
		Input.get_action_strength("down") - Input.get_action_strength("up") 
	).normalized() 
	
	if Input_direction != Vector2.ZERO:
		facing_direction = Input_direction 
		update_animation_parameters(Input_direction) 

	if Input.is_action_just_pressed("attack") and not is_attacking and not is_dodging:
		perform_attack()
		return

	if Input.is_action_just_pressed("dodge") and can_dodge and not is_attacking: 
		perform_dodge()
		return
	
	var current_speed = move_speed
	if Input.is_action_pressed("run"): 
		current_speed = run_speed
	
	velocity = Input_direction * current_speed 
	move_and_slide() 
	pick_new_state() 

# --- Animation Functions ---
func update_animation_parameters(move_input : Vector2):
	if(move_input != Vector2.ZERO): 
		animation_tree.set("parameters/Walk/blend_position", move_input) 
		animation_tree.set("parameters/Idle/blend_position", move_input) 
		animation_tree.set("parameters/Attack/blend_position", move_input) 
		
		# Pushes the invisible damage zone in front of the player based on direction!
		weapon_hitbox.position = move_input * attack_reach
		
func pick_new_state():
	if is_dodging or is_attacking:
		return 
		
	if(velocity != Vector2.ZERO): 
		state_machine.travel("Walk") 
	else: 
		state_machine.travel("Idle") 

# --- Action Functions ---
func perform_dodge():
	is_dodging = true 
	can_dodge = false 
	await get_tree().create_timer(dodge_duration).timeout 
	is_dodging = false 
	pick_new_state() 
	await get_tree().create_timer(dodge_cooldown).timeout 
	can_dodge = true 

func perform_attack():
	is_attacking = true
	state_machine.travel("Attack")
	
	# Deal Damage!
	# Look at everything currently standing inside the WeaponHitbox
	var bodies = weapon_hitbox.get_overlapping_bodies()
	for body in bodies:
		# If the object is NOT the player, and it has health, hit it!
		if body != self and body.has_method("take_damage"):
			body.take_damage(attack_damage)
	
	await get_tree().create_timer(attack_duration).timeout 
	is_attacking = false
	pick_new_state()

# --- Health Functions ---
func take_damage(amount: int):
	current_health -= amount
	current_health = clampi(current_health, 0, health) 
	
	update_heart_display()
	
	if current_health <= 0:
		die()

func update_heart_display():
	for i in range(hearts_list.size()):
		if i < current_health:
			hearts_list[i].visible = true 
		else:
			hearts_list[i].visible = false 

func die():
	print("Player Died!")
	
	# 1. (Optional) Turn the player invisible or play a death animation here
	visible = false 
	
	# 2. Wait for 1 second so the restart isn't jarring and instant
	await get_tree().create_timer(1.0).timeout
	
	# 3. Reload the entire current level!
	get_tree().reload_current_scene()
	
# --- System Functions ---
func _input(_event):
	# "ui_cancel" is automatically mapped to the Escape key in Godot!
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

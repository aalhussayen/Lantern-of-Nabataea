extends CharacterBody2D

# --- Enemy Stats ---
@export var max_health: int = 3
@export var speed: float = 50.0
@export var attack_damage: int = 1
@export var chase_distance: float = 200.0 
@export var attack_reach: float = 25.0 # How far the hitbox pushes out
@export var attack_cooldown: float = 1.5 # Seconds between attacks

var current_health: int
var player: Node2D = null
var is_attacking: bool = false
var can_attack: bool = true
var facing_direction: Vector2 = Vector2(0, 1) # Start facing down

# --- Nodes ---
@onready var sprite = $Sprite2D
@onready var nav_agent = $NavigationAgent2D
@onready var weapon_hitbox = $WeaponHitbox

# --- Animation Tree ---
@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")

func _ready():
	current_health = max_health
	animation_tree.active = true
	update_facing_and_hitbox(facing_direction)

func _physics_process(_delta):
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return 
			
	if is_attacking:
		return
		
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# --- NEW: Look inside the weapon hitbox ---
	var player_in_hitbox = false
	if weapon_hitbox != null:
		var bodies = weapon_hitbox.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player"):
				player_in_hitbox = true
				break # We found the player, stop looking!
	
	# --- NEW: Attack if the player is physically touching the box! ---
	if player_in_hitbox and can_attack:
		perform_attack()
		
	elif distance_to_player <= chase_distance:
		nav_agent.target_position = player.global_position
		var next_path_position = nav_agent.get_next_path_position()
		
		var direction = global_position.direction_to(next_path_position)
		velocity = direction * speed
		move_and_slide()
		
		# --- UPDATE DIRECTION AND WALK ---
		facing_direction = direction
		update_facing_and_hitbox(facing_direction)
		state_machine.travel("Walk") 
	else:
		state_machine.travel("Idle") 

func perform_attack():
	is_attacking = true
	can_attack = false # Lock his attacks immediately
	velocity = Vector2.ZERO 
	
	# Snap direction right before attacking
	facing_direction = global_position.direction_to(player.global_position)
	update_facing_and_hitbox(facing_direction)
	
	state_machine.travel("Attack") 
	
	# Wait for the animation swing to hit (0.6 seconds)
	await get_tree().create_timer(0.6).timeout
	
	if weapon_hitbox != null:
		var bodies = weapon_hitbox.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(attack_damage)
			
	# Let him start walking/chasing again
	is_attacking = false
	
	# --- The Cooldown Timer ---
	# He will chase you, but cannot attack again until this finishes
	await get_tree().create_timer(attack_cooldown).timeout 
	can_attack = true 

# --- Enemy Health System ---
func take_damage(amount: int):
	current_health -= amount
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if current_health <= 0:
		die()

func die():
	queue_free() 

# --- 4-DIRECTIONAL UPDATE ---
func update_facing_and_hitbox(dir: Vector2):
	# 1. Send the direction to the AnimationTree
	animation_tree.set("parameters/Idle/blend_position", dir)
	animation_tree.set("parameters/Walk/blend_position", dir)
	animation_tree.set("parameters/Attack/blend_position", dir)
	
	# 2. Snap the Weapon Hitbox to the 4 sides
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			weapon_hitbox.position = Vector2(attack_reach, 0) # Right
		else:
			weapon_hitbox.position = Vector2(-attack_reach, 0) # Left
	else:
		if dir.y > 0:
			weapon_hitbox.position = Vector2(0, attack_reach) # Down
		else:
			weapon_hitbox.position = Vector2(0, -attack_reach) # Up

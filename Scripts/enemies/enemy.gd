class_name Enemy extends CharacterBody2D

## Base class for all enemies. Handles target acquisition, death/score, knockback,
## and a simple "walk toward the player" default. Subclasses (e.g. Goblin) override
## _physics_process to add attack behaviour. Concrete on its own too: with a
## monitorable hitbox in the scene it acts as a touch-damage enemy.

@export var speed: float = 70.0
@export var score_value: int = 10
## How fast knockback bleeds off (pixels/sec^2). Higher = shorter shove.
@export var knockback_decay: float = 1100.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var sprite: Sprite2D = $Sprite2D

var _player: Node2D
var _dead: bool = false
var _knockback: Vector2 = Vector2.ZERO

signal died(enemy: Enemy)

func _ready() -> void:
	add_to_group("enemies")
	health_component.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	_acquire_player()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(_player):
		_acquire_player()
		return
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	move_with_knockback(dir * speed, delta)
	face(dir)

## Moves the body using an intended velocity plus any current knockback, then
## decays the knockback. Subclasses call this instead of move_and_slide() so they
## get pushed back when hit.
func move_with_knockback(intended_velocity: Vector2, delta: float) -> void:
	velocity = intended_velocity + _knockback
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)

## Shoves the enemy away from a world position with the given strength.
func apply_knockback(from_global: Vector2, strength: float) -> void:
	if strength <= 0.0:
		return
	var dir: Vector2 = global_position - from_global
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	_knockback = dir.normalized() * strength

## Flips the sprite to face a horizontal direction. Subclasses reuse this.
func face(dir: Vector2) -> void:
	if absf(dir.x) > 0.01:
		sprite.flip_h = dir.x < 0.0

func _acquire_player() -> void:
	_player = get_tree().get_first_node_in_group("player")

## True while the enemy is alive and still in the tree. Use after `await` to bail
## out of a coroutine if the enemy died mid-action.
func is_active() -> bool:
	return is_instance_valid(self) and not _dead

func _on_hurt(hitbox: HitboxComponent) -> void:
	apply_knockback(hitbox.global_position, hitbox.knockback)

func _on_died() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	queue_free()

class_name Goblin extends Enemy

## A goblin that chases the player and stabs with a dagger when it gets close.
## Attack loop: chase -> windup (telegraph) -> strike (dagger hitbox live) ->
## recover -> repeat. It stands still while attacking so the swing reads clearly.

## Center-to-center distance at which the goblin stops and stabs.
@export var attack_range: float = 44.0
## Telegraph before the stab lands (gives the player time to react).
@export var windup_time: float = 0.35
## How long the dagger hitbox stays active.
@export var strike_time: float = 0.12
## Pause after a stab before it can move/attack again.
@export var recover_time: float = 0.55
@export var dagger_damage: float = 12.0

@onready var aim_pivot: Node2D = $AimPivot
@onready var dagger_hitbox: HitboxComponent = $AimPivot/DaggerHitbox
@onready var dagger_shape: CollisionShape2D = $AimPivot/DaggerHitbox/CollisionShape2D

var _attacking: bool = false
var _base_modulate: Color = Color.WHITE

func _ready() -> void:
	super()
	_base_modulate = sprite.modulate
	dagger_hitbox.damage = dagger_damage
	dagger_shape.disabled = true

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(_player):
		_acquire_player()
		return

	var to_player: Vector2 = _player.global_position - global_position
	var dir: Vector2 = to_player.normalized()
	aim_pivot.rotation = dir.angle()
	face(dir)

	if _attacking:
		move_with_knockback(Vector2.ZERO, delta)
		return

	if to_player.length() <= attack_range:
		move_with_knockback(Vector2.ZERO, delta)
		_attack()
	else:
		move_with_knockback(dir * speed, delta)

func _attack() -> void:
	_attacking = true

	# Windup: flash so the incoming stab is readable.
	sprite.modulate = Color(1.0, 0.6, 0.6)
	await get_tree().create_timer(windup_time).timeout
	if not is_active():
		return

	# Strike: dagger is dangerous only during this brief window.
	sprite.modulate = _base_modulate
	dagger_shape.set_deferred("disabled", false)
	await get_tree().create_timer(strike_time).timeout
	if not is_active():
		return
	dagger_shape.set_deferred("disabled", true)

	# Recover before the next swing.
	await get_tree().create_timer(recover_time).timeout
	if not is_active():
		return
	_attacking = false

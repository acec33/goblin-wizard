class_name HurtboxComponent extends Area2D

## Receives damage. Detects overlapping HitboxComponents and forwards the damage
## to its HealthComponent. Owns invincibility frames so a hit can't be applied
## every physics frame, and re-checks overlaps when iframes end so standing in a
## crowd keeps hurting at a steady rhythm.

@export var health_component: HealthComponent
## Seconds of invincibility after a hit. Set small (~0.1) on enemies so melee
## can land repeat hits; larger (~0.5) on the player for fairer crowd damage.
@export var invincibility_time: float = 0.4

var _invincible: bool = false

## Forwards the hitbox that landed so the owner can react (knockback, flash, sfx).
signal hurt(hitbox: HitboxComponent)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is HitboxComponent:
		_take_hit(area)

func _take_hit(hitbox: HitboxComponent) -> void:
	if _invincible or health_component == null:
		return
	health_component.take_damage(hitbox.damage)
	hurt.emit(hitbox)
	if invincibility_time > 0.0:
		_run_iframes()

func _run_iframes() -> void:
	_invincible = true
	await get_tree().create_timer(invincibility_time).timeout
	if not is_instance_valid(self):
		return
	_invincible = false
	# Still touching a hitbox (e.g. surrounded by enemies)? Take another hit now.
	for area in get_overlapping_areas():
		if area is HitboxComponent:
			_take_hit(area)
			return

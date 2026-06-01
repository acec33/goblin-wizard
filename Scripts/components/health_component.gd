class_name HealthComponent extends Node

## Holds health for any entity. Attach as a child node and wire a HurtboxComponent
## to it. Emits signals the HUD / enemy / player listen to.

@export var max_health: float = 100.0

var current_health: float

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

func _ready() -> void:
	current_health = max_health

func take_damage(amount: float) -> void:
	if current_health <= 0.0 or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	if current_health <= 0.0 or amount <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0.0

func health_fraction() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0

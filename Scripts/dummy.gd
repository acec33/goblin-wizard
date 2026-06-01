extends CharacterBody2D
## Practice dummy — looks like a goblin but never moves, attacks, or dies.
## In group "goblins" so the player's punch hit-test finds it; emits
## Events.entity_hit on the global bus so any ComboManager in the scene
## can react.

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("goblins")
	add_to_group("dummies")
	if anim.sprite_frames != null and anim.sprite_frames.has_animation("idle_south"):
		anim.play("idle_south")

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	Events.entity_hit.emit(amount, global_position, knockback, self)
	_flash()

func _flash() -> void:
	anim.modulate = Color(1, 0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color.WHITE, 0.15)

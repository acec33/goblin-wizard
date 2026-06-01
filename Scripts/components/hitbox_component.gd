class_name HitboxComponent extends Area2D

## Deals damage. Sits on a "*_hitbox" collision layer and is detected by a
## HurtboxComponent. The hurtbox owns damage application, so this is mostly a
## data carrier (how much it hurts, and optional knockback).

@export var damage: float = 10.0
## Pixels/sec of knockback applied to whatever it hits. 0 = none.
@export var knockback: float = 0.0

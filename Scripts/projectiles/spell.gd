class_name Spell extends HitboxComponent

## A flying spell projectile. It IS a HitboxComponent, so enemy hurtboxes detect
## it and apply its damage. It also monitors hurtboxes itself purely to know when
## to despawn / how many enemies it may pierce.

@export var speed: float = 480.0
@export var lifetime: float = 2.0
## Extra enemies the spell can pass through after the first hit. 0 = dies on first
## hit, -1 = pierces forever (until lifetime).
@export var pierce: int = 0

var _dir: Vector2 = Vector2.RIGHT
var _hits_left: int = 0

func setup(dir: Vector2) -> void:
	_dir = dir.normalized()
	rotation = _dir.angle()

func _ready() -> void:
	_hits_left = pierce
	monitorable = true   # enemy hurtboxes can see us (to take damage)
	monitoring = true    # we can see enemy hurtboxes (to despawn)
	area_entered.connect(_on_area_entered)
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	global_position += _dir * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		if _hits_left == 0:
			queue_free()
		elif _hits_left > 0:
			_hits_left -= 1

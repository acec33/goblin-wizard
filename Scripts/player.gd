extends CharacterBody2D
## Player — the blue ninja. 8-direction walk + idle, and a left/right punch attack.
## Animations live in res://Assets/blue-ninja/blue_ninja_frames.tres (an AnimatedSprite2D).
## Health + hit flash included.

signal health_changed(current: int, max_value: int)
signal died

enum State { IDLE, WALK, PUNCH }

@export var move_speed: float = 240.0
@export var max_health: int = 100
@export var attack_damage: int = 25
@export var attack_range: float = 95.0
@export var attack_arc_degrees: float = 130.0
@export var attack_cooldown: float = 0.45
@export var knockback_force: float = 520.0

@export_group("Game feel")
@export var hit_stop_duration: float = 0.06   # seconds of freeze on a landed punch
@export var shake_per_hit: float = 0.45       # trauma added per landed punch (0..1)
@export var shake_max_offset: float = 8.0     # max camera jitter in pixels
@export var shake_decay: float = 4.0          # how fast the shake settles

# 8 direction names, ordered by 45-degree steps starting at east (+x), going clockwise
# (screen Y is down, so the next step after east is south-east).
const DIR_NAMES := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

var health: int
var _state: int = State.IDLE
var _facing: String = "south"
var _attack_timer: float = 0.0
var _is_dead: bool = false
var _punch_aim: Vector2 = Vector2.ZERO   # aim locked in when the punch starts
var _punch_hit_done: bool = false        # ensures the hit lands once per punch
var _shake_trauma: float = 0.0
var _hit_stopping: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	health = max_health
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_frame_changed)
	_play("idle_south")
	health_changed.emit(health, max_health)

func _process(delta: float) -> void:
	# Screen shake: jitter the camera based on decaying "trauma".
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(_shake_trauma - shake_decay * delta, 0.0)
		var amt := _shake_trauma * _shake_trauma
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_max_offset * amt
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta

	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# While a punch is playing, stand still and let it finish.
	if _state == State.PUNCH:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Start a punch?
	if _wants_attack() and _attack_timer <= 0.0:
		_start_punch()
		return

	# Otherwise walk or idle.
	var input_dir := _read_move_input()
	if input_dir != Vector2.ZERO:
		_facing = _dir_to_name(input_dir)
		_state = State.WALK
		velocity = input_dir * move_speed
		_play("walk_" + _facing)
	else:
		_state = State.IDLE
		velocity = Vector2.ZERO
		_play("idle_" + _facing)
	move_and_slide()

# ---------------- Input ----------------

func _read_move_input() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	return d.normalized()

func _wants_attack() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_J)

# ---------------- Attack ----------------

func _start_punch() -> void:
	_state = State.PUNCH
	_attack_timer = attack_cooldown
	velocity = Vector2.ZERO

	# Face toward the mouse for the hit direction.
	var aim := get_global_mouse_position() - global_position
	if aim.length() > 0.001:
		_facing = _dir_to_name(aim)
		aim = aim.normalized()
	else:
		aim = _facing_vector()

	# Pick the punch that swings toward the target: aim on his left -> punch_left,
	# aim on his right -> punch_right.
	_play("punch_left" if aim.x < 0.0 else "punch_right")

	# Damage is dealt on the LAST frame of the punch (see _on_frame_changed).
	_punch_aim = aim
	_punch_hit_done = false

func _on_frame_changed() -> void:
	if _state != State.PUNCH or _punch_hit_done:
		return
	var total := anim.sprite_frames.get_frame_count(anim.animation)
	if anim.frame >= total - 1:
		_punch_hit_done = true
		_deal_damage(_punch_aim)

func _deal_damage(aim: Vector2) -> void:
	var half_arc := deg_to_rad(attack_arc_degrees) * 0.5
	var hits := 0
	for goblin in get_tree().get_nodes_in_group("goblins"):
		if not is_instance_valid(goblin):
			continue
		var to_goblin: Vector2 = goblin.global_position - global_position
		if to_goblin.length() > attack_range:
			continue
		if absf(aim.angle_to(to_goblin)) <= half_arc and goblin.has_method("take_damage"):
			var push := to_goblin.normalized() if to_goblin.length() > 0.001 else aim
			goblin.take_damage(attack_damage, push * knockback_force)
			hits += 1
	if hits > 0:
		_impact(hits)

func _impact(hits: int) -> void:
	# Punch connected — add screen-shake trauma and freeze briefly for weight.
	var trauma := shake_per_hit + 0.08 * float(hits - 1)
	_shake_trauma = minf(_shake_trauma + trauma, 1.0)
	_hit_stop(hit_stop_duration)

func _hit_stop(duration: float) -> void:
	if _hit_stopping:
		return
	_hit_stopping = true
	Engine.time_scale = 0.0
	# 4th arg = ignore_time_scale, so this timer still ticks while frozen.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stopping = false

func _on_anim_finished() -> void:
	if _state == State.PUNCH:
		_state = State.IDLE

# ---------------- Health ----------------

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	_flash(Color(1, 0.4, 0.4))
	if health == 0:
		_die()

func _flash(c: Color) -> void:
	anim.modulate = c
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color.WHITE, 0.2)

func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	anim.modulate = Color(0.6, 0.6, 0.6)
	_play("idle_" + _facing)
	died.emit()

# ---------------- Helpers ----------------

func _play(anim_name: String) -> void:
	if anim.animation != anim_name or not anim.is_playing():
		anim.play(anim_name)

func _dir_to_name(v: Vector2) -> String:
	var deg := fposmod(rad_to_deg(v.angle()), 360.0)
	var idx := int(round(deg / 45.0)) % 8
	return DIR_NAMES[idx]

func _facing_vector() -> Vector2:
	match _facing:
		"east": return Vector2.RIGHT
		"west": return Vector2.LEFT
		"north": return Vector2.UP
		"south": return Vector2.DOWN
		"north_east": return Vector2(1, -1).normalized()
		"north_west": return Vector2(-1, -1).normalized()
		"south_east": return Vector2(1, 1).normalized()
		"south_west": return Vector2(-1, 1).normalized()
	return Vector2.DOWN

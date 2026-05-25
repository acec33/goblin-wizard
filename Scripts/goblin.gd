extends CharacterBody2D
## Goblin — chases the player and slashes with its dagger when in range.
## Uses the AnimatedSprite2D goblin art: run / slash / idle in 8 directions.
## Several directions ship with multiple art variants; one is picked at RANDOM
## each time an animation (re)starts (see _play_group).

signal died(goblin)

enum State { RUN, ATTACK, IDLE }

@export var move_speed: float = 115.0
@export var max_health: int = 30
@export var contact_damage: int = 10
@export var contact_range: float = 40.0
@export var attack_cooldown: float = 1.2
@export var knockback_decay: float = 1600.0   # how fast a shove bleeds off (px/sec^2)

# 8 direction names by 45-degree steps from east, clockwise (screen Y is down).
const DIR_NAMES := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

var health: int
var _state: int = State.RUN
var _facing: String = "south"
var _attack_timer: float = 0.0
var _attack_hit_done: bool = false
var _knockback: Vector2 = Vector2.ZERO
var _player: Node2D
var _variants: Dictionary = {}      # "run_south" -> ["run_south_0", "run_south_1", ...]
var _current_group: String = ""

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("goblins")
	health = max_health
	_build_variant_map()
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_frame_changed)
	_find_player()

func _build_variant_map() -> void:
	# Group animation names by direction, dropping a trailing "_<number>".
	for n in anim.sprite_frames.get_animation_names():
		var key := n
		var parts := n.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			key = parts[0]
		if not _variants.has(key):
			_variants[key] = []
		_variants[key].append(n)

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _physics_process(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)

	if _player == null or not is_instance_valid(_player):
		_find_player()

	# Mid-slash: hold and let the swing finish (knockback can still shove it).
	if _state == State.ATTACK:
		velocity = _knockback
		move_and_slide()
		return

	if _knockback.length() > 10.0:
		velocity = _knockback
		move_and_slide()
		return

	if _player != null and is_instance_valid(_player):
		var to_player: Vector2 = _player.global_position - global_position
		_facing = _dir_to_name(to_player)
		if to_player.length() > contact_range:
			_state = State.RUN
			velocity = to_player.normalized() * move_speed
			_play_group("run_" + _facing)
		else:
			velocity = Vector2.ZERO
			if _attack_timer <= 0.0:
				_start_attack()
			else:
				_state = State.IDLE
				_play_group("idle_" + _facing)
	else:
		velocity = Vector2.ZERO
		_play_group("idle_" + _facing)
	move_and_slide()

func _start_attack() -> void:
	_state = State.ATTACK
	_attack_timer = attack_cooldown
	_attack_hit_done = false
	velocity = Vector2.ZERO
	_play_group("slash_" + _facing)

func _on_frame_changed() -> void:
	# Land the stab on the slash's last frame, if the player is still in reach.
	if _state != State.ATTACK or _attack_hit_done:
		return
	var total := anim.sprite_frames.get_frame_count(anim.animation)
	if anim.frame >= total - 1:
		_attack_hit_done = true
		if _player != null and is_instance_valid(_player):
			if global_position.distance_to(_player.global_position) <= contact_range + 12.0:
				if _player.has_method("take_damage"):
					_player.take_damage(contact_damage)

func _on_anim_finished() -> void:
	if _state == State.ATTACK:
		_state = State.IDLE   # re-evaluated next physics frame

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	health = maxi(0, health - amount)
	_knockback = knockback
	_flash()
	if health == 0:
		_die()

func _flash() -> void:
	anim.modulate = Color(1, 0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color.WHITE, 0.15)

func _die() -> void:
	died.emit(self)
	queue_free()

# ---- helpers ----

func _play_group(group: String) -> void:
	# Re-roll the random variant only when the group changes (or playback stopped),
	# so a looping run/idle doesn't pick a new one every single frame.
	if group == _current_group and anim.is_playing():
		return
	_current_group = group
	var anim_name := group
	if _variants.has(group):
		var list: Array = _variants[group]
		anim_name = list[randi() % list.size()]
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)

func _dir_to_name(v: Vector2) -> String:
	var deg := fposmod(rad_to_deg(v.angle()), 360.0)
	var idx := int(round(deg / 45.0)) % 8
	return DIR_NAMES[idx]

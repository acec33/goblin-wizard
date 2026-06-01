extends Node2D
class_name DamageNumber
## A damage value visualized as a physical object popped out of a hit target.
##
## Lifecycle:
##   AIRBORNE — pseudo-3D arc with multi-bounce. The label is offset upward
##              from a ground-position by `_height`; height decays under
##              `gravity`; on ground impact, vertical velocity reflects with
##              `bounce_dampening` and horizontal damps with `ground_friction`.
##              Each impact triggers a squash & stretch flash. Settles to
##              RESTING when vertical speed falls under `settle_speed`.
##   RESTING  — sits in place until something pulls it.
##   PULLED   — homes in on a target Node2D at `pull_speed` (the target can
##              move; we re-aim every frame). Calls `on_arrive` when reached.
##   DISMISSED — terminal; used for the float-and-fade combo-sum popup.
##
## Designed to be reusable across scenes — see ComboManager for the combo
## flow, but a damage number doesn't *need* a combo manager. Anyone can
## instantiate, add to the tree, and call `pop()` for a one-shot popup.

enum State { AIRBORNE, RESTING, PULLED, DISMISSED }

@export_group("Pop")
@export var initial_jump: float = 360.0           # vertical kick on spawn (px/s)
@export var horizontal_speed_range: Vector2 = Vector2(140.0, 280.0)
@export var arc_jitter_degrees: float = 35.0      # cone width around push_dir
@export var spin_max: float = 6.0                 # max rad/s while airborne

@export_group("Physics")
@export var gravity: float = 1700.0
@export var bounce_dampening: float = 0.55        # vh after bounce = -vh * this
@export var ground_friction: float = 0.65         # vxy *= this per bounce
@export var settle_speed: float = 80.0            # |vh| below this on bounce stops the number
@export var spin_friction: float = 0.5            # rot_speed *= this per bounce

@export_group("Visual")
@export var squash_strength: float = 0.35         # 0 = none, 0.5 = strong squash
@export var squash_duration: float = 0.12
@export var rest_z_index: int = 5                 # render above world sprites but below HUD

# ----- Runtime state -----
var value: int = 0
var _state: int = State.AIRBORNE

# Pseudo-3D physics
var _ground_pos: Vector2 = Vector2.ZERO
var _height: float = 0.0
var _vh: float = 0.0
var _vxy: Vector2 = Vector2.ZERO
var _rot_speed: float = 0.0
var _squash_tween: Tween

# Pull-to-target state
var _pull_target: Node2D
var _pull_speed: float = 0.0
var _pull_offset: Vector2 = Vector2.ZERO
var _arrived_cb: Callable

@onready var label: Label = $Label

func _ready() -> void:
	z_index = rest_z_index
	label.text = str(value)

# ---------------- Public API ----------------

## Display `amount` and immediately launch it as a physical projectile.
## `origin` is the world position to spawn at; `push_dir` is the rough
## direction to fly (will be jittered within `arc_jitter_degrees`).
func pop(amount: int, origin: Vector2, push_dir: Vector2) -> void:
	set_value(amount)
	_ground_pos = origin
	global_position = origin
	_height = 0.0
	_vh = initial_jump
	var base_dir := push_dir.normalized() if push_dir.length() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
	var jitter := deg_to_rad(arc_jitter_degrees) * randf_range(-1.0, 1.0)
	var dir := base_dir.rotated(jitter)
	var speed := randf_range(horizontal_speed_range.x, horizontal_speed_range.y)
	_vxy = dir * speed
	_rot_speed = randf_range(-spin_max, spin_max)
	scale = Vector2.ONE
	rotation = 0.0
	_state = State.AIRBORNE

## Set the displayed number without launching physics. Used for static popups
## (e.g. the merged combo-sum, which uses `float_above` for its own animation).
func set_value(amount: int) -> void:
	value = amount
	if is_node_ready():
		label.text = str(amount)

## Home in on `target` until reached, then fire `on_arrive(self)`.
## `offset` is a position offset from the target (e.g. above its head).
func pull_to(target: Node2D, speed: float, offset: Vector2, on_arrive: Callable) -> void:
	_state = State.PULLED
	_pull_target = target
	_pull_speed = speed
	_pull_offset = offset
	_arrived_cb = on_arrive

## Drift upward from `anchor` while fading. Used for the combo-sum popup.
func float_above(anchor: Node2D, rise: float, duration: float, color: Color = Color(1, 0.92, 0.35, 1)) -> void:
	_state = State.DISMISSED
	label.modulate = color
	var start := anchor.global_position + Vector2(0, -rise * 0.5)
	global_position = start
	var tw := create_tween()
	tw.tween_property(self, "global_position", anchor.global_position + Vector2(0, -rise), duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0), duration)
	tw.tween_callback(queue_free)

# ---------------- Internals ----------------

func _process(delta: float) -> void:
	match _state:
		State.AIRBORNE:
			_tick_airborne(delta)
		State.PULLED:
			_tick_pull(delta)
		# RESTING / DISMISSED: nothing per-frame.

func _tick_airborne(delta: float) -> void:
	_ground_pos += _vxy * delta
	_height += _vh * delta
	_vh -= gravity * delta
	rotation += _rot_speed * delta

	# Ground impact: only register on the *downward* crossing so we don't
	# re-bounce on the very next frame while still pointing up.
	if _height <= 0.0 and _vh < 0.0:
		_height = 0.0
		_vh = -_vh * bounce_dampening
		_vxy *= ground_friction
		_rot_speed *= spin_friction
		if _vh < settle_speed:
			_settle()
		else:
			_squash()
	global_position = _ground_pos - Vector2(0, _height)

func _settle() -> void:
	_height = 0.0
	_vh = 0.0
	_vxy = Vector2.ZERO
	_rot_speed = 0.0
	_state = State.RESTING
	global_position = _ground_pos
	# Tween rotation back to upright so the resting number reads cleanly.
	var tw := create_tween()
	tw.tween_property(self, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.18)

func _squash() -> void:
	# Squash & stretch on bounce: wide & flat, then snap back. Re-trigger
	# cleanly on repeat bounces by killing any prior tween.
	if _squash_tween != null and _squash_tween.is_running():
		_squash_tween.kill()
	var flat := Vector2(1.0 + squash_strength, 1.0 - squash_strength)
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "scale", flat, squash_duration * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(self, "scale", Vector2.ONE, squash_duration * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _tick_pull(delta: float) -> void:
	if not is_instance_valid(_pull_target):
		queue_free()
		return
	var target_pos: Vector2 = _pull_target.global_position + _pull_offset
	var to_target := target_pos - global_position
	var step := _pull_speed * delta
	# Settle rotation while homing in — looks cleaner on arrival.
	rotation = lerp_angle(rotation, 0.0, clamp(step / maxf(to_target.length(), 1.0), 0.0, 1.0))
	if to_target.length() <= step:
		global_position = target_pos
		_state = State.DISMISSED
		if _arrived_cb.is_valid():
			_arrived_cb.call(self)
		return
	global_position += to_target.normalized() * step

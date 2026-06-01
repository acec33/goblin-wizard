class_name Player extends CharacterBody2D

## Brawler. Moves with WASD/arrows, faces the mouse, and fights hand-to-hand with
## a quick punch and a heavier kick. Both deal damage and knock enemies back; the
## kick hits harder and shoves further. Health lives on a HealthComponent child;
## incoming damage arrives through a HurtboxComponent child.
##
## Visuals: an 8-direction sprite (Man_1) driven by an AnimatedSprite2D whose
## SpriteFrames are built in code from the exported rotation/run PNGs. The body
## faces its movement direction while running, and the aim (mouse) direction when
## idle or attacking, so punches/kicks read toward the cursor.

@export var speed: float = 220.0

@export_group("Punch")
@export var punch_damage: float = 12.0
@export var punch_knockback: float = 170.0
@export var punch_active_time: float = 0.1
@export var punch_recovery: float = 0.22

@export_group("Kick")
@export var kick_damage: float = 26.0
@export var kick_knockback: float = 430.0
@export var kick_active_time: float = 0.12
@export var kick_recovery: float = 0.45

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var aim_pivot: Node2D = $AimPivot
@onready var attack_hitbox: HitboxComponent = $AimPivot/AttackHitbox
@onready var attack_shape: CollisionShape2D = $AimPivot/AttackHitbox/CollisionShape2D

# 8 directions in clockwise order starting at east (matches the asset folders and
# Vector2.angle(): 0 = east, +PI/2 = south because Y points down in 2D).
const DIR_NAMES: PackedStringArray = [
	"east", "south-east", "south", "south-west",
	"west", "north-west", "north", "north-east",
]
const IDLE_DIR: String = "res://Assets/Man_1/rotations"
const RUN_DIR: String = "res://Assets/Man_1/animations/Running-badf624c"

var _busy: bool = false
var _aim_dir: Vector2 = Vector2.DOWN
var _alive: bool = true

signal died

func _ready() -> void:
	add_to_group("player")
	health_component.died.connect(_on_died)
	attack_shape.disabled = true
	anim.sprite_frames = _build_sprite_frames()
	anim.play("idle_south")

func _physics_process(_delta: float) -> void:
	if not _alive:
		return

	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vec * speed
	move_and_slide()

	_update_aim()
	_update_animation(input_vec)

	if not _busy:
		if Input.is_action_pressed("attack"):
			_attack(punch_damage, punch_knockback, punch_active_time, punch_recovery)
		elif Input.is_action_pressed("kick"):
			_attack(kick_damage, kick_knockback, kick_active_time, kick_recovery)

func _update_aim() -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length() > 4.0:
		_aim_dir = to_mouse.normalized()
	aim_pivot.rotation = _aim_dir.angle()

func _update_animation(move_input: Vector2) -> void:
	var facing: Vector2
	var kind: String
	if _busy:
		# No dedicated attack frames yet; hold the idle pose facing the target.
		facing = _aim_dir
		kind = "idle"
	elif move_input.length() > 0.1:
		facing = move_input
		kind = "run"
	else:
		facing = _aim_dir
		kind = "idle"

	var anim_name: String = "%s_%s" % [kind, _dir_name(facing)]
	if anim.animation != anim_name or not anim.is_playing():
		anim.play(anim_name)

func _dir_name(v: Vector2) -> String:
	if v.length() < 0.001:
		return "south"
	var idx: int = int(round(v.angle() / (PI / 4.0)))
	idx = ((idx % 8) + 8) % 8
	return DIR_NAMES[idx]

func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for d in DIR_NAMES:
		var idle_name: String = "idle_" + d
		sf.add_animation(idle_name)
		sf.set_animation_loop(idle_name, true)
		sf.set_animation_speed(idle_name, 5.0)
		var idle_tex: Texture2D = load("%s/%s.png" % [IDLE_DIR, d])
		if idle_tex:
			sf.add_frame(idle_name, idle_tex)

		var run_name: String = "run_" + d
		sf.add_animation(run_name)
		sf.set_animation_loop(run_name, true)
		sf.set_animation_speed(run_name, 12.0)
		for i in 4:
			var run_tex: Texture2D = load("%s/%s/frame_%03d.png" % [RUN_DIR, d, i])
			if run_tex:
				sf.add_frame(run_name, run_tex)
	return sf

func _attack(damage: float, knockback: float, active_time: float, recovery: float) -> void:
	_busy = true
	attack_hitbox.damage = damage
	attack_hitbox.knockback = knockback
	attack_shape.set_deferred("disabled", false)
	await get_tree().create_timer(active_time).timeout
	if not is_instance_valid(self):
		return
	attack_shape.set_deferred("disabled", true)
	await get_tree().create_timer(recovery).timeout
	if is_instance_valid(self):
		_busy = false

func _on_died() -> void:
	if not _alive:
		return
	_alive = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	hide()
	died.emit()

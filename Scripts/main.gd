extends Node2D
## Game manager — spawns waves of goblins, tracks kills, draws the arena, and
## handles the game-over / restart flow.
##
## Player and HUD are NODES placed in main.tscn (edit them in the editor); this
## script only wires them together. Goblins are spawned at runtime from
## Scenes/goblin.tscn because waves are dynamic — but each is still a scene.

const GoblinScene := preload("res://Scenes/goblin.tscn")

@export var base_wave_size: int = 5
@export var wave_growth: int = 3          # extra goblins added each new wave
@export var spawn_radius: float = 720.0   # goblins appear this far from the player (off-screen)
@export var bg_color: Color = Color(0.09, 0.10, 0.13)
@export var grid_color: Color = Color(1, 1, 1, 0.05)
@export var grid_step: float = 64.0

var _wave: int = 0
var _score: int = 0
var _alive: int = 0
var _game_over: bool = false

@onready var _player: CharacterBody2D = $Player
@onready var _hud = $HUD  # Scenes/hud.tscn (GameHud); untyped so it parses before the class registers

func _ready() -> void:
	Engine.time_scale = 1.0  # safety: clear any leftover hit-stop freeze on (re)start
	_player.health_changed.connect(_on_health_changed)
	_player.died.connect(_on_player_died)
	_hud.update_health(_player.health, _player.max_health)
	_start_next_wave()

func _process(_delta: float) -> void:
	queue_redraw()  # redraw the arena each frame so the grid tracks the camera

func _input(event: InputEvent) -> void:
	if not _game_over:
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		get_tree().reload_current_scene()

# ---------------- Waves ----------------

func _start_next_wave() -> void:
	_wave += 1
	var count := base_wave_size + (_wave - 1) * wave_growth
	_alive += count
	for i in count:
		_spawn_goblin()
	_hud.update_kills(_score)
	_hud.update_wave(_wave)

func _spawn_goblin() -> void:
	var g := GoblinScene.instantiate()
	var angle := randf() * TAU
	g.global_position = _player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius
	g.died.connect(_on_goblin_died)
	add_child(g)

func _on_goblin_died(_g) -> void:
	_score += 1
	_alive -= 1
	_hud.update_kills(_score)
	if _alive <= 0 and not _game_over:
		_start_next_wave()

# ---------------- HUD wiring ----------------

func _on_health_changed(current: int, max_value: int) -> void:
	_hud.update_health(current, max_value)

func _on_player_died() -> void:
	_game_over = true
	_hud.show_game_over(_score, _wave)

# ---------------- Arena background ----------------
# Procedural on purpose: an infinite grid that follows the camera can't be a
# fixed node. Its look is editable via the bg_color / grid_color / grid_step
# exports on the Main node.

func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var center := cam.global_position if cam != null else Vector2.ZERO
	var view := get_viewport_rect().size
	var tl := center - view
	var br := center + view
	draw_rect(Rect2(tl, view * 2.0), bg_color, true)
	var x := floorf(tl.x / grid_step) * grid_step
	while x < br.x:
		draw_line(Vector2(x, tl.y), Vector2(x, br.y), grid_color, 1.0)
		x += grid_step
	var y := floorf(tl.y / grid_step) * grid_step
	while y < br.y:
		draw_line(Vector2(tl.x, y), Vector2(br.x, y), grid_color, 1.0)
		y += grid_step

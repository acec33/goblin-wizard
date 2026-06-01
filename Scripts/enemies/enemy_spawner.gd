class_name EnemySpawner extends Node2D

## Spawns enemies in a ring just outside the player's view at an interval that
## ramps from `initial_interval` down to `min_interval` over `ramp_time` seconds,
## so pressure increases the longer you survive.

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 560.0
@export var initial_interval: float = 1.4
@export var min_interval: float = 0.22
@export var ramp_time: float = 120.0
## Stop spawning past this many live enemies (0 = no cap). Keeps the horde sane.
@export var max_alive: int = 200
## Optional node to parent spawned enemies under. Falls back to the current scene.
@export var enemies_container_path: NodePath

var _player: Node2D
var _elapsed: float = 0.0
var _spawn_timer: float = 0.0

signal enemy_spawned(enemy: Enemy)

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_spawn_timer = initial_interval

func _process(delta: float) -> void:
	if GameState.is_game_over:
		return
	_elapsed += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn()
		_spawn_timer = _current_interval()

func _current_interval() -> float:
	var t: float = clampf(_elapsed / ramp_time, 0.0, 1.0)
	return lerpf(initial_interval, min_interval, t)

func _spawn() -> void:
	if enemy_scene == null:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			return
	if max_alive > 0 and get_tree().get_node_count_in_group("enemies") >= max_alive:
		return

	var angle: float = randf() * TAU
	var pos: Vector2 = _player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius

	var enemy: Enemy = enemy_scene.instantiate()
	var container: Node = get_node_or_null(enemies_container_path)
	if container == null:
		container = get_tree().current_scene
	container.add_child(enemy)
	enemy.global_position = pos
	enemy_spawned.emit(enemy)

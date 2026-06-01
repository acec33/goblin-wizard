extends Node2D

## Top-level game scene. Resets run state, awards score when enemies die, ends
## the run when the player dies, and handles restart input on game over.

@onready var player: Player = $Player
@onready var spawner: EnemySpawner = $EnemySpawner

func _ready() -> void:
	GameState.reset()
	player.died.connect(_on_player_died)
	spawner.enemy_spawned.connect(_on_enemy_spawned)

func _on_enemy_spawned(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Enemy) -> void:
	GameState.add_score(enemy.score_value)

func _on_player_died() -> void:
	GameState.trigger_game_over()

func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_game_over and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

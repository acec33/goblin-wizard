extends Node

## Autoload singleton (registered as "GameState"). Holds run-wide state — score
## and game-over flag — so the HUD and scenes can stay decoupled. Reset at the
## start of each run.

signal score_changed(score: int)
signal game_over

var score: int = 0
var is_game_over: bool = false

func reset() -> void:
	score = 0
	is_game_over = false
	score_changed.emit(score)

func add_score(amount: int) -> void:
	if is_game_over:
		return
	score += amount
	score_changed.emit(score)

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over.emit()

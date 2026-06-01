class_name HUD extends CanvasLayer

## Shows health, score and survival time, plus a game-over overlay. Pulls health
## from the player in the "player" group and the rest from the GameState autoload,
## so it needs no manual wiring in the main scene.

@onready var health_bar: ProgressBar = %HealthBar
@onready var score_label: Label = %ScoreLabel
@onready var time_label: Label = %TimeLabel
@onready var game_over_panel: Control = %GameOverPanel
@onready var final_score_label: Label = %FinalScoreLabel

var _time: float = 0.0
var _running: bool = true

func _ready() -> void:
	game_over_panel.hide()
	GameState.score_changed.connect(_on_score_changed)
	GameState.game_over.connect(_on_game_over)
	_on_score_changed(GameState.score)

	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_node("HealthComponent"):
		var hc: HealthComponent = player.get_node("HealthComponent")
		hc.health_changed.connect(_on_health_changed)
		_on_health_changed(hc.current_health, hc.max_health)

func _process(delta: float) -> void:
	if _running:
		_time += delta
		time_label.text = "Time  %.1fs" % _time

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func _on_score_changed(score: int) -> void:
	score_label.text = "Score  %d" % score

func _on_game_over() -> void:
	_running = false
	final_score_label.text = "Score: %d\nSurvived: %.1fs" % [GameState.score, _time]
	game_over_panel.show()

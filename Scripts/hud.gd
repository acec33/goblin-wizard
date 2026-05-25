extends CanvasLayer
class_name GameHud
## On-screen HUD. Built as NODES in Scenes/hud.tscn so labels/fonts/positions are
## editable in the Godot editor. main.gd just calls these update_* methods.

@onready var hp_label: Label = $HP
@onready var kills_label: Label = $Kills
@onready var wave_label: Label = $Wave
@onready var banner: Label = $Banner

func update_health(current: int, max_value: int) -> void:
	hp_label.text = "HP: %d / %d" % [current, max_value]

func update_kills(n: int) -> void:
	kills_label.text = "Kills: %d" % n

func update_wave(n: int) -> void:
	wave_label.text = "Wave: %d" % n

func show_game_over(kills: int, wave: int) -> void:
	banner.visible = true
	banner.text = "YOU DIED\n\nKills: %d     Wave: %d\n\nPress any key to restart" % [kills, wave]

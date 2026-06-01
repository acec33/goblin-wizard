extends Control
## Start menu — Start (main game), Training (practice dummy), Options (stub), Quit.
## Quit pops the ExitWarning modal child; Yes really quits, No returns focus.

@export_file("*.tscn") var main_scene_path: String = "res://Scenes/main.tscn"
@export_file("*.tscn") var training_scene_path: String = "res://Scenes/training.tscn"

@onready var _start_btn: Button = $CenterBox/VBox/StartButton
@onready var _training_btn: Button = $CenterBox/VBox/TrainingButton
@onready var _options_btn: Button = $CenterBox/VBox/OptionsButton
@onready var _quit_btn: Button = $CenterBox/VBox/QuitButton
@onready var _status: Label = $CenterBox/VBox/Status
@onready var _exit_warning = $ExitWarning

func _ready() -> void:
	_start_btn.pressed.connect(_on_start_pressed)
	_training_btn.pressed.connect(_on_training_pressed)
	_options_btn.pressed.connect(_on_options_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)
	_exit_warning.confirmed.connect(_on_exit_confirmed)
	_exit_warning.cancelled.connect(_on_exit_cancelled)
	_start_btn.grab_focus()
	_status.text = ""

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(main_scene_path)

func _on_training_pressed() -> void:
	get_tree().change_scene_to_file(training_scene_path)

func _on_options_pressed() -> void:
	_status.text = "Options menu coming soon."

func _on_quit_pressed() -> void:
	_exit_warning.open()

func _on_exit_confirmed() -> void:
	get_tree().quit()

func _on_exit_cancelled() -> void:
	_quit_btn.grab_focus()

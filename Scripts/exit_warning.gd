extends Control
## Modal "Are you sure?" confirmation. Drop the scene into any UI / HUD
## CanvasLayer as a hidden child; call open() to show it. Emits
## `confirmed` (A / Enter) or `cancelled` (B / Esc / No button).
##
## Pauses the SceneTree while open so gameplay freezes underneath. The
## scene root has `process_mode = PROCESS_MODE_ALWAYS` so its own input
## still fires while paused.

signal confirmed
signal cancelled

@export var default_prompt: String = "Are you sure?"

@onready var _title: Label = $Backdrop/Panel/Margin/VBox/Title
@onready var _yes_btn: Button = $Backdrop/Panel/Margin/VBox/Buttons/YesGroup/YesButton
@onready var _no_btn: Button = $Backdrop/Panel/Margin/VBox/Buttons/NoGroup/NoButton

func _ready() -> void:
	visible = false
	_title.text = default_prompt
	_yes_btn.pressed.connect(_on_yes)
	_no_btn.pressed.connect(_on_no)
	_yes_btn.focus_neighbor_right = _no_btn.get_path()
	_no_btn.focus_neighbor_left = _yes_btn.get_path()

## Open the prompt. Optional `prompt` overrides `default_prompt` for one
## invocation — handy for "Quit to desktop?" vs "Return to menu?".
func open(prompt: String = "") -> void:
	if visible:
		return
	if prompt != "":
		_title.text = prompt
	else:
		_title.text = default_prompt
	visible = true
	get_tree().paused = true
	# Focus on Yes so A / Enter immediately confirms.
	_yes_btn.grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# B / Esc closes regardless of focus. ui_accept is handled natively by
	# the focused Yes button — no special case needed.
	if event.is_action_pressed("ui_cancel"):
		_on_no()
		accept_event()

func _on_yes() -> void:
	close()
	confirmed.emit()

func _on_no() -> void:
	close()
	cancelled.emit()

extends Node2D
## Training mode — Player + practice Dummy inside a confined arena.
##
## The combo / damage-number system lives in `ComboManager` (a child node);
## this script just owns the arena visuals, HUD wiring, and the exit-prompt
## flow (Esc OR Xbox Start → "Return to menu?" confirmation).

@export_file("*.tscn") var menu_scene_path: String = "res://Scenes/start_menu.tscn"
@export var exit_prompt: String = "Return to menu?"

@export var bg_color: Color = Color(0.09, 0.10, 0.13)
@export var grid_color: Color = Color(1, 1, 1, 0.05)
@export var grid_step: float = 64.0
# Visible border for the confined practice zone. Match the actual wall layout
# placed in training.tscn — change both together if you resize the arena.
@export var arena_center: Vector2 = Vector2.ZERO
@export var arena_size: Vector2 = Vector2(1200, 800)
@export var wall_color: Color = Color(0.45, 0.38, 0.30, 1)
@export var wall_thickness: float = 6.0

@onready var _combo: ComboManager = $ComboManager
@onready var _stored_label: Label = $HUD/Stored
@onready var _exit_warning = $HUD/ExitWarning

func _ready() -> void:
	# Defensive: previous scene may have left the tree paused if it crashed
	# out of an ExitWarning. Always start unfrozen.
	get_tree().paused = false
	Engine.time_scale = 1.0
	_combo.combo_completed.connect(_on_combo_completed)
	_exit_warning.confirmed.connect(_on_exit_confirmed)
	_update_stored_label()

func _process(_delta: float) -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	# Esc OR Xbox Start (the `pause` action) opens the exit prompt. Note:
	# controller B is deliberately NOT bound here — it's only for cancelling
	# the prompt once it's open, not for opening it.
	if _is_open_request(event):
		_exit_warning.open(exit_prompt)

func _is_open_request(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return true
	if event.is_action_pressed("pause"):
		return true
	return false

func _on_exit_confirmed() -> void:
	get_tree().change_scene_to_file(menu_scene_path)

func _on_combo_completed(_total: int, _count: int) -> void:
	_update_stored_label()

func _update_stored_label() -> void:
	if _stored_label == null or _combo == null:
		return
	var totals := _combo.get_stored_totals()
	_stored_label.text = "Stored combos: %d   Total damage banked: %d" % [totals.size(), _combo.get_banked_total()]

# ---------------- Arena background ----------------

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
	var rect := Rect2(arena_center - arena_size * 0.5, arena_size)
	draw_rect(rect, wall_color, false, wall_thickness)

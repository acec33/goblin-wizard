extends Node
class_name ComboManager
## Owns combo state: spawns damage-number popups, tracks the combo timer,
## pulls all popups toward the target on combo end, and emits a signal with
## the total for downstream systems (currency, XP, HUD, audio).
##
## Drop a ComboManager node into any scene to enable the system there. It
## subscribes to the global `Events.entity_hit` bus, so entities don't need
## to know about it — they just emit when they're hit.

const DamageNumberScene := preload("res://Scenes/damage_number.tscn")

signal combo_started
signal combo_completed(total: int, count: int)

@export var combo_grace: float = 1.5
@export var pull_speed: float = 1500.0
@export var pull_offset: Vector2 = Vector2(0, -90)   # numbers land above target's head
@export var sum_float_rise: float = 110.0
@export var sum_float_duration: float = 1.4
@export var sum_color: Color = Color(1, 0.92, 0.35, 1)
## Group name the pull-target belongs to. Defaults to "player".
@export var target_group: String = "player"
## Where damage-numbers are added in the tree. If empty, uses this node's
## parent — useful so spawned numbers live as siblings of the world entities.
@export var number_parent_path: NodePath

var _active: bool = false
var _timer: float = 0.0
var _sum: int = 0
var _numbers: Array[DamageNumber] = []
var _stored_totals: Array[int] = []

var _target: Node2D
var _number_parent: Node

func _ready() -> void:
	add_to_group("combo_manager")
	_number_parent = get_node_or_null(number_parent_path) if number_parent_path != NodePath() else get_parent()
	if _number_parent == null:
		_number_parent = get_parent()
	Events.entity_hit.connect(_on_entity_hit)

func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_end_combo()

# ---------------- Public API ----------------

## Returns a copy of the running list of stored combo totals.
func get_stored_totals() -> Array[int]:
	return _stored_totals.duplicate()

## Sum of every stored combo. Convenience for HUD wiring.
func get_banked_total() -> int:
	var s := 0
	for v in _stored_totals:
		s += v
	return s

# ---------------- Internals ----------------

func _on_entity_hit(amount: int, world_pos: Vector2, push_dir: Vector2, _source: Node) -> void:
	if amount <= 0:
		return
	if not _active:
		_active = true
		combo_started.emit()
	_timer = combo_grace
	_sum += amount
	var dn := DamageNumberScene.instantiate() as DamageNumber
	_number_parent.add_child(dn)
	dn.pop(amount, world_pos, push_dir)
	_numbers.append(dn)

func _end_combo() -> void:
	_active = false
	var total := _sum
	var count := _numbers.size()
	_sum = 0
	var numbers := _numbers
	_numbers = []

	_resolve_target()
	if numbers.is_empty():
		return
	if _target == null:
		# No target — just record and clean up the popups.
		for dn in numbers:
			if is_instance_valid(dn):
				dn.queue_free()
		_record(total, count)
		return

	var pending := [numbers.size()]
	for dn in numbers:
		if not is_instance_valid(dn):
			pending[0] -= 1
			continue
		dn.pull_to(_target, pull_speed, pull_offset, func(node):
			node.queue_free()
			pending[0] -= 1
			if pending[0] <= 0:
				_show_sum_and_record(total, count)
		)
	if pending[0] <= 0:
		_show_sum_and_record(total, count)

func _show_sum_and_record(total: int, count: int) -> void:
	if _target != null and is_instance_valid(_target):
		var dn := DamageNumberScene.instantiate() as DamageNumber
		_number_parent.add_child(dn)
		dn.set_value(total)
		dn.float_above(_target, sum_float_rise, sum_float_duration, sum_color)
	_record(total, count)

func _record(total: int, count: int) -> void:
	_stored_totals.append(total)
	combo_completed.emit(total, count)

func _resolve_target() -> void:
	if is_instance_valid(_target):
		return
	var matches := get_tree().get_nodes_in_group(target_group)
	for m in matches:
		if m is Node2D:
			_target = m
			return

extends Node
## Global signal bus. Any entity that takes damage emits `entity_hit`;
## anything that wants to react (damage-number popups, combo tracking,
## screen flashes, audio, etc.) listens here. This keeps damageables
## decoupled from any particular listener — drop a ComboManager into a
## new scene and the system "turns on" with no entity-side changes.
##
## Registered as the `Events` autoload in project.godot.

signal entity_hit(amount: int, world_pos: Vector2, push_dir: Vector2, source: Node)

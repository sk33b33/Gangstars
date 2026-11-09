class_name Interactable
extends Area3D
## Something the player can interact with. Lives on physics layer 4 ("interactables").
## Owners set `prompt` and `on_interact` (a Callable returning the feedback message).

signal interacted(message: String)

const LAYER_INTERACTABLES := 1 << 3

@export var prompt: String = "Interact"
@export var radius: float = 1.2
## What this is, for gameplay systems (missions): kind "npc" / "door", target = stable id.
@export var kind: String = ""
@export var target: String = ""

var on_interact: Callable


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitoring = false
	monitorable = true
	if get_child_count() == 0:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		shape.shape = sphere
		add_child(shape)


func set_enabled(enabled: bool) -> void:
	set_deferred("monitorable", enabled)


func is_enabled() -> bool:
	return monitorable


func interact(_by: Node) -> String:
	var message := ""
	if on_interact.is_valid():
		message = str(on_interact.call())
	interacted.emit(message)
	return message

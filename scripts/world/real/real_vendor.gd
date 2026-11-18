class_name RealVendor
extends Node3D
## A person selling from a street stall or the back of the snoek bakkie: stands behind it, faces the
## street, chats while you are close, and sells through the shop menu (RealWorld.vendor_used).
## Made when a chunk is built (RealWorld.load_chunk) and freed with it. Design: design/gdd/real_world.md ("Public places").

const WAKE_DISTANCE := 40.0     # further from the camera than this the model is not animated
const NAMES := {"fruit": ["Aunty Fatima's fruit", "Mr Davids' fruit", "Aunty Sharon's fruit"], "snoek": ["Oom Gerrie's snoek"],
	"guard": ["the car guard", "Bhut' Sipho the car guard"], "conductor": ["the taxi conductor", "Bra Moegamat the conductor"]}
const LOOKS := {
	"fruit": {"dress": true, "hair_style": "doek", "face": "face_old_f", "accessories": ["apron"], "stoop": 0.15},
	"snoek": {"hair_style": "beanie", "face": "face_stubble", "accessories": ["moustache"]},
	"guard": {"hair_style": "beanie", "face": "face_stubble", "accessories": []},       # an orange hi-vis vest: see VEST
	"conductor": {"hair_style": "short", "face": "face_stubble", "accessories": []},
}
## The shirt colour of the people who are not selling anything: a car guard's hi-vis vest, a taxi conductor's bright shirt.
const VEST := {"guard": "#f28c1c", "conductor": "#2b6fb5"}

var model: Node3D
var interactable := Interactable.new()
var kind := "fruit"
var label := ""
var stock_kind := "fruit_stall"
var _talk_time := 0.0


## `at`: where they stand, `face`: the direction they look (towards the customers).
func setup(p_kind: String, at: Vector2, face: Vector2, seed_value: int, on_use: Callable) -> void:
	kind = p_kind
	stock_kind = "snoek_bakkie" if kind == "snoek" else "fruit_stall"
	var names: Array = NAMES[kind]
	label = str(names[seed_value % names.size()])
	name = "Vendor_%d_%d" % [roundi(at.x), roundi(at.y)]
	position = Vector3(at.x, 0.0, at.y)
	rotation.y = atan2(face.x, face.y)
	var shirts := [VEST[kind]] if VEST.has(kind) else ["#d6403e", "#2b6fb5", "#e0b02a", "#3f8f6a", "#c8327a"]
	var look: Dictionary = (LOOKS[kind] as Dictionary).duplicate()
	look["print"] = ["print_rose", "print_sun", "print_teal"][seed_value % 3]
	look["hair_color"] = Color("#cfcac0") if kind == "fruit" and seed_value % 2 == 0 else Color("#1d1b24")
	model = NpcBodies.model_for(name, "vendor", kind == "fruit")
	add_child(model)
	model.build(Color(shirts[seed_value % shirts.size()]), Color("#3a3d46"), Color(["#8d5a3b", "#a7754f", "#6b4430"][seed_value % 3]), Color(0, 0, 0, 0), look)
	if VEST.has(kind):   # standing about, nothing to buy
		return
	interactable.prompt = "Buy from %s" % label
	interactable.kind = "shop"
	interactable.target = name
	interactable.radius = 1.9
	interactable.on_interact = func() -> String:
		on_use.call(stock_kind, label)
		return ""
	interactable.position = Vector3(0, 1.0, 0.9)
	add_child(interactable)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(global_position) > WAKE_DISTANCE:
		return
	_talk_time = maxf(0.0, _talk_time - delta)
	var player_near := cam.global_position.distance_to(global_position) < 7.0
	model.mode = "talk" if player_near else "idle"
	model.animate(delta, 0.0)

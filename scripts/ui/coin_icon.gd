class_name CoinIcon
extends Control
## The R5 coin shown next to the player's money: a gold coin with a darker rim and "R5" on its face (drawn, no image).

const GOLD := Color("#f2c14e")
const RIM := Color("#b8862b")


func _ready() -> void:
	custom_minimum_size = Vector2(34, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := Vector2(17, 17)
	draw_circle(c, 17.0, Color(0, 0, 0, 0.55))
	draw_circle(c, 15.5, RIM)
	draw_circle(c, 13.0, GOLD)
	draw_arc(c, 10.5, 0.0, TAU, 32, Color(RIM, 0.8), 1.0)
	var font := ThemeDB.fallback_font
	var text := "R5"
	var fs := 13
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - w * 0.5, c.y + 4.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#5c3d0e"))

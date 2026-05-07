## Voltline — Stage 1 placeholder (v0.1 skeleton).
##
## Currently just shows a stub message confirming the scene transition
## works. The next story (V-002 player controller) replaces this with a
## proper level layout + player spawn + ground / wall collision.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216

const COLOR_BG: Color = Color("#1A1230")
const COLOR_GROUND: Color = Color("#3A2A50")
const COLOR_TEXT: Color = Color("#7AC8FF")


func _ready() -> void:
	Game.current_area = "stage_1"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Game.goto_level("title")
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), COLOR_BG)
	# Pretend ground for skeleton — V-002 replaces this with a real tile map.
	draw_rect(Rect2(0, 180, VIEWPORT_W, 36), COLOR_GROUND)
	# Stub label
	_label("STAGE 1 - SKELETON", 100.0, 80.0, COLOR_TEXT, 2.0)
	_label("PRESS  R  TO  RETURN", 100.0, 110.0, COLOR_TEXT, 1.5)


## Same block-letter helper as title.gd, copy-pasted to avoid wiring
## a shared text utility this early. Will move to a shared draw helper
## once we have a third user.
func _label(text: String, x: float, y: float, color: Color, scale: float) -> void:
	var letter_w: float = 5.0 * scale
	var spacing: float = 1.0 * scale
	var step: float = letter_w + spacing
	for i in text.length():
		var ch: String = text.substr(i, 1)
		if ch == " ":
			continue
		var lx: float = x + float(i) * step
		draw_rect(Rect2(lx, y, letter_w, 1.0 * scale), color)
		draw_rect(Rect2(lx, y + 6.0 * scale, letter_w, 1.0 * scale), color)
		draw_rect(Rect2(lx, y, 1.0 * scale, 7.0 * scale), color)
		draw_rect(Rect2(lx + letter_w - scale, y, 1.0 * scale, 7.0 * scale), color)

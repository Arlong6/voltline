## Voltline — placeholder title screen (v0.1 skeleton).
##
## Renders the game title + "PRESS START" prompt, transitions to stage_1
## when the player presses jump or shoot. Replaced by a proper title /
## stage-select once V-002 lands.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216

const COLOR_BG: Color = Color("#0A0D1A")
const COLOR_NEON: Color = Color("#7AC8FF")
const COLOR_NEON_DARK: Color = Color("#3A6A9A")
const COLOR_PROMPT: Color = Color("#F2F2F2")

var _t: float = 0.0


func _ready() -> void:
	Game.current_area = "title"


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("shoot"):
		Game.reset_run()
		Game.goto_level("stage_1")
		get_viewport().set_input_as_handled()


func _draw() -> void:
	# Solid backdrop so the default clear colour doesn't bleed through.
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), COLOR_BG)
	# Title text — placeholder using rectangles for the V O L T L I N E.
	# We're going to swap this for a proper logo asset in v0.2; for now,
	# a simple block-letter approximation reads at 384×216.
	var title_y: float = 70.0
	_draw_block_text("VOLTLINE", -1.0, title_y, COLOR_NEON, 4.0)
	# Subtitle / Chinese name
	_draw_block_text("DIAN GUANG", -1.0, title_y + 30.0, COLOR_NEON_DARK, 2.0)
	# Blinking prompt
	var blink: bool = sin(_t * 4.0) > 0.0
	if blink:
		_draw_block_text("PRESS  Z  TO  START", -1.0, 160.0, COLOR_PROMPT, 1.5)


## Cheap pixel-block letter renderer. Each character is drawn as a small
## rectangle so we have something to look at without a font asset.
## scale controls letter width + height; spacing scales with it.
func _draw_block_text(text: String, _ignored: float,
		y: float, color: Color, scale: float) -> void:
	var letter_w: float = 5.0 * scale
	var spacing: float = 1.0 * scale
	var step: float = letter_w + spacing
	var total_w: float = step * float(text.length()) - spacing
	var start_x: float = (VIEWPORT_W - total_w) * 0.5
	for i in text.length():
		var x: float = start_x + float(i) * step
		var ch: String = text.substr(i, 1)
		if ch == " ":
			continue
		# Draw the letter glyph as a hollow rectangle with a centre dot —
		# enough to suggest characters at this resolution.
		draw_rect(Rect2(x, y, letter_w, 1.0 * scale), color)
		draw_rect(Rect2(x, y + 6.0 * scale, letter_w, 1.0 * scale), color)
		draw_rect(Rect2(x, y, 1.0 * scale, 7.0 * scale), color)
		draw_rect(Rect2(x + letter_w - scale, y, 1.0 * scale, 7.0 * scale),
			color)
		draw_rect(Rect2(x + (letter_w - scale) * 0.5, y + 3.0 * scale,
			1.0 * scale, 1.0 * scale), color)

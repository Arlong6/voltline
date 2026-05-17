## Voltline — credits roll (v0.78).
##
## Plays after the outro cutscene. Lines scroll bottom→top at a steady
## pace; X / Z / ESC skip straight to the title. Pure procedural visuals
## to stay self-contained — no asset deps.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216

const COLOR_BG: Color = Color("#03040A")
const COLOR_SCANLINE: Color = Color(1.0, 1.0, 1.0, 0.03)
const COLOR_PRIMARY: Color = Color("#FFD24A")
const COLOR_SECONDARY: Color = Color("#A8D8FF")
const COLOR_DIVIDER: Color = Color("#3A4C70")
const COLOR_DIM: Color = Color("#7090B0")
const COLOR_PROMPT: Color = Color("#7AC8FF")

const SCROLL_SPEED: float = 22.0           # pixels per second
const SCANLINE_STEP: int = 3
const LINE_HEIGHT: float = 16.0
const TITLE_LINE_HEIGHT: float = 22.0
const DIVIDER_GAP: float = 10.0
const DIVIDER_WIDTH: float = 160.0
const DIVIDER_THICKNESS: float = 1.0
const PRIMARY_FONT_SIZE: int = 14
const SECONDARY_FONT_SIZE: int = 10
const DIM_FONT_SIZE: int = 9
const PROMPT_FONT_SIZE: int = 9
const PROMPT_Y_FROM_BOTTOM: float = 12.0
const END_PADDING_LINES: float = 4.0

const TITLE_LEVEL_KEY: String = "title"
const SKIP_ACTIONS: Array[String] = ["jump", "dash", "ui_cancel"]
const PROMPT_TEXT: String = "X / Z / ESC   SKIP"

# Each entry: [kind, text]. Kind decides font + colour:
#   "title"     — large gold (14)
#   "body"      — light blue (10)
#   "dim"       — small grey (9)
#   "divider"   — short horizontal line, no text
#   "spacer"    — blank gap, no text
const CREDITS: Array[Array] = [
	["title",   "VOLTLINE"],
	["body",    "A weekend-scale Mega Man tribute"],
	["spacer",  ""],
	["divider", ""],
	["spacer",  ""],
	["body",    "DESIGN & CODE"],
	["dim",     "arlong"],
	["dim",     "Codex CLI"],
	["spacer",  ""],
	["body",    "DIRECTION"],
	["dim",     "Claude Code Game Studios"],
	["spacer",  ""],
	["body",    "ENGINE"],
	["dim",     "Godot 4.6"],
	["dim",     "GDScript + GUT"],
	["spacer",  ""],
	["divider", ""],
	["spacer",  ""],
	["body",    "BOSSES"],
	["dim",     "R-08 · OMEGA-X"],
	["dim",     "TYRANT-Z · TYRANT-Z²"],
	["dim",     "GRID-0 · VEIN-K"],
	["dim",     "AXIS-Ω"],
	["spacer",  ""],
	["body",    "THE PROCESS THAT REMAINED"],
	["spacer",  ""],
	["divider", ""],
	["spacer",  ""],
	["dim",     "297+ tests passing"],
	["dim",     "zero assets, all procedural"],
	["spacer",  ""],
	["divider", ""],
	["spacer",  ""],
	["body",    "To all the late-night builds"],
	["body",    "and the friends who played it."],
	["spacer",  ""],
	["spacer",  ""],
	["title",   "// END OF LINE"],
]

var _scroll_y: float = float(VIEWPORT_H)
var _total_height: float = 0.0
var _finished: bool = false


func _ready() -> void:
	Music.play("title")
	_total_height = _compute_total_height()
	queue_redraw()


func _process(delta: float) -> void:
	if _finished:
		return
	_scroll_y -= SCROLL_SPEED * delta
	if _scroll_y + _total_height + float(VIEWPORT_H) * END_PADDING_LINES * 0.05 < 0.0:
		_finished = true
		Game.goto_level(TITLE_LEVEL_KEY)
		return
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	for action_name in SKIP_ACTIONS:
		if event.is_action_pressed(action_name):
			get_viewport().set_input_as_handled()
			_finished = true
			Game.goto_level(TITLE_LEVEL_KEY)
			return


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, float(VIEWPORT_W), float(VIEWPORT_H)), COLOR_BG)
	var y: int = 0
	while y < VIEWPORT_H:
		draw_line(Vector2(0.0, float(y)), Vector2(float(VIEWPORT_W), float(y)),
			COLOR_SCANLINE, 1.0)
		y += SCANLINE_STEP

	var font: Font = ThemeDB.fallback_font
	var cursor_y: float = _scroll_y
	for entry in CREDITS:
		var kind: String = String(entry[0])
		var text: String = String(entry[1])
		match kind:
			"title":
				if cursor_y > -TITLE_LINE_HEIGHT and cursor_y < float(VIEWPORT_H):
					_draw_centered(font, text, cursor_y,
						PRIMARY_FONT_SIZE, COLOR_PRIMARY)
				cursor_y += TITLE_LINE_HEIGHT
			"body":
				if cursor_y > -LINE_HEIGHT and cursor_y < float(VIEWPORT_H):
					_draw_centered(font, text, cursor_y,
						SECONDARY_FONT_SIZE, COLOR_SECONDARY)
				cursor_y += LINE_HEIGHT
			"dim":
				if cursor_y > -LINE_HEIGHT and cursor_y < float(VIEWPORT_H):
					_draw_centered(font, text, cursor_y,
						DIM_FONT_SIZE, COLOR_DIM)
				cursor_y += LINE_HEIGHT
			"divider":
				if cursor_y > -DIVIDER_GAP and cursor_y < float(VIEWPORT_H):
					var div_x: float = (float(VIEWPORT_W) - DIVIDER_WIDTH) * 0.5
					draw_rect(Rect2(div_x, cursor_y + DIVIDER_GAP * 0.5,
						DIVIDER_WIDTH, DIVIDER_THICKNESS), COLOR_DIVIDER)
				cursor_y += DIVIDER_GAP
			"spacer":
				cursor_y += DIVIDER_GAP

	_draw_centered(font, PROMPT_TEXT,
		float(VIEWPORT_H) - PROMPT_Y_FROM_BOTTOM,
		PROMPT_FONT_SIZE, COLOR_PROMPT)


func _compute_total_height() -> float:
	var h: float = 0.0
	for entry in CREDITS:
		match String(entry[0]):
			"title":   h += TITLE_LINE_HEIGHT
			"body":    h += LINE_HEIGHT
			"dim":     h += LINE_HEIGHT
			"divider": h += DIVIDER_GAP
			"spacer":  h += DIVIDER_GAP
	return h


func _draw_centered(font: Font, text: String, y: float, size: int, color: Color) -> void:
	if text == "":
		return
	var width: float = font.get_string_size(text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = (float(VIEWPORT_W) - width) * 0.5
	draw_string(font, Vector2(x, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

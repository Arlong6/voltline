## Voltline — how-to-play / controls reference screen (v0.77).
##
## Static page accessible from the title via key 7. Two stacked sections:
## controls table on top, gameplay tips below. ESC / X / Z returns to title.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216

const COLOR_BG: Color = Color("#06080F")
const COLOR_SCANLINE: Color = Color(1.0, 1.0, 1.0, 0.03)
const COLOR_TITLE: Color = Color("#FFD24A")
const COLOR_SECTION: Color = Color("#7AC8FF")
const COLOR_DIVIDER: Color = Color("#1A2438")
const COLOR_KEY: Color = Color("#FFD24A")
const COLOR_LABEL: Color = Color("#E0E8F0")
const COLOR_NOTE: Color = Color("#8AA0BA")
const COLOR_TIP: Color = Color("#C0D8F0")
const COLOR_PROMPT: Color = Color("#7AC8FF")

const TITLE_TEXT: String = "VOLTLINE — HOW TO PLAY"
const SECTION_CONTROLS_TEXT: String = "CONTROLS"
const SECTION_GAMEPLAY_TEXT: String = "GAMEPLAY"
const PROMPT_TEXT: String = "X / Z / ESC   BACK"

const TITLE_FONT_SIZE: int = 14
const SECTION_FONT_SIZE: int = 10
const KEY_FONT_SIZE: int = 9
const LABEL_FONT_SIZE: int = 9
const NOTE_FONT_SIZE: int = 8
const TIP_FONT_SIZE: int = 9
const PROMPT_FONT_SIZE: int = 9

const SCANLINE_STEP: int = 3
const TITLE_Y: float = 14.0
const TITLE_DIVIDER_Y: float = 26.0
const CONTROLS_SECTION_Y: float = 36.0
const CONTROLS_ROW_START_Y: float = 52.0
const CONTROLS_ROW_HEIGHT: float = 11.0
const GAMEPLAY_DIVIDER_Y: float = 156.0
const GAMEPLAY_SECTION_Y: float = 164.0
const TIP_START_Y: float = 176.0
const TIP_HEIGHT: float = 10.0
const PROMPT_DIVIDER_Y: float = 200.0
const PROMPT_Y: float = 208.0

const COL_LABEL_X: float = 32.0
const COL_KEY_X: float = 152.0
const COL_NOTE_X: float = 228.0
const DIVIDER_MARGIN_X: float = 24.0
const DIVIDER_HEIGHT: float = 1.0

const TITLE_LEVEL_KEY: String = "title"
const BACK_ACTIONS: Array[String] = ["jump", "dash", "ui_cancel"]

# Each entry is [label, key_combo, note]. Aligned with consistent columns.
const CONTROL_ROWS: Array[Array] = [
	["Move",          "ARROWS  /  WASD",  ""],
	["Jump",          "X",             "hold for higher jump"],
	["Shoot",         "C",             "hold to charge Lv1 / Lv2"],
	["Dash",          "Z",             ""],
	["Slide / Dive",  "Z + DOWN",      "ground / air"],
	["Wall jump",     "X",             "against a wall"],
	["Sub-weapon",    "SHIFT",         ""],
	["Cycle sub",     "Q",             ""],
	["Pause / Restart", "ESC  /  R",   ""],
]

const GAMEPLAY_TIPS: Array[String] = [
	"Clear 10 sectors in STORY MODE to restore the system.",
	"Hidden walls break with a Lv2 super shot.",
	"NG+ Hard Mode unlocks after the final boss.",
]


func _ready() -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	for action_name in BACK_ACTIONS:
		if event.is_action_pressed(action_name):
			get_viewport().set_input_as_handled()
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

	_draw_centered(font, TITLE_TEXT, TITLE_Y, TITLE_FONT_SIZE, COLOR_TITLE)
	_draw_divider(TITLE_DIVIDER_Y)

	draw_string(font, Vector2(COL_LABEL_X, CONTROLS_SECTION_Y),
		SECTION_CONTROLS_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, SECTION_FONT_SIZE, COLOR_SECTION)
	for i in CONTROL_ROWS.size():
		var row: Array = CONTROL_ROWS[i]
		var row_y: float = CONTROLS_ROW_START_Y + float(i) * CONTROLS_ROW_HEIGHT
		draw_string(font, Vector2(COL_LABEL_X, row_y), String(row[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, COLOR_LABEL)
		draw_string(font, Vector2(COL_KEY_X, row_y), String(row[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_FONT_SIZE, COLOR_KEY)
		var note: String = String(row[2])
		if note != "":
			draw_string(font, Vector2(COL_NOTE_X, row_y), note,
				HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_FONT_SIZE, COLOR_NOTE)

	_draw_divider(GAMEPLAY_DIVIDER_Y)
	draw_string(font, Vector2(COL_LABEL_X, GAMEPLAY_SECTION_Y),
		SECTION_GAMEPLAY_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, SECTION_FONT_SIZE, COLOR_SECTION)
	for i in GAMEPLAY_TIPS.size():
		var tip_y: float = TIP_START_Y + float(i) * TIP_HEIGHT
		draw_string(font, Vector2(COL_LABEL_X, tip_y), GAMEPLAY_TIPS[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, TIP_FONT_SIZE, COLOR_TIP)

	_draw_divider(PROMPT_DIVIDER_Y)
	_draw_centered(font, PROMPT_TEXT, PROMPT_Y, PROMPT_FONT_SIZE, COLOR_PROMPT)


func _draw_divider(y: float) -> void:
	draw_rect(
		Rect2(DIVIDER_MARGIN_X, y, float(VIEWPORT_W) - DIVIDER_MARGIN_X * 2.0,
			DIVIDER_HEIGHT),
		COLOR_DIVIDER,
	)


func _draw_centered(font: Font, text: String, y: float, size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = (float(VIEWPORT_W) - width) * 0.5
	draw_string(font, Vector2(x, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

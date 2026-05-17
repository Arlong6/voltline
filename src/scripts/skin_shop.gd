## Voltline — NIX Skin Shop (v0.72).
##
## Routed to from the base hub after NIX dialogue. Shows the four player
## skins with their cost / ownership state and lets the player switch or
## buy with the 1-4 number keys. X / Z / ESC returns to the base hub.
##
## Re-uses Game.SKIN_COLORS / SKIN_NAMES / SKIN_COSTS / skin_index /
## is_skin_owned / select_skin and adds a `buy_skin(idx)` purchase path
## that mirrors title.gd's try_advance_skin but targets a specific slot.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216

const COLOR_BG: Color = Color("#06080F")
const COLOR_SCANLINE: Color = Color(1.0, 1.0, 1.0, 0.03)
const COLOR_FRAME_ACTIVE: Color = Color("#FFD24A")
const COLOR_FRAME_OWNED: Color = Color("#5A7A9A")
const COLOR_FRAME_LOCKED: Color = Color("#2A3F60")
const COLOR_TITLE: Color = Color("#FFD24A")
const COLOR_LABEL: Color = Color("#A8D8FF")
const COLOR_COIN: Color = Color("#FFD24A")
const COLOR_PROMPT: Color = Color("#7AC8FF")
const COLOR_STATUS_OWNED: Color = Color("#80E0A0")
const COLOR_STATUS_ACTIVE: Color = Color("#FFD24A")
const COLOR_STATUS_AFFORD: Color = Color("#A8D8FF")
const COLOR_STATUS_BROKE: Color = Color("#806060")

const TITLE_TEXT: String = "// NIX TECH BAY"
const SUBTITLE_TEXT: String = "SKIN SELECTION"
const PROMPT_TEXT: String = "1-4 SELECT/BUY     X/Z/ESC BACK"

const TITLE_FONT_SIZE: int = 14
const SUBTITLE_FONT_SIZE: int = 10
const COIN_FONT_SIZE: int = 11
const ROW_FONT_SIZE: int = 11
const STATUS_FONT_SIZE: int = 10
const PROMPT_FONT_SIZE: int = 9
const TOAST_FONT_SIZE: int = 11

const TITLE_Y: float = 22.0
const SUBTITLE_Y: float = 38.0
const COIN_Y: float = 56.0
const ROW_START_Y: float = 86.0
const ROW_HEIGHT: float = 24.0
const ROW_X: float = 60.0
const SWATCH_OFFSET: Vector2 = Vector2(0.0, -10.0)
const SWATCH_SIZE: Vector2 = Vector2(20.0, 16.0)
const NAME_OFFSET_X: float = 32.0
const STATUS_OFFSET_X: float = 130.0
const PROMPT_Y: float = 198.0
const TOAST_Y: float = 178.0
const TOAST_DURATION: float = 1.4
const SCANLINE_STEP: int = 3

const BASE_LEVEL_KEY: String = "base"
const ACTION_BACK_KEY_BINDS: Array[String] = ["jump", "dash", "ui_cancel"]
const NUMBER_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4]

var _toast_text: String = ""
var _toast_age: float = 0.0


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	if _toast_age > 0.0:
		_toast_age = maxf(_toast_age - delta, 0.0)
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		var idx: int = NUMBER_KEYS.find(key)
		if idx >= 0:
			get_viewport().set_input_as_handled()
			_handle_slot(idx)
			return
	for action_name in ACTION_BACK_KEY_BINDS:
		if event.is_action_pressed(action_name):
			get_viewport().set_input_as_handled()
			Game.goto_level(BASE_LEVEL_KEY)
			return


## Tries to switch to or buy skin index `idx`. Shows a brief toast describing
## the action taken so the player has feedback for an otherwise-silent button.
func _handle_slot(idx: int) -> void:
	if idx < 0 or idx >= Game.SKIN_COLORS.size():
		return
	var name: String = Game.SKIN_NAMES[idx]
	if Game.is_skin_owned(idx):
		if Game.skin_index == idx:
			_set_toast("%s — already active" % name)
		else:
			Game.select_skin(idx)
			_set_toast("Switched to %s" % name)
			Sfx.play("coin")
		queue_redraw()
		return
	var cost: int = Game.SKIN_COSTS[idx]
	if Game.coins < cost:
		_set_toast("Need %d coin (have %d)" % [cost, Game.coins])
		queue_redraw()
		return
	Game.coins -= cost
	Game.skin_owned[idx] = true
	Game.skin_index = idx
	Game.save_to_file()
	_set_toast("Bought %s for %d coin" % [name, cost])
	Sfx.play("coin")
	queue_redraw()


func _set_toast(text: String) -> void:
	_toast_text = text
	_toast_age = TOAST_DURATION


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, float(VIEWPORT_W), float(VIEWPORT_H)), COLOR_BG)
	var y: int = 0
	while y < VIEWPORT_H:
		draw_line(Vector2(0.0, float(y)), Vector2(float(VIEWPORT_W), float(y)), COLOR_SCANLINE, 1.0)
		y += SCANLINE_STEP
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(16.0, TITLE_Y), TITLE_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE, COLOR_TITLE)
	draw_string(font, Vector2(16.0, SUBTITLE_Y), SUBTITLE_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, SUBTITLE_FONT_SIZE, COLOR_LABEL)
	draw_string(font, Vector2(16.0, COIN_Y), "COIN  %d" % Game.coins,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COIN_FONT_SIZE, COLOR_COIN)
	for i in Game.SKIN_COLORS.size():
		_draw_row(font, i)
	draw_string(font, Vector2(16.0, PROMPT_Y), PROMPT_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, PROMPT_FONT_SIZE, COLOR_PROMPT)
	if _toast_age > 0.0:
		draw_string(font, Vector2(16.0, TOAST_Y), _toast_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT_SIZE, COLOR_STATUS_AFFORD)


func _draw_row(font: Font, idx: int) -> void:
	var y: float = ROW_START_Y + float(idx) * ROW_HEIGHT
	var swatch_color: Color = Game.SKIN_COLORS[idx]
	var swatch_rect: Rect2 = Rect2(ROW_X + SWATCH_OFFSET.x, y + SWATCH_OFFSET.y,
		SWATCH_SIZE.x, SWATCH_SIZE.y)
	var frame_color: Color = COLOR_FRAME_LOCKED
	if Game.skin_index == idx:
		frame_color = COLOR_FRAME_ACTIVE
	elif Game.is_skin_owned(idx):
		frame_color = COLOR_FRAME_OWNED
	draw_rect(swatch_rect.grow(2.0), frame_color)
	draw_rect(swatch_rect, swatch_color)
	var label_text: String = "[%d] %s" % [idx + 1, Game.SKIN_NAMES[idx]]
	draw_string(font, Vector2(ROW_X + NAME_OFFSET_X, y),
		label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FONT_SIZE, COLOR_LABEL)
	var status_text: String
	var status_color: Color
	if Game.skin_index == idx:
		status_text = "ACTIVE"
		status_color = COLOR_STATUS_ACTIVE
	elif Game.is_skin_owned(idx):
		status_text = "OWNED"
		status_color = COLOR_STATUS_OWNED
	else:
		var cost: int = Game.SKIN_COSTS[idx]
		status_text = "%d COIN" % cost
		status_color = COLOR_STATUS_AFFORD if Game.coins >= cost else COLOR_STATUS_BROKE
	draw_string(font, Vector2(ROW_X + STATUS_OFFSET_X, y),
		status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE, status_color)

## Voltline — typewriter cutscene scene (v0.57).
##
## Reads `Game.cutscene_title`, `Game.cutscene_lines`, and
## `Game.cutscene_next` on _ready, then plays the lines through a
## char-by-char typewriter. X (jump) advances:
##   - mid-typing: snap-complete the current line
##   - line complete: advance to the next line
##   - last line complete: fade out and goto Game.cutscene_next
##
## Background is the same dark slab as the title with a faint scanline
## overlay so it reads as "comms terminal."
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216

const COLOR_BG: Color = Color("#06080F")
const COLOR_SCANLINE: Color = Color(1.0, 1.0, 1.0, 0.03)
const COLOR_TITLE: Color = Color("#FFD24A")
const COLOR_TEXT: Color = Color("#A8D8FF")
const COLOR_PROMPT: Color = Color("#7AC8FF")
const COLOR_FRAME: Color = Color("#1A2438")

const TITLE_FONT_SIZE: int = 14
const TEXT_FONT_SIZE: int = 11
const PROMPT_FONT_SIZE: int = 9

# Characters per second for the typewriter effect.
const TYPE_RATE: float = 32.0

# Char interval at which we play the text-blip SFX (so it isn't deafening).
const BLIP_EVERY: int = 3

const FADE_IN_DURATION: float = 0.6
const FADE_OUT_DURATION: float = 0.8

const PROMPT_TEXT: String = "X TO CONTINUE"

var _title: String = ""
var _lines: PackedStringArray = PackedStringArray()
var _next: String = "title"

var _line_index: int = 0
var _typed_chars: int = 0
var _type_timer: float = 0.0
var _blip_counter: int = 0
var _t: float = 0.0
var _transitioning: bool = false

var _hud_layer: CanvasLayer
var _fade_rect: ColorRect


func _ready() -> void:
	Game.current_area = "cutscene"
	Music.play("title")  # cutscenes share the calm title theme
	_title = Game.cutscene_title
	_lines = Game.cutscene_lines
	_next = Game.cutscene_next
	_build_fade_overlay()


func _process(delta: float) -> void:
	_t += delta
	if _line_index >= _lines.size():
		queue_redraw()
		return
	var current: String = _lines[_line_index]
	if _typed_chars < current.length():
		_type_timer += delta
		var next_count: int = mini(int(_type_timer * TYPE_RATE), current.length())
		while _typed_chars < next_count:
			_typed_chars += 1
			_blip_counter += 1
			if _blip_counter >= BLIP_EVERY:
				_blip_counter = 0
				Sfx.play("text_blip")
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("shoot"):
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	if _line_index >= _lines.size():
		_fade_out_and_continue()
		return
	var current: String = _lines[_line_index]
	if _typed_chars < current.length():
		# Snap-complete the current line on the first press.
		_typed_chars = current.length()
		_type_timer = float(_typed_chars) / TYPE_RATE
		return
	# Line is complete — advance to the next or wrap.
	_line_index += 1
	_typed_chars = 0
	_type_timer = 0.0
	if _line_index >= _lines.size():
		_fade_out_and_continue()


func _fade_out_and_continue() -> void:
	if _transitioning:
		return
	_transitioning = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(func() -> void:
		if is_inside_tree():
			Game.goto_level(_next)
	)


func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), COLOR_BG)
	# Faint scanlines.
	for y in range(0, VIEWPORT_H, 2):
		draw_line(Vector2(0.0, float(y)), Vector2(float(VIEWPORT_W), float(y)),
			COLOR_SCANLINE, 1.0)
	# Frame around the dialogue area.
	var frame: Rect2 = Rect2(20.0, 60.0, float(VIEWPORT_W) - 40.0, 110.0)
	draw_rect(frame, COLOR_FRAME, false, 1.0)

	var font: Font = ThemeDB.fallback_font
	# Title bar.
	if _title != "":
		var title_size: Vector2 = font.get_string_size(
			_title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE
		)
		draw_string(
			font, Vector2((float(VIEWPORT_W) - title_size.x) * 0.5, 40.0),
			_title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE, COLOR_TITLE
		)
	# Lines so far + the partially-typed current line.
	var y_offset: float = 80.0
	for i in range(_line_index):
		_draw_line(font, _lines[i], y_offset)
		y_offset += 16.0
	if _line_index < _lines.size():
		var current: String = _lines[_line_index]
		var visible: String = current.substr(0, _typed_chars)
		_draw_line(font, visible, y_offset)
	# Continue prompt — only after the current line finishes typing.
	if _line_index < _lines.size():
		var current_line: String = _lines[_line_index]
		if _typed_chars >= current_line.length():
			_draw_prompt(font)
	else:
		_draw_prompt(font)


func _draw_line(font: Font, text: String, y: float) -> void:
	draw_string(
		font, Vector2(34.0, y),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_FONT_SIZE, COLOR_TEXT
	)


func _draw_prompt(font: Font) -> void:
	var blink: bool = sin(_t * 5.0) > 0.0
	if not blink:
		return
	var prompt_size: Vector2 = font.get_string_size(
		PROMPT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, PROMPT_FONT_SIZE
	)
	draw_string(
		font, Vector2(float(VIEWPORT_W) - prompt_size.x - 30.0, 162.0),
		PROMPT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, PROMPT_FONT_SIZE, COLOR_PROMPT
	)


func _build_fade_overlay() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_fade_rect)
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_DURATION)

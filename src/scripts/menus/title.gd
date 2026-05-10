## Voltline — title screen.
##
## Renders the game title, story-flavour subtitle, persistent-coin shop,
## and a blinking "press start" prompt. After a stage_4 clear
## (Game.game_cleared = true) the prompt swaps for a celebratory
## "GAME CLEAR" line. Loads persistent state on entry; saves on every
## upgrade purchase. Fades in/out for scene transitions.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216

const COLOR_BG: Color = Color("#0A0D1A")
const COLOR_NEON: Color = Color("#7AC8FF")
const COLOR_NEON_DARK: Color = Color("#3A6A9A")
const COLOR_PROMPT: Color = Color("#F2F2F2")
const COLOR_CLEAR: Color = Color("#FFD24A")
const COLOR_FLAVOR: Color = Color("#A0C8E0")
const COLOR_GOLD: Color = Color("#FFD24A")
const COLOR_SHOP_OK: Color = Color("#A0C8E0")
const COLOR_SHOP_DIM: Color = Color("#5A6A82")
const COLOR_SHOP_MAXED: Color = Color("#43D27A")

const TITLE_TEXT: String = "VOLTLINE"
const SUBTITLE_TEXT: String = "DIAN GUANG"
const PROMPT_TEXT: String = "PRESS X TO START"
const CLEAR_TEXT: String = "GAME CLEAR  -  4: STAGE INFINITY"
const TRUE_CLEAR_TEXT: String = "TRUE CLEAR  -  5: BOSS RUSH"
const RUSH_CLEAR_TEXT: String = "RUSH CLEAR  -  PRESS X"

const STORY_LINES: Array[String] = [
	"21XX. THE OUTER GRID HAS FALLEN.",
	"VOLTLINE PROTOCOL BURNS THE LAST",
	"COMBAT UNIT THROUGH FOUR SECTORS",
	"TO REACH THE CORE: TYRANT-Z.",
]
const CONTROLS_LINE: String = "ARROWS/WASD MOVE   X JUMP   C SHOOT   Z DASH"

const TITLE_FONT_SIZE: int = 36
const SUBTITLE_FONT_SIZE: int = 14
const STORY_FONT_SIZE: int = 9
const SHOP_FONT_SIZE: int = 9
const PROMPT_FONT_SIZE: int = 12

# Shop tuning — costs and per-slot maximums.
const SHOP_HP_COST: int = 8
const SHOP_HP_MAX: int = 3
const SHOP_DASH_COST: int = 10
const SHOP_DASH_MAX: int = 2
const SHOP_SHOOT_COST: int = 12
const SHOP_SHOOT_MAX: int = 2

const FADE_IN_DURATION: float = 0.5
const FADE_OUT_DURATION: float = 0.5

var _t: float = 0.0
var _fade_rect: ColorRect
var _transitioning: bool = false


func _ready() -> void:
	Game.current_area = "title"
	# Pull persistent state in from disk every time the title screen
	# loads — covers the cold-boot case and the "press R to return"
	# round-trip so the shop UI always shows fresh values.
	Game.load_from_file()
	_build_fade_overlay()
	Music.play("title")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	# Number keys trigger shop slots. Handle these BEFORE the start
	# action so pressing 1/2/3 doesn't accidentally enter a stage.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_try_buy(0)
				return
			KEY_2:
				_try_buy(1)
				return
			KEY_3:
				_try_buy(2)
				return
			KEY_4:
				# Stage 5 (// VOLTLINE INFINITY) unlocks after the
				# first game clear. Silent no-op if not yet unlocked.
				if Game.game_cleared:
					get_viewport().set_input_as_handled()
					_transitioning = true
					Game.reset_run()
					_fade_out_then_goto("stage_5")
				return
			KEY_5:
				# Boss Rush unlocks after the true clear. Silent no-op
				# if Stage 5 hasn't been beaten yet.
				if Game.true_cleared:
					get_viewport().set_input_as_handled()
					_transitioning = true
					Game.reset_run()
					_fade_out_then_goto("boss_rush")
				return
	if event.is_action_pressed("jump") or event.is_action_pressed("shoot"):
		get_viewport().set_input_as_handled()
		_transitioning = true
		Game.reset_run()
		# Fresh runs play the intro cutscene before stage_1; returning
		# players who have already beaten the game can skip straight in.
		if Game.game_cleared:
			_fade_out_then_goto("stage_1")
		else:
			_fade_out_then_play_intro()


# Attempts to purchase upgrade slot 0/1/2. No-op if maxed or short on coins.
func _try_buy(slot: int) -> void:
	var cost: int
	var current: int
	var maxval: int
	match slot:
		0:
			cost = SHOP_HP_COST
			current = Game.upgrade_hp_count
			maxval = SHOP_HP_MAX
		1:
			cost = SHOP_DASH_COST
			current = Game.upgrade_dash_count
			maxval = SHOP_DASH_MAX
		2:
			cost = SHOP_SHOOT_COST
			current = Game.upgrade_shoot_count
			maxval = SHOP_SHOOT_MAX
		_:
			return

	if current >= maxval:
		return
	if Game.coins < cost:
		return

	Game.coins -= cost
	match slot:
		0: Game.upgrade_hp_count += 1
		1: Game.upgrade_dash_count += 1
		2: Game.upgrade_shoot_count += 1
	Game.save_to_file()
	Sfx.play("coin_pickup")


func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), COLOR_BG)
	var font: Font = ThemeDB.fallback_font

	_draw_centered(font, TITLE_TEXT, 36.0, TITLE_FONT_SIZE, COLOR_NEON)
	_draw_centered(font, SUBTITLE_TEXT, 60.0, SUBTITLE_FONT_SIZE, COLOR_NEON_DARK)

	var story_y: float = 80.0
	for line in STORY_LINES:
		_draw_centered(font, line, story_y, STORY_FONT_SIZE, COLOR_FLAVOR)
		story_y += 11.0

	# Coin balance + shop slots.
	_draw_centered(
		font, "COINS  x %d" % Game.coins, 124.0, SHOP_FONT_SIZE, COLOR_GOLD
	)
	_draw_shop_line(font, 138.0, "1", "HP UP",
		SHOP_HP_COST, Game.upgrade_hp_count, SHOP_HP_MAX)
	_draw_shop_line(font, 149.0, "2", "DASH UP",
		SHOP_DASH_COST, Game.upgrade_dash_count, SHOP_DASH_MAX)
	_draw_shop_line(font, 160.0, "3", "FIRE UP",
		SHOP_SHOOT_COST, Game.upgrade_shoot_count, SHOP_SHOOT_MAX)

	_draw_centered(font, CONTROLS_LINE, 178.0, STORY_FONT_SIZE, COLOR_NEON_DARK)

	var blink: bool = sin(_t * 4.0) > 0.0
	if blink:
		if Game.boss_rush_cleared:
			_draw_centered(font, RUSH_CLEAR_TEXT, 200.0, PROMPT_FONT_SIZE, COLOR_CLEAR)
		elif Game.true_cleared:
			_draw_centered(font, TRUE_CLEAR_TEXT, 200.0, PROMPT_FONT_SIZE, COLOR_CLEAR)
		elif Game.game_cleared:
			_draw_centered(font, CLEAR_TEXT, 200.0, PROMPT_FONT_SIZE, COLOR_CLEAR)
		else:
			_draw_centered(font, PROMPT_TEXT, 200.0, PROMPT_FONT_SIZE, COLOR_PROMPT)


# Renders one shop slot row. Greys out the price label when the player
# can't afford it; switches to a green "MAX" tag when fully purchased.
func _draw_shop_line(font: Font, y: float, key: String, name: String,
		cost: int, current: int, maxval: int) -> void:
	var status: String
	var color: Color
	if current >= maxval:
		status = "MAX"
		color = COLOR_SHOP_MAXED
	else:
		status = "%d coins" % cost
		color = COLOR_SHOP_OK if Game.coins >= cost else COLOR_SHOP_DIM
	var text: String = "[%s]  %s   LV %d/%d   %s" % [
		key, name, current, maxval, status
	]
	_draw_centered(font, text, y, SHOP_FONT_SIZE, color)


# Centres a single line of text horizontally inside the viewport at the
# supplied baseline y.
func _draw_centered(font: Font, text: String, baseline_y: float,
		font_size: int, color: Color) -> void:
	var width: float = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	var x: float = (float(VIEWPORT_W) - width) * 0.5
	draw_string(
		font, Vector2(x, baseline_y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
	)


# Builds the screen-fixed black ColorRect used for fade transitions.
func _build_fade_overlay() -> void:
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(_fade_rect)

	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_DURATION)


func _fade_out_then_goto(level_key: String) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(func() -> void:
		if is_inside_tree():
			Game.goto_level(level_key)
	)


func _fade_out_then_play_intro() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(func() -> void:
		if not is_inside_tree():
			return
		Game.play_cutscene(
			"// VOLTLINE PROTOCOL — 21XX",
			PackedStringArray([
				"THE OUTER GRID HAS FALLEN.",
				"YOU ARE THE LAST COMBAT UNIT.",
				"BURN THROUGH FOUR SECTORS.",
				"REACH THE CORE. END THE GREY.",
			]),
			"stage_1"
		)
	)

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
const RUSH_CLEAR_TEXT: String = "RUSH CLEAR  -  6: THE ARCHITECT"
const ARCHITECT_TEXT: String = "ARCHITECT FELL  -  7: LABYRINTH"
const LABYRINTH_TEXT: String = "LABYRINTH MAPPED  -  PRESS X"

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

# Title is paged. TAB rotates between MAIN → STAGES → ACHIEVEMENTS → MAIN.
const PAGE_MAIN: int = 0
const PAGE_STAGES: int = 1
const PAGE_ACHIEVEMENTS: int = 2
const _PAGE_COUNT: int = 3

# Stage-select rows. (key, display name).
const STAGE_LIST: Array = [
	["stage_1",   "1 // JUNKYARD"],
	["stage_2",   "2 // SUBLEVEL"],
	["stage_3",   "3 // SKYBRIDGE"],
	["stage_4",   "4 // CORE"],
	["stage_5",   "5 // INFINITY"],
	["boss_rush", "B // BOSS RUSH"],
	["stage_6",   "6 // ARCHITECT"],
	["stage_7",   "7 // LABYRINTH"],
]

var _t: float = 0.0
var _fade_rect: ColorRect
var _transitioning: bool = false
var _page: int = PAGE_MAIN
var _stage_cursor: int = 0


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
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	# TAB rotates through MAIN → STAGES → ACHIEVEMENTS → MAIN.
	if event.physical_keycode == KEY_TAB:
		_page = (_page + 1) % _PAGE_COUNT
		_stage_cursor = 0
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	match _page:
		PAGE_MAIN:
			_handle_main_input(event)
		PAGE_STAGES:
			_handle_stage_select_input(event)
		# Achievements page is read-only — no input handlers needed
		# beyond TAB cycling away.


func _handle_main_input(event: InputEventKey) -> void:
	# Number keys trigger shop slots. Handle these BEFORE the start
	# action so pressing 1/2/3 doesn't accidentally enter a stage.
	match event.physical_keycode:
		KEY_1:
			_try_buy(0)
			return
		KEY_2:
			_try_buy(1)
			return
		KEY_3:
			_try_buy(2)
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


func _handle_stage_select_input(event: InputEventKey) -> void:
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_stage_cursor = (_stage_cursor - 1 + STAGE_LIST.size()) % STAGE_LIST.size()
			queue_redraw()
			return
		KEY_DOWN, KEY_S:
			_stage_cursor = (_stage_cursor + 1) % STAGE_LIST.size()
			queue_redraw()
			return
	if event.is_action_pressed("jump") or event.is_action_pressed("shoot"):
		var entry: Array = STAGE_LIST[_stage_cursor]
		var key: String = String(entry[0])
		if not Game.is_stage_unlocked(key):
			# Locked — play a soft buzz and stay put.
			Sfx.play("enemy_hit")
			return
		get_viewport().set_input_as_handled()
		_transitioning = true
		Game.reset_run()
		_fade_out_then_goto(key)


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
	match _page:
		PAGE_STAGES:        _draw_stage_select(font)
		PAGE_ACHIEVEMENTS:  _draw_achievements(font)
		_:                  _draw_main(font)
	# TAB hint always visible — labels the next page so the player can
	# discover the rotation.
	var hint: String
	match _page:
		PAGE_MAIN:         hint = "TAB: STAGE SELECT"
		PAGE_STAGES:       hint = "TAB: ACHIEVEMENTS"
		PAGE_ACHIEVEMENTS: hint = "TAB: BACK"
		_:                 hint = ""
	_draw_centered(font, hint, 188.0, STORY_FONT_SIZE, COLOR_NEON_DARK)


func _draw_main(font: Font) -> void:
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

	_draw_centered(font, CONTROLS_LINE, 174.0, STORY_FONT_SIZE, COLOR_NEON_DARK)

	var blink: bool = sin(_t * 4.0) > 0.0
	if blink:
		if Game.labyrinth_cleared:
			_draw_centered(font, LABYRINTH_TEXT, 200.0, PROMPT_FONT_SIZE, COLOR_CLEAR)
		elif Game.architect_cleared:
			_draw_centered(font, ARCHITECT_TEXT, 200.0, PROMPT_FONT_SIZE, COLOR_CLEAR)
		elif Game.boss_rush_cleared:
			_draw_centered(font, RUSH_CLEAR_TEXT, 200.0, PROMPT_FONT_SIZE, COLOR_CLEAR)
		elif Game.true_cleared:
			_draw_centered(font, TRUE_CLEAR_TEXT, 200.0, PROMPT_FONT_SIZE, COLOR_CLEAR)
		elif Game.game_cleared:
			_draw_centered(font, CLEAR_TEXT, 200.0, PROMPT_FONT_SIZE, COLOR_CLEAR)
		else:
			_draw_centered(font, PROMPT_TEXT, 200.0, PROMPT_FONT_SIZE, COLOR_PROMPT)


func _draw_stage_select(font: Font) -> void:
	_draw_centered(font, "// STAGE SELECT", 18.0, SUBTITLE_FONT_SIZE, COLOR_NEON)
	# Header row.
	var header_y: float = 38.0
	draw_string(font, Vector2(20.0, header_y),
		"STAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, STORY_FONT_SIZE, COLOR_NEON_DARK)
	draw_string(font, Vector2(190.0, header_y),
		"SCORE  RANK   TIME", HORIZONTAL_ALIGNMENT_LEFT, -1, STORY_FONT_SIZE, COLOR_NEON_DARK)
	# Rows.
	for i in STAGE_LIST.size():
		var y: float = 52.0 + float(i) * 13.0
		var entry: Array = STAGE_LIST[i]
		var key: String = String(entry[0])
		var name: String = String(entry[1])
		var unlocked: bool = Game.is_stage_unlocked(key)
		var selected: bool = (i == _stage_cursor)
		var color: Color = COLOR_PROMPT
		if not unlocked:
			color = COLOR_SHOP_DIM
		elif selected:
			color = COLOR_GOLD
		var prefix: String = "> " if selected else "  "
		var label: String = name if unlocked else "%s  [LOCKED]" % name
		draw_string(font, Vector2(20.0, y),
			"%s%s" % [prefix, label], HORIZONTAL_ALIGNMENT_LEFT, -1,
			STORY_FONT_SIZE, color)
		if unlocked:
			var score: int = int(Game.best_scores.get(key, 0))
			var rank: String = "—" if score == 0 else Game.rank_for_score(score)
			var time: float = float(Game.best_times.get(key, INF))
			var time_str: String = Game.format_time(time)
			var stat_text: String = "%5d  %3s   %s" % [score, rank, time_str]
			draw_string(font, Vector2(190.0, y),
				stat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STORY_FONT_SIZE, color)
	# Stats footer.
	var stats_y: float = 156.0
	_draw_centered(font,
		"RUNS %d   COINS %d   SECTORS CLEARED %d/%d" % [
			Game.total_runs, Game.coins,
			Game.best_scores.size(), STAGE_LIST.size()
		],
		stats_y, STORY_FONT_SIZE, COLOR_FLAVOR)
	_draw_centered(font, "↑↓ NAVIGATE   X ENTER", 174.0,
		STORY_FONT_SIZE, COLOR_NEON_DARK)


func _draw_achievements(font: Font) -> void:
	var defs: Array = Game.ACHIEVEMENT_DEFS
	var unlocked_count: int = 0
	for entry in defs:
		if Game.has_achievement(String(entry["id"])):
			unlocked_count += 1
	_draw_centered(font, "// ACHIEVEMENTS — %d / %d" % [unlocked_count, defs.size()],
		18.0, SUBTITLE_FONT_SIZE, COLOR_NEON)
	# Two columns of 6 entries each.
	var col_w: float = float(VIEWPORT_W) * 0.5
	for i in defs.size():
		var col: int = i / 6
		var row: int = i % 6
		var x: float = 12.0 + float(col) * col_w
		var y: float = 38.0 + float(row) * 22.0
		var entry: Dictionary = defs[i]
		var id: String = String(entry["id"])
		var owned: bool = Game.has_achievement(id)
		var color: Color = COLOR_GOLD if owned else COLOR_SHOP_DIM
		var check: String = "[X]" if owned else "[ ]"
		draw_string(font, Vector2(x, y),
			"%s %s" % [check, String(entry["name"])],
			HORIZONTAL_ALIGNMENT_LEFT, -1, STORY_FONT_SIZE + 1, color)
		# Description line in smaller dim text right below.
		draw_string(font, Vector2(x + 12.0, y + 9.0),
			String(entry["description"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, STORY_FONT_SIZE - 1, COLOR_NEON_DARK)


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

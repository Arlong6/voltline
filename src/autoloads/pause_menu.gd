## Voltline — global pause menu autoload (v0.59).
##
## Listens for the `pause` action (ESC) on every frame and pops up a
## CanvasLayer overlay that pauses the SceneTree. Two pages:
##   MAIN     — RESUME / RESTART / TITLE / SETTINGS
##   SETTINGS — MASTER / SFX / MUSIC sliders + BACK
##
## The autoload itself runs with PROCESS_MODE_ALWAYS so its input handler
## stays live while the rest of the game is paused. Suppresses itself on
## the title screen and during cutscenes (no need to pause those).
extends Node

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216

const COLOR_DIM:    Color = Color(0.0, 0.0, 0.0, 0.78)
const COLOR_FRAME:  Color = Color("#1A2438")
const COLOR_LABEL:  Color = Color("#A8D8FF")
const COLOR_HEAD:   Color = Color("#FFD24A")
const COLOR_HILITE: Color = Color("#FFD24A")
const COLOR_DIM_TX: Color = Color("#5A6A82")
const COLOR_BAR_FG: Color = Color("#43D27A")
const COLOR_BAR_BG: Color = Color("#1A2438")

const HEAD_FONT_SIZE: int = 16
const ITEM_FONT_SIZE: int = 12
const HINT_FONT_SIZE: int = 9

# Step size when LEFT/RIGHT adjusts a settings slider.
const VOLUME_STEP: float = 0.05

# Page identifiers.
enum Page { MAIN, SETTINGS }

# MAIN page item indices.
enum MainItem { RESUME, RESTART, TITLE, SETTINGS, COUNT }

# SETTINGS page item indices.
enum SettingsItem { MASTER, SFX, MUSIC, BACK, COUNT }

# Display labels — declared as `var` because PackedStringArray
# constructors are not constant expressions in GDScript.
var _MAIN_LABELS: PackedStringArray = PackedStringArray([
	"RESUME", "RESTART STAGE", "RETURN TO TITLE", "SETTINGS",
])
var _SETTINGS_LABELS: PackedStringArray = PackedStringArray([
	"MASTER VOLUME", "SFX VOLUME", "MUSIC VOLUME", "BACK",
])

var _layer: CanvasLayer
var _backing: ColorRect
var _draw_node: Node2D

var _is_open: bool = false
var _page: int = Page.MAIN
var _selection: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if Game.test_mode:
		return
	# ESC toggles the menu — but only inside actual gameplay scenes.
	if event.is_action_pressed("pause"):
		if not _is_open and _is_pausable_scene():
			open()
			get_viewport().set_input_as_handled()
		elif _is_open:
			# Closing from settings page goes back to main first.
			if _page == Page.SETTINGS:
				_page = Page.MAIN
				_selection = MainItem.RESUME
				_redraw()
			else:
				close()
			get_viewport().set_input_as_handled()
		return
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_menu_key(event)
		get_viewport().set_input_as_handled()


func _is_pausable_scene() -> bool:
	# Don't pause the title or cutscene flows — those have their own
	# input handling (and pausing them feels weird).
	var area: String = Game.current_area
	if area == "" or area == "title" or area == "cutscene":
		return false
	return true


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_page = Page.MAIN
	_selection = MainItem.RESUME
	_layer.visible = true
	get_tree().paused = true
	_redraw()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_layer.visible = false
	get_tree().paused = false


# ---------------------------------------------------------------------------
# Menu input
# ---------------------------------------------------------------------------

func _handle_menu_key(event: InputEventKey) -> void:
	# Up/Down navigate, Left/Right adjust sliders, Enter/X confirm.
	var item_count: int = MainItem.COUNT if _page == Page.MAIN else SettingsItem.COUNT
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_selection = (_selection - 1 + item_count) % item_count
			_redraw()
		KEY_DOWN, KEY_S:
			_selection = (_selection + 1) % item_count
			_redraw()
		KEY_LEFT, KEY_A:
			if _page == Page.SETTINGS:
				_adjust_setting(-VOLUME_STEP)
		KEY_RIGHT, KEY_D:
			if _page == Page.SETTINGS:
				_adjust_setting(VOLUME_STEP)
		KEY_ENTER, KEY_KP_ENTER, KEY_X, KEY_SPACE:
			_activate_selection()


func _activate_selection() -> void:
	if _page == Page.MAIN:
		match _selection:
			MainItem.RESUME:
				close()
			MainItem.RESTART:
				_restart_current_stage()
			MainItem.TITLE:
				_return_to_title()
			MainItem.SETTINGS:
				_page = Page.SETTINGS
				_selection = SettingsItem.MASTER
				_redraw()
	else:  # SETTINGS
		if _selection == SettingsItem.BACK:
			_page = Page.MAIN
			_selection = MainItem.SETTINGS
			_redraw()


func _adjust_setting(delta: float) -> void:
	match _selection:
		SettingsItem.MASTER:
			Game.setting_master_volume = clampf(Game.setting_master_volume + delta, 0.0, 1.0)
		SettingsItem.SFX:
			Game.setting_sfx_volume = clampf(Game.setting_sfx_volume + delta, 0.0, 1.0)
			# Play a blip so the user can hear the new SFX level.
			Sfx.play("coin_pickup")
		SettingsItem.MUSIC:
			Game.setting_music_volume = clampf(Game.setting_music_volume + delta, 0.0, 1.0)
		_:
			return
	Game.apply_audio_settings()
	Game.save_to_file()
	_redraw()


func _restart_current_stage() -> void:
	close()
	var area: String = Game.current_area
	if area != "" and Game.LEVEL_PATHS.has(area):
		Game.reset_run()
		Game.goto_level(area)
	else:
		_return_to_title()


func _return_to_title() -> void:
	close()
	Game.goto_level("title")


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.visible = false
	add_child(_layer)

	_backing = ColorRect.new()
	_backing.color = COLOR_DIM
	_backing.position = Vector2.ZERO
	_backing.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_backing)

	_draw_node = Node2D.new()
	_draw_node.draw.connect(_render)
	_layer.add_child(_draw_node)


func _redraw() -> void:
	_draw_node.queue_redraw()


func _render() -> void:
	var font: Font = ThemeDB.fallback_font
	# Frame — same look as the cutscene comms terminal.
	var frame: Rect2 = Rect2(40.0, 40.0, float(VIEWPORT_W) - 80.0, 140.0)
	_draw_node.draw_rect(frame, Color(0.0, 0.0, 0.0, 0.92))
	_draw_node.draw_rect(frame, COLOR_FRAME, false, 1.0)

	if _page == Page.MAIN:
		_render_main(font)
	else:
		_render_settings(font)


func _render_main(font: Font) -> void:
	_draw_centered(font, "// PAUSED", 56.0, HEAD_FONT_SIZE, COLOR_HEAD)
	for i in MainItem.COUNT:
		var y: float = 88.0 + float(i) * 16.0
		var color: Color = COLOR_HILITE if _selection == i else COLOR_LABEL
		var prefix: String = "> " if _selection == i else "  "
		_draw_centered(font, prefix + _MAIN_LABELS[i], y, ITEM_FONT_SIZE, color)
	_draw_centered(font, "↑↓ NAVIGATE   X CONFIRM   ESC CLOSE", 168.0,
		HINT_FONT_SIZE, COLOR_DIM_TX)


func _render_settings(font: Font) -> void:
	_draw_centered(font, "// SETTINGS", 56.0, HEAD_FONT_SIZE, COLOR_HEAD)
	# 3 sliders.
	for i in 3:
		var y: float = 84.0 + float(i) * 22.0
		var label: String = _SETTINGS_LABELS[i]
		var value: float = _value_for_settings_index(i)
		var color: Color = COLOR_HILITE if _selection == i else COLOR_LABEL
		var prefix: String = "> " if _selection == i else "  "
		_draw_node.draw_string(
			font, Vector2(56.0, y),
			"%s%s" % [prefix, label], HORIZONTAL_ALIGNMENT_LEFT, -1,
			ITEM_FONT_SIZE, color
		)
		_draw_volume_bar(value, y + 4.0)
	# BACK row.
	var back_y: float = 152.0
	var back_color: Color = COLOR_HILITE if _selection == SettingsItem.BACK else COLOR_LABEL
	var back_prefix: String = "> " if _selection == SettingsItem.BACK else "  "
	_draw_centered(font, back_prefix + "BACK", back_y, ITEM_FONT_SIZE, back_color)
	_draw_centered(font, "←→ ADJUST   X CONFIRM   ESC CLOSE", 174.0,
		HINT_FONT_SIZE, COLOR_DIM_TX)


func _value_for_settings_index(idx: int) -> float:
	match idx:
		SettingsItem.MASTER: return Game.setting_master_volume
		SettingsItem.SFX:    return Game.setting_sfx_volume
		SettingsItem.MUSIC:  return Game.setting_music_volume
	return 0.0


func _draw_volume_bar(value: float, y: float) -> void:
	# Right-side horizontal bar, 120 px wide, 6 px tall.
	var bar_x: float = float(VIEWPORT_W) - 56.0 - 120.0
	_draw_node.draw_rect(Rect2(bar_x, y, 120.0, 6.0), COLOR_BAR_BG)
	var filled: float = clampf(value, 0.0, 1.0) * 120.0
	_draw_node.draw_rect(Rect2(bar_x, y, filled, 6.0), COLOR_BAR_FG)


func _draw_centered(font: Font, text: String, y: float, font_size: int, color: Color) -> void:
	var size: Vector2 = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	_draw_node.draw_string(
		font, Vector2((float(VIEWPORT_W) - size.x) * 0.5, y),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
	)

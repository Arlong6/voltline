## Voltline — boss intro slam-in (v0.68).
##
## A one-shot CanvasLayer that flies the boss's name in from the right,
## holds briefly in the centre with a chromatic slam, then flies off to
## the left and queue_free's itself. Spawned from Boss._enter_tree right
## next to the BossHpBar; both vanish when the boss dies.
##
## The whole animation fits inside the boss's bullet_initial_delay window
## (typically 1.0–1.5 s) so the player isn't getting shot during the show.
class_name BossIntro
extends CanvasLayer

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216

const _COLOR_BG_BAR: Color = Color(0.0, 0.0, 0.0, 0.55)
const _COLOR_TEXT: Color = Color("#FF8080")
const _COLOR_SHADOW: Color = Color("#600A0A")

const _BAR_HEIGHT: float = 36.0
const _SLIDE_IN_TIME: float = 0.32
const _HOLD_TIME: float = 0.85
const _SLIDE_OUT_TIME: float = 0.30

## Set by Boss._spawn_intro before the overlay enters the tree.
var boss_name: String = "BOSS"

# Internal — built in _ready, animated by a Tween.
var _bar_rect: ColorRect
var _name_label: Label


func _ready() -> void:
	layer = 11  # one above the stage HUD layer (10)
	_bar_rect = ColorRect.new()
	_bar_rect.color = _COLOR_BG_BAR
	_bar_rect.position = Vector2(0.0, (float(VIEWPORT_H) - _BAR_HEIGHT) * 0.5)
	_bar_rect.size = Vector2(VIEWPORT_W, _BAR_HEIGHT)
	_bar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Start invisible — fade in via the tween.
	_bar_rect.modulate.a = 0.0
	add_child(_bar_rect)

	_name_label = Label.new()
	_name_label.text = boss_name
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", _COLOR_TEXT)
	_name_label.add_theme_constant_override("shadow_offset_x", 2)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_name_label.add_theme_color_override("font_shadow_color", _COLOR_SHADOW)
	_name_label.size = Vector2(VIEWPORT_W, _BAR_HEIGHT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Start off the right edge for the slam-in.
	_name_label.position = Vector2(float(VIEWPORT_W), _bar_rect.position.y)
	add_child(_name_label)

	if not Game.test_mode:
		_play_intro()


func _play_intro() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(false)
	# Slide in + fade the bar in simultaneously.
	tween.set_parallel(true)
	tween.tween_property(_name_label, "position:x", 0.0, _SLIDE_IN_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bar_rect, "modulate:a", 1.0, _SLIDE_IN_TIME * 0.6)
	# Hold.
	tween.set_parallel(false)
	tween.tween_interval(_HOLD_TIME)
	# Slide out + fade the bar out.
	tween.set_parallel(true)
	tween.tween_property(_name_label, "position:x", -float(VIEWPORT_W), _SLIDE_OUT_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(_bar_rect, "modulate:a", 0.0, _SLIDE_OUT_TIME)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

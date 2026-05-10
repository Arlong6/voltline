## Voltline — player HP bar (V-009 full).
##
## Top-left HUD readout that reads `player.hp` / `player.max_hp` and draws
## a small filled bar plus a numeric label. Lives on a CanvasLayer so it
## stays anchored to the screen as the camera scrolls.
class_name HpBar
extends Control

const _WIDTH: float = 80.0
const _HEIGHT: float = 8.0

const _COLOR_BG: Color = Color("#0F1218")
const _COLOR_BORDER: Color = Color("#7AC8FF")
const _COLOR_FILL: Color = Color("#43D27A")
const _COLOR_FILL_LOW: Color = Color("#F4734D")
const _COLOR_TEXT: Color = Color("#FFFFFF")

## Reference to the player whose HP we're rendering. Set by the stage on
## _build_hud after the player has been spawned.
var player: Player = null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var pct: float = 0.0
	if player.max_hp > 0:
		pct = float(player.hp) / float(player.max_hp)
	# Frame
	draw_rect(Rect2(0.0, 0.0, _WIDTH, _HEIGHT), _COLOR_BG)
	# Fill — turn orange when below 25%.
	var fill_w: float = (_WIDTH - 4.0) * pct
	var fill_color: Color = _COLOR_FILL_LOW if pct < 0.25 else _COLOR_FILL
	draw_rect(Rect2(2.0, 2.0, fill_w, _HEIGHT - 4.0), fill_color)
	# Border
	draw_rect(Rect2(0.0, 0.0, _WIDTH, _HEIGHT), _COLOR_BORDER, false)
	# Numeric readout to the right of the bar.
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font, Vector2(_WIDTH + 6.0, _HEIGHT - 1.0),
		"HP %d / %d" % [player.hp, player.max_hp],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, _COLOR_TEXT
	)

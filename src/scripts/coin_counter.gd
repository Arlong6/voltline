## Voltline — HUD coin counter.
##
## Reads Game.coins each frame and renders a small icon + count to the
## top-right area of the viewport. Sits on a stage's HUD CanvasLayer.
class_name CoinCounter
extends Control

const _COIN_COLOR: Color = Color("#FFD24A")
const _TEXT_COLOR: Color = Color("#FFFFFF")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Coin icon (6x6 gold square).
	draw_rect(Rect2(0.0, 0.0, 6.0, 6.0), _COIN_COLOR)
	# Count label.
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font, Vector2(10.0, 6.0),
		"x %d" % Game.coins,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _TEXT_COLOR
	)

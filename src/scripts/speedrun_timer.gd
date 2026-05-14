## Voltline — in-stage speedrun timer (v0.68).
##
## Compact HUD widget that mirrors Game.session_time at frame rate plus
## the personal best (best_times[current_area]) below it. Anchored to the
## top-right of the viewport on a CanvasLayer, alongside the coin counter.
##
## Reads `Game.current_area` so the same widget works in every stage —
## stages just add one of these to their HUD layer.
class_name SpeedrunTimer
extends Control

const _COLOR_TIME: Color = Color("#FFFFFF")
const _COLOR_PB: Color = Color("#8AC8FF")
const _COLOR_AHEAD: Color = Color("#43D27A")
const _COLOR_BEHIND: Color = Color("#F4734D")

const _FONT_SIZE_TIME: int = 11
const _FONT_SIZE_PB: int = 8


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Returns the personal-best time for the current stage, or INF if none.
func current_pb() -> float:
	return float(Game.best_times.get(Game.current_area, INF))


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# Line 1 — current run time.
	var t_str: String = Game.format_time(Game.session_time)
	# Show PB on the second line. Colour the run time green when ahead of
	# PB, orange when behind, white when no PB yet.
	var pb: float = current_pb()
	var time_color: Color = _COLOR_TIME
	if pb != INF and Game.session_time > 0.0:
		time_color = _COLOR_AHEAD if Game.session_time < pb else _COLOR_BEHIND
	draw_string(font, Vector2(0.0, 11.0), t_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE_TIME, time_color)
	# Line 2 — PB or "—" placeholder.
	var pb_str: String = "PB %s" % Game.format_time(pb)
	draw_string(font, Vector2(0.0, 22.0), pb_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE_PB, _COLOR_PB)

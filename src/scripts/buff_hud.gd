## Voltline — active-buff HUD widget (v0.64).
##
## Reads Game.buffs each frame and renders a horizontal strip of icons
## with countdown numbers. One icon per active buff. Mounted by each
## stage's _build_hud into the HUD CanvasLayer.
##
## Compact: 16-px-wide icon + 1-decimal-second countdown label per buff.
class_name BuffHud
extends Control

const _COLORS: Dictionary = {
	"invincible": Color("#7AC8FF"),
	"damage_up":  Color("#FFD24A"),
	"rapid_fire": Color("#FF60D0"),
	"magnet":     Color("#FF9030"),
}

const _GLYPHS: Dictionary = {
	"invincible": "INV",
	"damage_up":  "DMG",
	"rapid_fire": "RPD",
	"magnet":     "MAG",
}

# Order in which to render buffs (deterministic regardless of pickup order).
const _ORDER: PackedStringArray = PackedStringArray([
	"invincible", "damage_up", "rapid_fire", "magnet",
])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var x: float = 0.0
	for key in _ORDER:
		var remaining: float = Game.buff_remaining(key)
		if remaining <= 0.0:
			continue
		var color: Color = _COLORS[key]
		# Icon: small diamond.
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x + 6.0, 0.0),
			Vector2(x + 12.0, 6.0),
			Vector2(x + 6.0, 12.0),
			Vector2(x, 6.0),
		])
		draw_polygon(pts, PackedColorArray([color]))
		# Label + countdown.
		var label: String = "%s %.1f" % [_GLYPHS[key], remaining]
		draw_string(font, Vector2(x + 16.0, 10.0),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
		x += 56.0

	# v0.64 — sub-weapon HUD slot drawn on the right side. Shows equipped
	# name + cooldown ring. SHIFT fires when ready.
	var sub_label: String = String(Game.SUBWEAPON_LABELS.get(
		Game.equipped_subweapon, "—"
	))
	var ready: bool = Game.subweapon_ready()
	var cd: float = Game.subweapon_cooldown_remaining
	var color2: Color = Color("#43D27A") if ready else Color("#5A6A82")
	var status: String = "READY" if ready else "%.1f" % cd
	var sub_text: String = "SHIFT %s  %s" % [sub_label, status]
	# Right-align by computing width and offsetting from size.x.
	var text_size: Vector2 = font.get_string_size(
		sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8
	)
	var sub_x: float = size.x - text_size.x - 4.0
	draw_string(font, Vector2(sub_x, 10.0),
		sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color2)

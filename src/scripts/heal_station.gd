## Voltline — mid-stage heal station (v0.56).
##
## Area2D vendor pad — when the player walks on top, deducts `cost` coins
## from Game and heals `heal_amount` HP. Stays on the map (does NOT
## queue_free) but armed with a per-stage `_used` flag so a single station
## can only be cashed in once per run. Players who don't have enough coins
## or are already at full HP get a silent no-op.
class_name HealStation
extends Area2D

const _COLOR_FRAME: Color = Color("#3F5A88")
const _COLOR_FRAME_USED: Color = Color("#2A2E3A")
const _COLOR_PAD: Color = Color("#43D27A")
const _COLOR_PAD_USED: Color = Color("#1F3F2A")
const _COLOR_GLOW: Color = Color("#7FFFB0")

@export var cost: int = 8
@export var heal_amount: int = 6

var _t: float = 0.0
var _used: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode:
		return
	if _used:
		return
	if not (body is Player):
		return
	if body.hp >= body.max_hp:
		return  # already topped up — don't waste the player's coins
	if Game.coins < cost:
		return
	Game.coins -= cost
	Game.save_to_file()
	body.heal(heal_amount)
	_used = true
	Sfx.play("heal")


func _draw() -> void:
	# 16×6 base pad on the floor.
	var pad_color: Color = _COLOR_PAD_USED if _used else _COLOR_PAD
	draw_rect(Rect2(-8.0, 0.0, 16.0, 4.0), pad_color)
	# Two side posts framing the pad.
	var frame_color: Color = _COLOR_FRAME_USED if _used else _COLOR_FRAME
	draw_rect(Rect2(-8.0, -10.0, 2.0, 12.0), frame_color)
	draw_rect(Rect2(6.0, -10.0, 2.0, 12.0), frame_color)
	# Top crossbar.
	draw_rect(Rect2(-8.0, -10.0, 16.0, 2.0), frame_color)
	# Glow plus-sign while still active — pulses with sin(t).
	if not _used:
		var pulse: float = (sin(_t * 4.0) + 1.0) * 0.5  # 0..1
		var glow_color: Color = Color(
			_COLOR_GLOW.r, _COLOR_GLOW.g, _COLOR_GLOW.b,
			0.5 + pulse * 0.5
		)
		draw_rect(Rect2(-1.0, -7.0, 2.0, 6.0), glow_color)
		draw_rect(Rect2(-3.0, -5.0, 6.0, 2.0), glow_color)

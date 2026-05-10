## Voltline — shootable switch panel (v0.62).
##
## A wall-mounted target the player has to hit with ANY bullet (Lv0+
## counts) to flip the switch ON. Once triggered, it stays on for the
## duration of the run and emits the `triggered` signal so connected
## doors can open in response.
##
## Doesn't take a Bullet's full bullet → enemy pipeline; instead it
## listens for body_entered as an Area2D so a player projectile entering
## its hitbox is enough to flip it.
class_name SwitchPanel
extends Area2D

const _COLOR_FRAME: Color = Color("#3A2E40")
const _COLOR_PLATE_OFF: Color = Color("#586070")
const _COLOR_PLATE_ON: Color = Color("#43D27A")
const _COLOR_LED_OFF: Color = Color("#7AC8FF")
const _COLOR_LED_ON: Color = Color("#FFD24A")

## Visible size — drawn centred on the body. Hit area matches.
@export var size: Vector2 = Vector2(12.0, 16.0)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## True after a bullet has triggered the switch.
var is_on: bool = false

## Fired exactly once when the switch flips ON. Doors connect to this.
signal triggered

var _t: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	queue_redraw()


# Player projectiles arrive as Area2D (Bullet inherits from it). Walls
# / static bodies arrive via body_entered but those are filtered out
# inside _trigger_if_player_bullet.
func _on_area_entered(area: Area2D) -> void:
	if Game.test_mode:
		return
	if area is Bullet:
		_trigger()


func _on_body_entered(body: Node2D) -> void:
	# StaticBody2D collisions are no-ops; we only react to Bullet areas.
	pass


# ---------------------------------------------------------------------------
# State change
# ---------------------------------------------------------------------------

## Public so tests / cheats can flip directly.
func _trigger() -> void:
	if is_on:
		return
	is_on = true
	if not Game.test_mode:
		Sfx.play("coin_pickup")
	triggered.emit()


func trigger() -> void:
	_trigger()


func _draw() -> void:
	# Frame plate.
	draw_rect(Rect2(-size * 0.5, size), _COLOR_FRAME)
	# Inner plate — color shifts on trigger.
	var plate_color: Color = _COLOR_PLATE_ON if is_on else _COLOR_PLATE_OFF
	draw_rect(Rect2(-size.x * 0.5 + 2.0, -size.y * 0.5 + 2.0,
		size.x - 4.0, size.y - 4.0), plate_color)
	# LED indicator — blinks slowly when off, solid yellow when on.
	var led_color: Color = _COLOR_LED_ON
	if not is_on:
		var blink: float = (sin(_t * 4.0) + 1.0) * 0.5
		led_color = Color(_COLOR_LED_OFF.r, _COLOR_LED_OFF.g, _COLOR_LED_OFF.b,
			0.5 + blink * 0.5)
	draw_rect(Rect2(-2.0, -size.y * 0.5 + 4.0, 4.0, 3.0), led_color)

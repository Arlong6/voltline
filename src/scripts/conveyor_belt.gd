## Voltline — conveyor-belt floor (v0.62).
##
## AnimatableBody2D with a non-zero `constant_linear_velocity` so any
## CharacterBody2D standing on top gets carried along at `belt_speed`
## px/s. Visual is a strip of arrows pointing in the carry direction
## that animate along the belt for clear directional reading.
##
## The belt itself does NOT move (position is fixed); only the
## constant_linear_velocity field — read by Godot's collision response
## — gives the player the carry impulse.
class_name ConveyorBelt
extends AnimatableBody2D

## Carry speed in px/s. Positive = right, negative = left.
@export var belt_speed: float = 80.0

## Visual size — drawn as a single strip centred on the body.
@export var size: Vector2 = Vector2(64.0, 8.0)

const _COLOR_BELT: Color = Color("#3F4858")
const _COLOR_FRAME: Color = Color("#1A2028")
const _COLOR_ARROW: Color = Color("#FFD24A")
const _COLOR_ARROW_DIM: Color = Color("#A07020")

# Distance arrows travel per second (visual only — synced to belt_speed
# direction).
const _ARROW_SCROLL_RATE: float = 1.0

var _t: float = 0.0


func _ready() -> void:
	# Tells the physics engine to apply this velocity to anything resting
	# on the belt's surface. Direction matches belt_speed sign.
	constant_linear_velocity = Vector2(belt_speed, 0.0)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Frame.
	draw_rect(Rect2(-size * 0.5, size), _COLOR_FRAME)
	# Belt surface — slightly inset.
	draw_rect(Rect2(-size.x * 0.5 + 1.0, -size.y * 0.5 + 1.0,
		size.x - 2.0, size.y - 2.0), _COLOR_BELT)
	# Animated arrows scrolling in the belt's direction.
	var arrow_count: int = int(size.x / 12.0)
	var dir: float = signf(belt_speed)
	# Phase shifts based on time × belt_speed sign so arrows scroll with belt.
	var phase: float = fposmod(_t * belt_speed * 0.04, 1.0)
	for i in arrow_count:
		var alpha: float = (float(i) / float(maxi(arrow_count - 1, 1))) + phase
		alpha = fposmod(alpha, 1.0)
		var x: float = -size.x * 0.5 + 4.0 + alpha * (size.x - 8.0)
		# Triangle pointing in belt direction.
		var arrow_color: Color = _COLOR_ARROW if int(_t * 4.0) % 2 == 0 else _COLOR_ARROW_DIM
		var pts: PackedVector2Array
		if dir >= 0.0:
			pts = PackedVector2Array([
				Vector2(x - 2.0, -1.5),
				Vector2(x + 2.0, 0.0),
				Vector2(x - 2.0, 1.5),
			])
		else:
			pts = PackedVector2Array([
				Vector2(x + 2.0, -1.5),
				Vector2(x - 2.0, 0.0),
				Vector2(x + 2.0, 1.5),
			])
		draw_polygon(pts, PackedColorArray([arrow_color]))

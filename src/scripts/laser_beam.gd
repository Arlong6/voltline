## Voltline — pulsing laser hazard (v0.59).
##
## Area2D that cycles ON/OFF on a fixed period. While ON it deals heavy
## damage to the player on contact and renders a bright crimson beam.
## While OFF it draws a thin warning outline so the player can read its
## footprint before it fires.
##
## Pure-logic tick(delta) drives the cycle so unit tests can verify the
## ON window without a SceneTree timer.
class_name LaserBeam
extends Area2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Total cycle length in seconds (ON window + OFF window).
@export var period: float = 2.4

## Fraction of `period` during which the laser is ON. 0.35 = ON for
## ~0.84s every 2.4s.
@export var on_duty: float = 0.35

## Phase offset (seconds). Lets multiple lasers in a corridor stagger.
@export var phase: float = 0.0

## Damage applied to the player on contact while ON.
@export var damage: int = 4

## Beam dimensions — drawn centred on the body.
@export var size: Vector2 = Vector2(8.0, 64.0)

const _COLOR_ON: Color = Color("#FF3838")
const _COLOR_ON_CORE: Color = Color("#FFE8E8")
const _COLOR_WARN: Color = Color("#FF8030")
const _COLOR_OFF: Color = Color(1.0, 0.4, 0.4, 0.18)

# Last 0.25s of the OFF window flashes orange so the player knows it's
# about to fire.
const _WARN_LEAD_TIME: float = 0.25

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _t: float = 0.0
var is_on: bool = false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if Game.test_mode:
		return
	tick(delta)
	# Toggle Area2D monitoring with the on/off state — when off, contact
	# is a no-op even if the player is inside the rect.
	monitoring = is_on
	queue_redraw()


## Pure-logic cycle step. Updates `is_on` based on (t + phase) mod period.
func tick(delta: float) -> void:
	_t += delta
	var local: float = fposmod(_t + phase, period)
	is_on = local < (period * on_duty)


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode or not is_on:
		return
	if body is Player and body.has_method("take_damage"):
		body.take_damage(damage)


func _draw() -> void:
	# Determine if we're in the warning sliver right before ON.
	var local: float = fposmod(_t + phase, period)
	var on_window_end: float = period * on_duty
	var until_on: float = period - local  # seconds until next ON edge
	var in_warn: bool = (
		not is_on
		and until_on <= _WARN_LEAD_TIME
		and until_on > 0.0
	)
	var rect: Rect2 = Rect2(-size * 0.5, size)
	if is_on:
		# Outer crimson glow + bright core.
		draw_rect(rect, _COLOR_ON)
		var core: Vector2 = Vector2(size.x * 0.5, size.y)
		draw_rect(Rect2(-core * 0.5, core), _COLOR_ON_CORE)
	elif in_warn:
		# Pulsing orange "telegraph" outline.
		var pulse: float = (sin(_t * 40.0) + 1.0) * 0.5
		var c: Color = Color(_COLOR_WARN.r, _COLOR_WARN.g, _COLOR_WARN.b,
			0.4 + pulse * 0.5)
		draw_rect(rect, c, false, 2.0)
	else:
		# Faint outline so the player can see the footprint.
		draw_rect(rect, _COLOR_OFF, false, 1.0)

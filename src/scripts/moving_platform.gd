## Voltline — moving platform hazard (v0.59).
##
## AnimatableBody2D that oscillates between its starting position and
## (start + travel) on a sinusoidal path. AnimatableBody2D propagates
## its motion to CharacterBody2D bodies standing on it via Godot's
## floor-snap, so the player rides it for free.
##
## Behaves identically in test mode minus the queue_redraw — pure
## sinusoidal position update via tick(delta) so unit tests can drive it.
class_name MovingPlatform
extends AnimatableBody2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Total displacement applied across one half-cycle. Set to (96, 0) for
## a horizontal mover; (0, -64) for a riser; (96, 64) for diagonal.
@export var travel: Vector2 = Vector2(96.0, 0.0)

## Seconds for a full there-and-back cycle.
@export var period: float = 4.0

## Optional phase offset (radians). Lets multiple platforms in a row stay
## staggered so the player can chain jumps between them.
@export var phase: float = 0.0

## Visual size — drawn as a single rect centred on the body.
@export var size: Vector2 = Vector2(56.0, 8.0)

## Visual color — defaults to a steel cyan that reads against most stage
## palettes; override per-stage if it clashes.
@export var color: Color = Color("#5BC0F0")

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _t: float = 0.0
var _origin: Vector2 = Vector2.ZERO

## Current offset from the origin (0 → travel → 0 across a cycle).
## Mirrored to `position` each tick. Exposed so tests can verify motion
## without relying on AnimatableBody2D's transform write semantics, which
## are sometimes filtered by Godot's headless physics stepper.
var current_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_origin = position
	_t = 0.0


func _physics_process(delta: float) -> void:
	if Game.test_mode:
		return
	tick(delta)
	queue_redraw()


## Pure-logic position step. Tests call this directly.
func tick(delta: float) -> void:
	_t += delta
	# 0.5 * (1 - cos(...)) ramps alpha 0→1→0 each cycle so the platform
	# oscillates between origin and origin + travel without overshoot.
	var alpha: float = 0.5 - 0.5 * cos(TAU * _t / period + phase)
	current_offset = travel * alpha
	position = _origin + current_offset


func _draw() -> void:
	draw_rect(Rect2(-size * 0.5, size), color)

## Voltline — ceiling crusher hazard (v0.59).
##
## AnimatableBody2D that idles at its starting position, then SLAMS down
## by `slam_distance` over `slam_time` seconds, holds for `hold_time`,
## then retracts upward over `retract_time`. Damage is applied via a
## child Area2D HurtBox that's only monitoring during the slam.
##
## The cycle is fully data-driven; tests can drive tick(delta) directly
## to verify the four-phase state machine (idle → slamming → held →
## retracting).
class_name Crusher
extends AnimatableBody2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Vertical distance the crusher travels per slam (positive = downward).
@export var slam_distance: float = 96.0

## Seconds spent travelling DOWN.
@export var slam_time: float = 0.18

## Seconds the crusher stays at the bottom before retracting.
@export var hold_time: float = 0.6

## Seconds spent travelling back UP.
@export var retract_time: float = 1.2

## Seconds idle at the top before the next slam fires.
@export var idle_time: float = 1.4

## Damage applied to the player on contact while the slam is active or held.
@export var damage: int = 6

## Visual size — drawn as a wide rect centred on the body.
@export var size: Vector2 = Vector2(48.0, 24.0)

## Visual color — defaults to a heavy iron grey.
@export var color: Color = Color("#3A3A48")

const _COLOR_DETAIL: Color = Color("#1A1A22")
const _COLOR_DANGER: Color = Color("#FFAA40")  # underside teeth glow before slam

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

enum Phase { IDLE, SLAM, HOLD, RETRACT }

var _phase: int = Phase.IDLE
var _phase_t: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _hurt_area: Area2D

## Current vertical offset from the origin (positive = descended). Computed
## inside tick() so tests can inspect motion without poking at the
## AnimatableBody2D's transform — `position` doesn't always reflect runtime
## writes in the headless physics stepper.
var current_offset_y: float = 0.0


func _ready() -> void:
	_origin = position
	_phase = Phase.IDLE
	_phase_t = 0.0
	_build_hurt_area()


func _physics_process(delta: float) -> void:
	if Game.test_mode:
		return
	tick(delta)
	# Hurt area only "live" during the slam + hold phases (the descent
	# and the impact). Retraction is safe.
	_hurt_area.monitoring = (_phase == Phase.SLAM or _phase == Phase.HOLD)
	queue_redraw()


## Pure-logic state-machine tick. Tests call this directly.
func tick(delta: float) -> void:
	_phase_t += delta
	match _phase:
		Phase.IDLE:
			current_offset_y = 0.0
			if _phase_t >= idle_time:
				_phase = Phase.SLAM
				_phase_t = 0.0
		Phase.SLAM:
			var alpha: float = clampf(_phase_t / slam_time, 0.0, 1.0)
			# Ease-in for a snappy drop.
			alpha = alpha * alpha
			current_offset_y = slam_distance * alpha
			if _phase_t >= slam_time:
				current_offset_y = slam_distance
				_phase = Phase.HOLD
				_phase_t = 0.0
		Phase.HOLD:
			current_offset_y = slam_distance
			if _phase_t >= hold_time:
				_phase = Phase.RETRACT
				_phase_t = 0.0
		Phase.RETRACT:
			var alpha: float = clampf(_phase_t / retract_time, 0.0, 1.0)
			# Ease-out so the lift looks mechanical.
			current_offset_y = slam_distance * (1.0 - alpha)
			if _phase_t >= retract_time:
				current_offset_y = 0.0
				_phase = Phase.IDLE
				_phase_t = 0.0
	position = _origin + Vector2(0.0, current_offset_y)


func _build_hurt_area() -> void:
	_hurt_area = Area2D.new()
	_hurt_area.name = &"HurtArea"
	_hurt_area.collision_layer = 0
	_hurt_area.collision_mask = 2  # Player layer
	_hurt_area.monitoring = false
	add_child(_hurt_area)
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	_hurt_area.add_child(collider)
	_hurt_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode:
		return
	if body is Player and body.has_method("take_damage"):
		body.take_damage(damage)


func _draw() -> void:
	# Body.
	draw_rect(Rect2(-size * 0.5, size), color)
	# Detail strip across the top.
	draw_rect(Rect2(-size.x * 0.5, -size.y * 0.5, size.x, 4.0), _COLOR_DETAIL)
	# Underside teeth — glow orange when about to slam (last 0.4s of idle).
	var teeth_color: Color = _COLOR_DETAIL
	if _phase == Phase.IDLE and _phase_t >= idle_time - 0.4:
		teeth_color = _COLOR_DANGER
	# Three downward triangles along the bottom edge.
	for i in range(3):
		var x: float = -size.x * 0.5 + 6.0 + float(i) * (size.x - 12.0) / 2.0
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x - 4.0, size.y * 0.5),
			Vector2(x, size.y * 0.5 + 6.0),
			Vector2(x + 4.0, size.y * 0.5),
		])
		draw_polygon(pts, PackedColorArray([teeth_color]))

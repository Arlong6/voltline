## Voltline — short-lived particle burst (death FX).
##
## Spawns `count` 2×2 squares with random outward velocities + light gravity.
## Particles fade out linearly across `duration` seconds, then the whole
## burst queue_free's itself. Stateless tick(delta) lets tests drive it
## without a SceneTree timer.
class_name ParticleBurst
extends Node2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

@export var color: Color = Color("#FFFFFF")
@export var count: int = 8
@export var duration: float = 0.55
@export var speed_min: float = 40.0
@export var speed_max: float = 100.0
@export var gravity: float = 220.0

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _t: float = 0.0


func _ready() -> void:
	# Sample initial velocities at random angles.
	for i in count:
		var angle: float = randf() * TAU
		var speed: float = randf_range(speed_min, speed_max)
		_positions.append(Vector2.ZERO)
		_velocities.append(Vector2(cos(angle) * speed, sin(angle) * speed))


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	tick(delta)
	queue_redraw()
	if _t >= duration:
		queue_free()


## Pure-logic step. Tests call this directly with synthesized deltas.
func tick(delta: float) -> void:
	_t += delta
	for i in _positions.size():
		_positions[i] += _velocities[i] * delta
		_velocities[i].y += gravity * delta


func _draw() -> void:
	var alpha: float = clampf(1.0 - _t / duration, 0.0, 1.0)
	var draw_color: Color = Color(color.r, color.g, color.b, alpha)
	for p in _positions:
		draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 2.0, 2.0), draw_color)

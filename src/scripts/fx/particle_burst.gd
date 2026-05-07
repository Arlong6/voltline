## Lightweight particle burst effect.
## Spawns N small squares with randomized velocity and optional gravity,
## fades out over lifetime, then queue_frees itself. Rendered via _draw for
## pixel-crisp output (no sprites required).
##
## Usage (inline spawn):
##   var burst: ParticleBurst = ParticleBurst.new()
##   burst.position = global_spawn_pos
##   burst.count = 6
##   burst.color = Color("#F2A227")
##   parent.add_child(burst)
##
## NOTE: randf() is used during _ready — output is non-deterministic.
## Keep this off the hot test path.
class_name ParticleBurst
extends Node2D

# ---------------------------------------------------------------------------
# Exports (tweak per use site)
# ---------------------------------------------------------------------------

## Number of particles to emit.
@export var count: int = 6
## Base colour for all particles. Alpha is driven by lifetime.
@export var color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Minimum speed (px/s) picked at spawn.
@export var speed_min: float = 40.0
## Maximum speed (px/s) picked at spawn.
@export var speed_max: float = 100.0
## Edge length of each particle square (px).
@export var particle_size: float = 2.0
## Total burst lifetime (s). Particles die and node frees at the end.
@export var lifetime: float = 0.45
## Scales the downward gravity acceleration (0 = no gravity, 1 = normal fall).
@export var gravity_scale: float = 1.0
## Upward bias applied to spawn direction. 0 = omnidirectional, 1 = pure up.
@export var upward_bias: float = 0.4

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const FALL_GRAVITY: float = 300.0

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _positions: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
var _elapsed: float = 0.0

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	_positions.resize(count)
	_velocities.resize(count)
	for i in count:
		var angle: float = randf() * TAU
		var speed: float = randf_range(speed_min, speed_max)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		# Bias upward: shift y component (negative = up in screen space).
		dir.y -= upward_bias
		if dir.length() > 0.0001:
			dir = dir.normalized()
		_positions[i] = Vector2.ZERO
		_velocities[i] = dir * speed


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	for i in count:
		var v: Vector2 = _velocities[i]
		v.y += FALL_GRAVITY * gravity_scale * delta
		_velocities[i] = v
		_positions[i] += v * delta
	queue_redraw()


func _draw() -> void:
	var life_pct: float = clampf(1.0 - (_elapsed / lifetime), 0.0, 1.0)
	var c: Color = color
	c.a = color.a * life_pct
	var half: float = particle_size / 2.0
	for i in count:
		var p: Vector2 = _positions[i]
		draw_rect(
			Rect2(roundf(p.x) - half, roundf(p.y) - half, particle_size, particle_size),
			c
		)

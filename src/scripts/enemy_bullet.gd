## Voltline — enemy projectile (V-011 boss support).
##
## Constant-velocity Area2D fired by the boss (and future shooting enemies).
## Travels in `velocity` until it has covered MAX_TRAVEL pixels or hits the
## player; deals `damage` to the player on contact.
class_name EnemyBullet
extends Area2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Maximum pixels of travel before the bullet despawns.
const MAX_TRAVEL: float = 400.0

## Damage applied to player on contact. v0.58: 3 → 2 to match the
## softened contact_damage curve.
@export var damage: int = 2

# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

const _BULLET_COLOR: Color = Color("#FF6040")
const _BULLET_SIZE: Vector2 = Vector2(6.0, 6.0)

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## World-space velocity vector. Set by the boss (or other shooter) on spawn
## before the bullet enters the tree.
var velocity: Vector2 = Vector2.ZERO

## Downward acceleration (px/s²). Default 0 = straight-line shot. The
## Spitter sets this positive so its lob arcs over cover. Named
## `gravity_accel` (not `gravity`) so we don't shadow Area2D's own
## `gravity` property — Godot rejects the shadowed name from outside.
var gravity_accel: float = 0.0

# Cumulative absolute distance travelled — drives expiry.
var _distance_traveled: float = 0.0

# ---------------------------------------------------------------------------
# Frame loop
# ---------------------------------------------------------------------------

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	tick(delta)
	if is_expired():
		queue_free()


## Pure-logic position step. Tests call this directly. Applies gravity to
## `velocity.y` first (0 by default → straight line), then advances.
func tick(delta: float) -> void:
	if gravity_accel != 0.0:
		velocity.y += gravity_accel * delta
	var step: Vector2 = velocity * delta
	position += step
	_distance_traveled += step.length()


## True once the bullet has travelled MAX_TRAVEL pixels.
func is_expired() -> bool:
	return _distance_traveled >= MAX_TRAVEL


# Despawns on any body contact. Damages the player if that's who we hit.
func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode:
		return
	if body is Player:
		body.take_damage(damage)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(-_BULLET_SIZE * 0.5, _BULLET_SIZE), _BULLET_COLOR)

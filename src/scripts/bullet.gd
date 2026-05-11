## Voltline — player buster bullet (V-003 + V-006).
##
## Constant-velocity horizontal projectile spawned by Player on the rising
## edge of `shoot` (V-003 normal tap) or on the falling edge of a fully
## charged hold (V-006 charge shot). Despawns once it has travelled
## MAX_TRAVEL pixels from spawn — distance-based expiry is independent
## of camera or stage layout, so bullets fire correctly anywhere in the
## scrolling stage.
##
## Uses Area2D so future collision wiring (V-008 enemies) can hook into
## body_entered / area_entered without changing the node type.
##
## Game.test_mode short-circuits _process so unit tests can drive tick()
## directly with synthesized deltas.
class_name Bullet
extends Area2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Pixel-per-second travel speed for a normal (uncharged) bullet.
const SPEED_NORMAL: float = 240.0

## Pixel-per-second travel speed for a Lv1 charged bullet.
const SPEED_CHARGED: float = 280.0

## Pixel-per-second travel speed for a Lv2 super-charged bullet.
const SPEED_SUPER: float = 320.0

## Maximum pixels of travel before the bullet despawns.
const MAX_TRAVEL: float = 600.0

# ---------------------------------------------------------------------------
# Visuals — separate look per charge level
# ---------------------------------------------------------------------------

const _SIZE_NORMAL: Vector2 = Vector2(6.0, 4.0)
const _SIZE_CHARGED: Vector2 = Vector2(12.0, 8.0)
const _SIZE_SUPER: Vector2 = Vector2(18.0, 12.0)

const _COLOR_NORMAL: Color = Color("#A8E0FF")
const _COLOR_CHARGED: Color = Color("#FFE066")
const _COLOR_SUPER: Color = Color("#FF8030")

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## -1 = travelling left, 1 = travelling right. Set by Player on spawn.
var direction: int = 1

## 0 = normal tap shot, 1 = fully charged buster shot. Set by Player on
## spawn before the bullet enters the tree.
var charge_level: int = 0

# Cumulative absolute distance travelled — drives expiry independently of
# the absolute world x position.
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


# Despawns the bullet on contact with any body. Damage scales with
# charge level: Lv0 = 1, Lv1 = 2, Lv2 = 4.
#
# Lv2 (super) bullets pierce through enemies AND through any
# destructible wall they break (so a single super shot can blow open a
# hidden room and clip the enemy waiting inside).
func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode:
		return
	if body is Enemy and body.is_alive:
		body.take_damage(damage_for_level())
		# Hit-stop + camera shake on impact — bigger for Lv2 super,
		# regular for Lv1, none for Lv0 (so rapid-fire stays snappy).
		if charge_level >= 2:
			Game.hit_stop(0.10, 0.02)
			Game.request_shake(3.0)
		elif charge_level >= 1:
			Game.hit_stop(0.05, 0.15)
			Game.request_shake(1.5)
		if charge_level >= 2:
			return  # piercing — keep flying
	elif body is DestructibleWall and not body.is_destroyed:
		body.take_damage(damage_for_level())
		if body.is_destroyed:
			Game.hit_stop(0.10, 0.02)
		# Pierce on Lv2 — only if our shot was the one that broke it.
		if charge_level >= 2 and body.is_destroyed:
			return
	queue_free()


## Damage value for the bullet's charge level. Exposed so tests can
## assert the table without poking at private constants.
func damage_for_level() -> int:
	if charge_level >= 2:
		return 4
	if charge_level >= 1:
		return 2
	return 1


## Pure-logic position step. Tests call this directly with a synthesized
## delta — no SceneTree, no real frame loop required.
func tick(delta: float) -> void:
	var dx: float = float(direction) * speed() * delta
	position.x += dx
	_distance_traveled += absf(dx)


## Per-level travel speed accessor. Tests can read this without touching
## the internal SPEED constants.
func speed() -> float:
	if charge_level >= 2:
		return SPEED_SUPER
	if charge_level >= 1:
		return SPEED_CHARGED
	return SPEED_NORMAL


## True once the bullet has travelled MAX_TRAVEL pixels from its spawn
## position. Side-effect-free so tests can assert on it.
func is_expired() -> bool:
	return _distance_traveled >= MAX_TRAVEL


func _draw() -> void:
	var size: Vector2
	var color: Color
	if charge_level >= 2:
		size = _SIZE_SUPER
		color = _COLOR_SUPER
	elif charge_level >= 1:
		size = _SIZE_CHARGED
		color = _COLOR_CHARGED
	else:
		size = _SIZE_NORMAL
		color = _COLOR_NORMAL
	draw_rect(Rect2(-size * 0.5, size), color)

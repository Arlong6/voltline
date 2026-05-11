## Voltline — destructible wall hiding a treasure alcove (v0.60).
##
## Static block that LOOKS like normal wall geometry but with hairline
## cracks. Only takes "real" damage from a Lv2 super charge shot
## (≥ min_break_damage); lesser hits play a ping sound + screen shake
## so the player knows the wall registered the hit but isn't enough.
##
## Once destroyed, the collision_layer drops to 0 so the player can walk
## through, the visual hides, a particle burst pops, and the wall
## queue_free's after a short grace period (so the bullet that broke it
## can finish its hit handler).
class_name DestructibleWall
extends StaticBody2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Damage threshold to break the wall in a single hit. Default 4 matches
## the Lv2 super-charge bullet exactly so only that level qualifies.
@export var min_break_damage: int = 4

## Visual size — drawn as a single rect centred on the body.
@export var size: Vector2 = Vector2(24.0, 24.0)

## Visual color — defaults to a slightly desaturated stone-grey so the
## block reads as "this is breakable", not regular level geometry.
@export var color: Color = Color("#5A5060")

const _COLOR_CRACK: Color = Color("#1A1018")
const _COLOR_HIGHLIGHT: Color = Color("#7A6878")
const _COLOR_BURST: Color = Color("#A09080")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## True after the wall has been broken. Tests can read this directly.
var is_destroyed: bool = false

# Brief shake offset applied on a sub-threshold hit so the player gets
# feedback that the bullet registered.
var _shake_timer: float = 0.0
const _SHAKE_DURATION: float = 0.12
const _SHAKE_AMPLITUDE: float = 1.5


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	if _shake_timer > 0.0:
		_shake_timer = maxf(_shake_timer - delta, 0.0)
		queue_redraw()


## Bullet damage handler. Called by Bullet._on_body_entered when the
## projectile hits this wall. Sub-threshold hits register but do not
## chip — Lv2 super-charge is mandatory to break.
func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	if amount >= min_break_damage:
		destroy()
	else:
		_shake_timer = _SHAKE_DURATION
		if not Game.test_mode:
			Sfx.play("enemy_hit")


## Public so tests / cheats can trigger directly.
func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	# Walls are on layer 1 (World) by default — drop to 0 so the player
	# walks through. Hide the visual.
	collision_layer = 0
	visible = false
	Game.register_wall_break()
	if not Game.test_mode:
		_spawn_break_particles()
		Sfx.play("explode")
	# Free on the next frame so the bullet's hit handler completes first.
	call_deferred("queue_free")


func _spawn_break_particles() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.color = _COLOR_BURST
	burst.count = 16
	burst.duration = 0.6
	burst.speed_min = 60.0
	burst.speed_max = 160.0
	burst.gravity = 280.0
	burst.global_position = global_position
	parent.add_child(burst)


func _draw() -> void:
	if is_destroyed:
		return
	var offset: Vector2 = Vector2.ZERO
	if _shake_timer > 0.0:
		var pulse: float = sin(_shake_timer * 80.0)
		offset = Vector2(pulse * _SHAKE_AMPLITUDE, 0.0)
	var rect: Rect2 = Rect2(-size * 0.5 + offset, size)
	draw_rect(rect, color)
	# Top highlight strip — a hint that this isn't a normal wall.
	draw_rect(Rect2(-size.x * 0.5 + offset.x, -size.y * 0.5 + offset.y, size.x, 2.0),
		_COLOR_HIGHLIGHT)
	# Hairline cracks — a diagonal + a Y-fork so the player reads "this
	# can be broken" if they look closely.
	var c: Color = _COLOR_CRACK
	var cx: float = offset.x
	var cy: float = offset.y
	# Main diagonal crack from upper-left toward lower-right.
	draw_line(Vector2(-size.x * 0.5 + 4.0 + cx, -size.y * 0.5 + 6.0 + cy),
		Vector2(2.0 + cx, 2.0 + cy), c, 1.0)
	# Branch crack downward.
	draw_line(Vector2(2.0 + cx, 2.0 + cy),
		Vector2(-2.0 + cx, size.y * 0.5 - 4.0 + cy), c, 1.0)
	# Branch crack rightward.
	draw_line(Vector2(2.0 + cx, 2.0 + cy),
		Vector2(size.x * 0.5 - 4.0 + cx, 6.0 + cy), c, 1.0)

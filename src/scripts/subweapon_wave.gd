## Voltline — sine-wave piercing shot sub-weapon (v0.67).
##
## Travels horizontally in the player's facing direction at SPEED, with
## a sine-wave vertical offset (±AMPLITUDE_Y, period PERIOD). Pierces
## every Enemy it touches (no despawn on enemy hit) but tracks who it's
## already hit so the same enemy can't take damage twice from one cast.
## Despawns on wall hit or after MAX_TRAVEL pixels.
##
## Spawned by Player when SHIFT fires with equipped_subweapon ==
## SUBWEAPON_WAVE.
class_name SubweaponWave
extends Area2D

const SPEED: float = 160.0
const MAX_TRAVEL: float = 360.0
const AMPLITUDE_Y: float = 24.0
const PERIOD: float = 0.6

const _COLOR_HEAD: Color = Color("#80FFE0")
const _COLOR_TRAIL: Color = Color("#40C0A0")
const _SIZE: Vector2 = Vector2(8.0, 8.0)

const DAMAGE: int = 2

## Horizontal direction sign: +1 = travelling right, -1 = travelling left.
## Set by Player on spawn (from facing).
var direction: int = 1

# Anchor y captured on _ready — the sine offset is added to this so the
# wave doesn't drift permanently.
var _anchor_y: float = 0.0
var _life_t: float = 0.0
var _distance_traveled: float = 0.0
var _trail: PackedVector2Array = PackedVector2Array()
var _already_hit: Array[Enemy] = []


func _ready() -> void:
	_anchor_y = global_position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	tick(delta)
	queue_redraw()
	if is_expired():
		queue_free()


## Pure-logic step. Advances horizontally, recomputes vertical sine
## offset from `_life_t`. Tests drive this directly.
func tick(delta: float) -> void:
	var dx: float = float(direction) * SPEED * delta
	position.x += dx
	_distance_traveled += absf(dx)
	_life_t += delta
	# Sine offset around the anchor y.
	var sin_y: float = sin((_life_t / PERIOD) * TAU) * AMPLITUDE_Y
	global_position.y = _anchor_y + sin_y
	_trail.append(position)
	if _trail.size() > 8:
		_trail.remove_at(0)


func is_expired() -> bool:
	return _distance_traveled >= MAX_TRAVEL


# Public so tests can introspect the de-dup tracking.
func has_hit(enemy: Enemy) -> bool:
	return _already_hit.has(enemy)


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode:
		return
	if body is Enemy and body.is_alive:
		_hit_enemy(body)
	# Walls are StaticBody2D on layer 1 — pierce-through stops there.
	elif body is StaticBody2D:
		queue_free()


func _hit_enemy(enemy: Enemy) -> void:
	if _already_hit.has(enemy):
		return
	_already_hit.append(enemy)
	enemy.take_damage(DAMAGE, global_position)
	Game.hit_stop(0.04, 0.20)
	Game.request_shake(1.2)


func _draw() -> void:
	# Trail — fading line from oldest sample to current head.
	for i in range(_trail.size() - 1):
		var alpha: float = float(i + 1) / float(_trail.size())
		var c: Color = Color(_COLOR_TRAIL.r, _COLOR_TRAIL.g, _COLOR_TRAIL.b,
			alpha * 0.6)
		draw_line(_trail[i] - global_position, _trail[i + 1] - global_position,
			c, 2.0)
	# Head — a small filled diamond.
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(_SIZE.x * 0.5, 0.0),
		Vector2(0.0, _SIZE.y * 0.5),
		Vector2(-_SIZE.x * 0.5, 0.0),
		Vector2(0.0, -_SIZE.y * 0.5),
	])
	draw_polygon(pts, PackedColorArray([_COLOR_HEAD]))

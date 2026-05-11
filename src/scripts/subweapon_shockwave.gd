## Voltline — shockwave sub-weapon (v0.64).
##
## Instant radial AoE centred on the player. Expanding ring grows from
## 0 to MAX_RADIUS over EXPAND_TIME seconds. Damages any Enemy whose
## position is within the current ring radius (once per enemy — tracked
## in `_already_hit` so the ring sweeping past doesn't multi-tick).
##
## Spawned by Player when SHIFT fires the equipped sub-weapon if
## equipped_subweapon == SUBWEAPON_SHOCKWAVE.
class_name SubweaponShockwave
extends Node2D

const MAX_RADIUS: float = 96.0
const EXPAND_TIME: float = 0.32

const _COLOR_RING: Color = Color("#7AC8FF")
const _COLOR_INNER: Color = Color("#FFFFFF")

const DAMAGE: int = 2

var _t: float = 0.0
var _already_hit: Array[Enemy] = []


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	tick(delta)
	queue_redraw()
	if _t >= EXPAND_TIME:
		queue_free()


## Pure-logic step. Tests drive directly with synthesized deltas.
func tick(delta: float) -> void:
	_t += delta
	var radius: float = current_radius()
	# Scan parent's children for Enemy nodes within the current ring.
	var parent: Node = get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is Enemy and child.is_alive and not _already_hit.has(child):
			var d: float = (child.global_position - global_position).length()
			if d <= radius:
				child.take_damage(DAMAGE)
				_already_hit.append(child)
				if not Game.test_mode:
					Game.hit_stop(0.04, 0.15)


## Current ring radius from the elapsed time. Tests use this to assert
## the expansion curve hits MAX_RADIUS by EXPAND_TIME.
func current_radius() -> float:
	var alpha: float = clampf(_t / EXPAND_TIME, 0.0, 1.0)
	return MAX_RADIUS * alpha


func _draw() -> void:
	var r: float = current_radius()
	if r <= 0.0:
		return
	var alpha: float = 1.0 - clampf(_t / EXPAND_TIME, 0.0, 1.0)
	# Outer ring (thicker, primary).
	var ring_color: Color = Color(_COLOR_RING.r, _COLOR_RING.g, _COLOR_RING.b,
		alpha * 0.85)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, ring_color, 3.0, true)
	# Inner glow (thinner white).
	var inner_color: Color = Color(_COLOR_INNER.r, _COLOR_INNER.g, _COLOR_INNER.b,
		alpha * 0.5)
	draw_arc(Vector2.ZERO, r * 0.85, 0.0, TAU, 32, inner_color, 1.0, true)

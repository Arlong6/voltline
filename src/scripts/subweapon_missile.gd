## Voltline — homing missile sub-weapon (v0.64).
##
## Slow Area2D projectile that locks onto the nearest enemy and curves
## toward it at a limited turn rate. 3 damage on contact, no piercing.
## Despawns on enemy hit, on wall hit, or after MAX_TRAVEL pixels.
##
## Spawned by Player when SHIFT fires the equipped sub-weapon if
## equipped_subweapon == SUBWEAPON_MISSILE.
class_name SubweaponMissile
extends Area2D

const SPEED: float = 140.0
const MAX_TRAVEL: float = 700.0
const TURN_RATE_DEG: float = 270.0  # max degrees per second toward target

const _COLOR_BODY: Color = Color("#E8E8F2")
const _COLOR_TRAIL: Color = Color("#FFB060")
const _SIZE: Vector2 = Vector2(10.0, 5.0)

const DAMAGE: int = 3

## Initial firing direction (set by Player on spawn). The missile starts
## flying this way and gradually curves toward the locked target.
var direction: Vector2 = Vector2.RIGHT

var _velocity: Vector2 = Vector2.ZERO
var _distance_traveled: float = 0.0
var _trail: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_velocity = direction * SPEED
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	tick(delta)
	queue_redraw()
	if is_expired():
		queue_free()


## Pure-logic step. Tests drive directly.
func tick(delta: float) -> void:
	# Re-acquire nearest enemy each tick — cheap (typical stage has <10 alive).
	var target: Node2D = _find_nearest_enemy()
	if target != null:
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() > 0.5:
			var current_angle: float = _velocity.angle()
			var target_angle: float = to_target.angle()
			var max_step: float = deg_to_rad(TURN_RATE_DEG) * delta
			var new_angle: float = lerp_angle(current_angle, target_angle, 1.0)
			# Clamp angular delta to max_step.
			var delta_angle: float = wrapf(new_angle - current_angle, -PI, PI)
			delta_angle = clampf(delta_angle, -max_step, max_step)
			_velocity = Vector2.RIGHT.rotated(current_angle + delta_angle) * SPEED
	var step: Vector2 = _velocity * delta
	position += step
	_distance_traveled += step.length()
	# Trail samples — push current position every tick, cap at 6 samples.
	_trail.append(position)
	if _trail.size() > 6:
		_trail.remove_at(0)


func _find_nearest_enemy() -> Node2D:
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	if tree == null:
		return null
	var best: Node2D = null
	var best_d2: float = INF
	var enemies: Array[Node] = tree.get_nodes_in_group("enemy")
	# Fallback — Enemy class doesn't add itself to a group, so scan
	# siblings of parent for Enemy nodes.
	var parent: Node = get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is Enemy and child.is_alive:
				var d2: float = (child.global_position - global_position).length_squared()
				if d2 < best_d2:
					best_d2 = d2
					best = child
	return best


func is_expired() -> bool:
	return _distance_traveled >= MAX_TRAVEL


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode:
		return
	if body is Enemy and body.is_alive:
		body.take_damage(DAMAGE)
		Game.hit_stop(0.08, 0.05)
		Game.request_shake(2.0)
	# Despawn on any solid contact (wall or enemy).
	queue_free()


func _draw() -> void:
	# Trail — fading line from oldest sample to current position.
	for i in range(_trail.size() - 1):
		var alpha: float = float(i + 1) / float(_trail.size())
		var c: Color = Color(_COLOR_TRAIL.r, _COLOR_TRAIL.g, _COLOR_TRAIL.b,
			alpha * 0.6)
		draw_line(_trail[i] - global_position, _trail[i + 1] - global_position,
			c, 2.0)
	# Missile body — small forward-pointing triangle aligned to velocity.
	var angle: float = _velocity.angle()
	var tip: Vector2 = Vector2.RIGHT.rotated(angle) * _SIZE.x * 0.5
	var back_left: Vector2 = Vector2(-_SIZE.x * 0.5, -_SIZE.y * 0.5).rotated(angle)
	var back_right: Vector2 = Vector2(-_SIZE.x * 0.5, _SIZE.y * 0.5).rotated(angle)
	var pts: PackedVector2Array = PackedVector2Array([tip, back_left, back_right])
	draw_polygon(pts, PackedColorArray([_COLOR_BODY]))

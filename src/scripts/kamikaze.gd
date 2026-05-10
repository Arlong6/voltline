## Voltline — flying kamikaze drone.
##
## Inherits Enemy. Ignores patrol bounds: when the player is within
## `aggro_range`, the kamikaze homes directly toward them at
## `home_speed`. On contact (or HP zero) it triggers a brief expanding
## blast that does heavy damage to whatever is inside.
##
## Until aggroed, it idles bobbing on `hover_y` like a Drone but
## without shooting.
class_name Kamikaze
extends "res://scripts/enemy.gd"

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Idle-mode hover Y. Set on spawn.
@export var hover_y: float = 80.0

## Range at which the kamikaze locks onto the player and starts homing.
@export var aggro_range: float = 140.0

## Speed in homing mode (px/s, applied to the unit vector toward the player).
@export var home_speed: float = 110.0

## Bob amplitude / frequency while idle.
@export var bob_amplitude: float = 4.0
@export var bob_frequency: float = 1.6

# ---------------------------------------------------------------------------
# Visuals — sharp, predator-red triangle silhouette
# ---------------------------------------------------------------------------

const _KAMI_COLOR_BODY: Color = Color("#C04030")
const _KAMI_COLOR_BODY_HIT: Color = Color("#FFE0E0")
const _KAMI_COLOR_FIN: Color = Color("#902020")
const _KAMI_COLOR_EYE: Color = Color("#FFD040")
const _KAMI_COLOR_EYE_AGGRO: Color = Color("#FFFFFF")
const _KAMI_COLOR_BLAST: Color = Color("#FF6020")

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _is_homing: bool = false
var _bob_phase: float = 0.0


func _ready() -> void:
	# v0.56 defaults — fragile but dangerous: 3 HP.
	if max_hp == 2:
		max_hp = 3
	hp = max_hp
	if hover_y == 80.0 and absf(global_position.y - 80.0) > 0.5:
		hover_y = global_position.y


## Pure-logic homing step. Detects player; idles in bob-mode if no aggro,
## homes toward the player otherwise. Velocity.y is overridden completely
## so gravity does not apply to a kamikaze.
func tick_movement(delta: float, _on_wall: bool = false) -> void:
	_bob_phase += delta * bob_frequency * TAU

	var player: Node2D = null
	if is_inside_tree():
		player = get_tree().get_first_node_in_group("player")

	if player != null:
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length() <= aggro_range:
			_is_homing = true
			direction = 1 if to_player.x > 0.0 else -1
			var unit: Vector2 = to_player.normalized()
			velocity = unit * home_speed
			return
		else:
			_is_homing = false

	# Idle bob — patrol horizontally between bounds, ride sine on Y.
	var hit_max: bool = direction > 0 and global_position.x >= patrol_max_x
	var hit_min: bool = direction < 0 and global_position.x <= patrol_min_x
	if hit_max or hit_min:
		direction = -direction
	velocity.x = float(direction) * walk_speed
	var target_y: float = hover_y + sin(_bob_phase) * bob_amplitude
	velocity.y = (target_y - global_position.y) * 6.0


# Override Enemy.die so the kamikaze also produces a blast on death.
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	hp = 0
	Game.register_kill()
	if not Game.test_mode:
		_spawn_blast()
		Sfx.play("explode")
		if randf() < 0.30:
			_drop_health()
		else:
			_drop_coins(1, 8.0)
	queue_free()


# Brief expanding blast — visual + damage burst centred on the kamikaze.
# The blast is implemented as a ParticleBurst (for the visual) plus a
# directly-applied take_damage(2) on the player if they're within 24 px.
func _spawn_blast() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	# Visual ring of orange particles.
	var burst: ParticleBurst = ParticleBurst.new()
	burst.color = _KAMI_COLOR_BLAST
	burst.count = 14
	burst.duration = 0.45
	burst.speed_min = 80.0
	burst.speed_max = 180.0
	burst.gravity = 80.0
	burst.global_position = global_position
	parent.add_child(burst)
	# Damage check — short-range AoE.
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null and (player.global_position - global_position).length() <= 24.0:
		if player.has_method("take_damage"):
			player.take_damage(2)


func _draw() -> void:
	var body_color: Color = _KAMI_COLOR_BODY_HIT if _hit_flash_timer > 0.0 else _KAMI_COLOR_BODY
	# Triangular forward-pointing silhouette.
	var tip_x: float = 8.0 if direction > 0 else -8.0
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(tip_x, 0.0),
		Vector2(-tip_x * 0.6, -5.0),
		Vector2(-tip_x * 0.6, 5.0),
	])
	draw_polygon(pts, PackedColorArray([body_color]))
	# Tail fins.
	draw_rect(Rect2(-tip_x * 0.6 - 2.0, -2.0, 2.0, 4.0), _KAMI_COLOR_FIN)
	# Eye / sensor — flashes white when homing.
	var eye_color: Color = _KAMI_COLOR_EYE_AGGRO if _is_homing else _KAMI_COLOR_EYE
	draw_rect(Rect2(tip_x * 0.4 - 1.0, -1.0, 2.0, 2.0), eye_color)

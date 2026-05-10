## Voltline — heavy charging brute enemy.
##
## Inherits Enemy's HP / damage / drop pipeline. Differs from the base
## sweeper: when the player is within `aggro_range`, the brute switches
## from idle patrol to a CHARGE state, accelerating toward the player at
## `charge_speed` until it loses sight or a wall stops it. Slams shake
## the camera and deal heavy contact damage on hit.
class_name Brute
extends "res://scripts/enemy.gd"

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Pixel range at which the brute spots the player and starts charging.
@export var aggro_range: float = 160.0

## Multiplier applied to walk_speed when charging. 2.0 = "twice as fast
## as patrol speed" — fast enough that double-jumping over feels like the
## intended counter.
@export var charge_speed_multiplier: float = 2.0

## Seconds the brute remains in charge state after losing line of sight.
## Prevents flickery state changes when the player ducks behind cover.
@export var charge_persist: float = 0.7

# ---------------------------------------------------------------------------
# Visuals — wider, taller silhouette than a regular grunt
# ---------------------------------------------------------------------------

const _BRUTE_COLOR_BODY: Color = Color("#7A2030")
const _BRUTE_COLOR_BODY_HIT: Color = Color("#FFE0E0")
const _BRUTE_COLOR_PLATE: Color = Color("#A03040")
const _BRUTE_COLOR_EYE: Color = Color("#FFC040")
const _BRUTE_COLOR_EYE_CHARGE: Color = Color("#FF3030")
const _BRUTE_COLOR_LEGS: Color = Color("#481018")

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _is_charging: bool = false
var _charge_persist_timer: float = 0.0


func _ready() -> void:
	# v0.56 spawn defaults — heavy: 12 HP, slow patrol, BIG charge.
	if max_hp == 2:  # Enemy default — brute spawn didn't override
		max_hp = 12
	hp = max_hp
	if walk_speed == 30.0:  # Enemy default
		walk_speed = 35.0


## Pure-logic patrol + charge step. Switches to charge when the player is
## within `aggro_range` (any vertical offset within ±60 px); reverses on
## wall hit while charging just like patrol mode. Tests drive this directly.
func tick_movement(delta: float, on_wall: bool = false) -> void:
	_charge_persist_timer = maxf(_charge_persist_timer - delta, 0.0)

	var player: Node2D = null
	if is_inside_tree():
		player = get_tree().get_first_node_in_group("player")

	# Aggro detection — line-of-sight is generous (no ray casts), just an
	# Euclidean range check on the horizontal axis with a vertical band.
	if player != null:
		var dx: float = player.global_position.x - global_position.x
		var dy: float = absf(player.global_position.y - global_position.y)
		var horizontal_range: float = absf(dx)
		if horizontal_range <= aggro_range and dy <= 60.0:
			_is_charging = true
			_charge_persist_timer = charge_persist
			# Face the player — overrides patrol direction.
			direction = 1 if dx > 0.0 else -1
		elif _charge_persist_timer <= 0.0:
			_is_charging = false

	# Wall + bound logic — brutes still bounce off walls while charging,
	# otherwise they get stuck on geometry forever.
	var hit_max: bool = direction > 0 and global_position.x >= patrol_max_x
	var hit_min: bool = direction < 0 and global_position.x <= patrol_min_x
	if on_wall or (not _is_charging and (hit_max or hit_min)):
		direction = -direction

	var speed: float = walk_speed
	if _is_charging:
		speed = walk_speed * charge_speed_multiplier
	velocity.x = float(direction) * speed
	velocity.y = minf(velocity.y + gravity * delta, terminal_velocity)


func _draw() -> void:
	var body_color: Color = _BRUTE_COLOR_BODY_HIT if _hit_flash_timer > 0.0 else _BRUTE_COLOR_BODY
	# Wide chest plate.
	draw_rect(Rect2(-10.0, -8.0, 20.0, 12.0), body_color)
	# Top shoulder plates — thicker than a grunt.
	draw_rect(Rect2(-12.0, -10.0, 24.0, 4.0), _BRUTE_COLOR_PLATE)
	# Single big eye in the middle of the body, glows red while charging.
	var eye_color: Color = _BRUTE_COLOR_EYE_CHARGE if _is_charging else _BRUTE_COLOR_EYE
	var eye_x: float = 2.0 if direction > 0 else -6.0
	draw_rect(Rect2(eye_x, -4.0, 4.0, 3.0), eye_color)
	# Two heavy legs.
	draw_rect(Rect2(-7.0, 4.0, 4.0, 6.0), _BRUTE_COLOR_LEGS)
	draw_rect(Rect2(3.0, 4.0, 4.0, 6.0), _BRUTE_COLOR_LEGS)

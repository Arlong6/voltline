## Voltline — telegraphed-charge ground enemy (v0.68).
##
## Sister to the Brute, with a louder tell. State machine:
##
##   PATROL    — walking the patrol band like a base sweeper
##   TELEGRAPH — player spotted; eye flares red and the lancer stops
##               for `telegraph_duration` seconds before committing
##   CHARGE    — rushes toward the player at charge_speed for at most
##               `charge_duration` or until a wall stops it
##   COOLDOWN  — stops and pants for `cooldown_duration`; loops to PATROL
##
## The telegraph is the player's hint to jump or slide past — once CHARGE
## starts the lancer commits and is hard to dodge laterally.
##
## Pure-logic tick_movement(delta, player_pos, on_wall) lets tests drive
## the state machine without physics.
class_name Lancer
extends "res://scripts/enemy.gd"

const STATE_PATROL: int = 0
const STATE_TELEGRAPH: int = 1
const STATE_CHARGE: int = 2
const STATE_COOLDOWN: int = 3

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Pixel range at which the lancer locks onto the player and enters the
## TELEGRAPH state.
@export var aggro_range: float = 140.0

## Vertical band (±) for line-of-sight. Outside this band the lancer
## won't aggro.
@export var aggro_band_y: float = 50.0

## Seconds spent in TELEGRAPH before charging — the player's reaction window.
@export var telegraph_duration: float = 0.45

## Multiplier on walk_speed during CHARGE.
@export var charge_speed_multiplier: float = 4.0

## Max seconds in CHARGE before automatically transitioning to COOLDOWN.
@export var charge_duration: float = 1.0

## Seconds in COOLDOWN before looping back to PATROL.
@export var cooldown_duration: float = 1.2

# ---------------------------------------------------------------------------
# Visuals — bulky red silhouette with a forward-pointing lance
# ---------------------------------------------------------------------------

const _LA_BODY: Color = Color("#6E1A18")
const _LA_BODY_HIT: Color = Color("#FFE0E0")
const _LA_PLATE: Color = Color("#9E2A28")
const _LA_EYE: Color = Color("#FFC040")
const _LA_EYE_LOCK: Color = Color("#FF3030")
const _LA_LANCE: Color = Color("#D0D8E0")
const _LA_LEGS: Color = Color("#3A0A08")

# ---------------------------------------------------------------------------
# Public state — exposed so tests can introspect transitions.
# ---------------------------------------------------------------------------

## Current state — one of STATE_*.
var state: int = STATE_PATROL

# Per-state countdown — reused across states.
var _state_timer: float = 0.0


func _ready() -> void:
	if max_hp == 2:
		max_hp = 8
	hp = max_hp
	if walk_speed == 30.0:
		walk_speed = 40.0


## Pure-logic state-machine + movement step. Tests drive directly.
## Named `tick_state` (not `tick_movement`) so we don't clash with the
## Enemy base's tick_movement signature.
func tick_state(delta: float, player_pos: Vector2, on_wall: bool = false) -> void:
	_state_timer = maxf(_state_timer - delta, 0.0)

	# State transitions.
	match state:
		STATE_PATROL:
			if _is_player_in_aggro(player_pos):
				_enter_state(STATE_TELEGRAPH)
				direction = 1 if player_pos.x > global_position.x else -1
		STATE_TELEGRAPH:
			if _state_timer <= 0.0:
				_enter_state(STATE_CHARGE)
		STATE_CHARGE:
			if _state_timer <= 0.0 or on_wall:
				_enter_state(STATE_COOLDOWN)
		STATE_COOLDOWN:
			if _state_timer <= 0.0:
				_enter_state(STATE_PATROL)

	# Per-state velocity choice.
	var speed: float = 0.0
	match state:
		STATE_PATROL:
			# Patrol with bound reversal (Enemy.tick_movement does this
			# but we need to honor state — re-inline the logic here).
			var hit_max: bool = direction > 0 and global_position.x >= patrol_max_x
			var hit_min: bool = direction < 0 and global_position.x <= patrol_min_x
			if on_wall or hit_max or hit_min:
				direction = -direction
			speed = walk_speed
		STATE_TELEGRAPH:
			# Stand still during the tell.
			speed = 0.0
		STATE_CHARGE:
			speed = walk_speed * charge_speed_multiplier
		STATE_COOLDOWN:
			speed = 0.0

	velocity.x = float(direction) * speed
	velocity.y = minf(velocity.y + gravity * delta, terminal_velocity)


func _enter_state(new_state: int) -> void:
	state = new_state
	match new_state:
		STATE_PATROL:
			_state_timer = 0.0
		STATE_TELEGRAPH:
			_state_timer = telegraph_duration
		STATE_CHARGE:
			_state_timer = charge_duration
		STATE_COOLDOWN:
			_state_timer = cooldown_duration


func _is_player_in_aggro(player_pos: Vector2) -> bool:
	var dx: float = absf(player_pos.x - global_position.x)
	var dy: float = absf(player_pos.y - global_position.y)
	return dx <= aggro_range and dy <= aggro_band_y


func _physics_process(delta: float) -> void:
	if Game.test_mode or not is_alive:
		return
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	var player: Node2D = null
	if is_inside_tree():
		player = get_tree().get_first_node_in_group("player")
	var ppos: Vector2 = player.global_position if player != null else global_position
	tick_state(delta, ppos, is_on_wall())
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	var body_color: Color = _LA_BODY_HIT if _hit_flash_timer > 0.0 else _LA_BODY
	# Heavy chest.
	draw_rect(Rect2(-9.0, -8.0, 18.0, 12.0), body_color)
	# Shoulder plate.
	draw_rect(Rect2(-11.0, -10.0, 22.0, 4.0), _LA_PLATE)
	# Eye glows red during TELEGRAPH/CHARGE, otherwise amber.
	var eye_color: Color = _LA_EYE
	if state == STATE_TELEGRAPH or state == STATE_CHARGE:
		eye_color = _LA_EYE_LOCK
	var eye_x: float = 2.0 if direction > 0 else -5.0
	draw_rect(Rect2(eye_x, -4.0, 3.0, 3.0), eye_color)
	# Forward-pointing lance — extends during CHARGE for the visual punch.
	var lance_extend: float = 12.0 if state == STATE_CHARGE else 6.0
	var lance_x_start: float = 9.0 if direction > 0 else (-9.0 - lance_extend)
	draw_rect(Rect2(lance_x_start, -1.0, lance_extend, 2.0), _LA_LANCE)
	# Two heavy legs.
	draw_rect(Rect2(-6.0, 4.0, 4.0, 5.0), _LA_LEGS)
	draw_rect(Rect2(2.0, 4.0, 4.0, 5.0), _LA_LEGS)

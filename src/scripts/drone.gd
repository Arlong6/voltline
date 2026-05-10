## Voltline — flying drone enemy.
##
## Inherits Enemy's hp / take_damage / die / drop pipeline, but ignores
## gravity and patrols horizontally at a fixed hover_y. Fires
## EnemyBullets straight down (with a small lateral lead toward the
## player) on a fixed cadence — punishes the player for lingering
## under it.
class_name Drone
extends "res://scripts/enemy.gd"

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Pixel Y the drone hovers at. Set by the level when spawning.
@export var hover_y: float = 80.0

## Vertical drift amplitude for the bobbing visual.
@export var bob_amplitude: float = 4.0

## Vertical drift frequency (Hz).
@export var bob_frequency: float = 1.2

@export var shoot_interval: float = 1.6
@export var bullet_speed: float = 180.0
@export var bullet_initial_delay: float = 0.8

# ---------------------------------------------------------------------------
# Visuals — sleek gunmetal disc with a single red sensor
# ---------------------------------------------------------------------------

const _DRONE_COLOR_BODY: Color = Color("#404858")
const _DRONE_COLOR_BODY_HIT: Color = Color("#FFE0E0")
const _DRONE_COLOR_RING: Color = Color("#7A8898")
const _DRONE_COLOR_EYE: Color = Color("#FF4830")
const _DRONE_COLOR_THRUSTER: Color = Color("#FFB060")

const _BULLET_SCENE: PackedScene = preload("res://scenes/enemy_bullet.tscn")

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _shoot_timer: float = 0.0
var _bob_phase: float = 0.0


func _ready() -> void:
	hp = max_hp
	_shoot_timer = bullet_initial_delay
	# If hover_y wasn't explicitly set, latch to the spawn position.
	if hover_y == 80.0 and absf(global_position.y - 80.0) > 0.5:
		hover_y = global_position.y


func _physics_process(delta: float) -> void:
	if Game.test_mode or not is_alive:
		return
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	tick_movement(delta, is_on_wall())
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = shoot_interval
		_fire_at_player()
	move_and_slide()
	queue_redraw()


## Pure-logic hover step. Reverses direction at patrol bounds, sets
## velocity.x from direction × speed, and corrects velocity.y to ride
## the bobbing sine curve toward `hover_y`. Tests drive this directly.
func tick_movement(delta: float, on_wall: bool = false) -> void:
	var hit_max: bool = direction > 0 and global_position.x >= patrol_max_x
	var hit_min: bool = direction < 0 and global_position.x <= patrol_min_x
	if on_wall or hit_max or hit_min:
		direction = -direction

	velocity.x = float(direction) * walk_speed

	_bob_phase += delta * bob_frequency * TAU
	var target_y: float = hover_y + sin(_bob_phase) * bob_amplitude
	# Critically-damped pull toward the target so the drone settles even
	# if it spawns slightly off-line.
	velocity.y = (target_y - global_position.y) * 6.0


func _fire_at_player() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var aim: Vector2 = (player.global_position - global_position).normalized()
	# Bias toward downward — the drone's gun points beneath it.
	aim.y = maxf(aim.y, 0.4)
	aim = aim.normalized()
	var bullet: EnemyBullet = _BULLET_SCENE.instantiate() as EnemyBullet
	bullet.velocity = aim * bullet_speed
	bullet.global_position = global_position + Vector2(0.0, 4.0)
	get_parent().add_child(bullet)
	if not Game.test_mode:
		Sfx.play("shoot_enemy")


func _draw() -> void:
	var body_color: Color = _DRONE_COLOR_BODY_HIT if _hit_flash_timer > 0.0 else _DRONE_COLOR_BODY
	# Outer ring — slightly wider than the body.
	draw_rect(Rect2(-9.0, -3.0, 18.0, 6.0), _DRONE_COLOR_RING)
	# Main hull.
	draw_rect(Rect2(-7.0, -2.0, 14.0, 5.0), body_color)
	# Sensor eye — sweeps left/right with movement direction.
	var eye_x: float = 2.0 if direction > 0 else -4.0
	draw_rect(Rect2(eye_x, -1.0, 2.0, 2.0), _DRONE_COLOR_EYE)
	# Twin thrusters venting heat downward.
	draw_rect(Rect2(-5.0, 3.0, 2.0, 2.0), _DRONE_COLOR_THRUSTER)
	draw_rect(Rect2(3.0, 3.0, 2.0, 2.0), _DRONE_COLOR_THRUSTER)

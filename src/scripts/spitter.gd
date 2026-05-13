## Voltline — arcing lobber enemy (v0.66).
##
## Stationary like a Turret, but instead of a flat tracked shot it LOBS a
## gravity-affected EnemyBullet on a high arc — so it can drop rounds over
## low cover and onto a player who thinks a chest-high wall keeps them
## safe. Inherits Enemy's hp / take_damage / die / drop pipeline.
##
## The lob is ballistic: given the horizontal distance to the player and a
## fixed launch angle, it solves for the launch speed that lands the shot
## near the player's feet (clamped so absurd ranges don't fire railguns).
class_name Spitter
extends "res://scripts/enemy.gd"

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Seconds between lobs.
@export var shoot_interval: float = 2.8

## Delay before the first lob after spawning.
@export var bullet_initial_delay: float = 1.2

## Launch angle above horizontal, in degrees. 50° gives a satisfying arc
## that still travels a useful distance.
@export var launch_angle_deg: float = 50.0

## Downward accel applied to the lobbed bullet (px/s²).
@export var lob_gravity: float = 360.0

## Clamp on the solved launch speed so a distant player doesn't make the
## spitter fire a near-flat bullet.
@export var max_launch_speed: float = 240.0

# ---------------------------------------------------------------------------
# Visuals — squat mortar pot
# ---------------------------------------------------------------------------

const _SP_BASE: Color = Color("#5A4A6A")
const _SP_BASE_HIT: Color = Color("#FFE0E0")
const _SP_RIM: Color = Color("#8A78A0")
const _SP_MOUTH: Color = Color("#1A1424")
const _SP_EYE: Color = Color("#C080FF")

const _BULLET_SCENE: PackedScene = preload("res://scenes/enemy_bullet.tscn")

var _shoot_timer: float = 0.0


func _ready() -> void:
	if max_hp == 2:  # Enemy default — spawn didn't override
		max_hp = 4
	hp = max_hp
	_shoot_timer = bullet_initial_delay


func _physics_process(delta: float) -> void:
	if Game.test_mode or not is_alive:
		return
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	velocity.x = 0.0
	velocity.y = minf(velocity.y + gravity * delta, terminal_velocity)
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = shoot_interval
		_lob_at_player()
	move_and_slide()
	queue_redraw()


## Solves the ballistic launch velocity to drop a shot on the player and
## returns it. Pure math — tests call this directly. `target_x` /
## `target_y` are world coords; `self_pos` is the spitter's position.
## Falls back to a 45° max-speed toss toward the target if the geometry
## degenerates (target directly overhead, etc.).
func lob_velocity_for(self_pos: Vector2, target_x: float, target_y: float) -> Vector2:
	var dx: float = target_x - self_pos.x
	var dir: float = signf(dx)
	if dir == 0.0:
		dir = 1.0
	var theta: float = deg_to_rad(launch_angle_deg)
	var range_x: float = absf(dx)
	# R = v² · sin(2θ) / g  ⇒  v = sqrt(R · g / sin(2θ))
	var sin2: float = sin(2.0 * theta)
	var speed: float = max_launch_speed
	if sin2 > 0.001 and range_x > 1.0:
		speed = sqrt(range_x * lob_gravity / sin2)
		speed = clampf(speed, 0.0, max_launch_speed)
	return Vector2(cos(theta) * speed * dir, -sin(theta) * speed)


func _lob_at_player() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var bullet: EnemyBullet = _BULLET_SCENE.instantiate() as EnemyBullet
	bullet.gravity_accel = lob_gravity
	bullet.velocity = lob_velocity_for(
		global_position, player.global_position.x, player.global_position.y
	)
	bullet.global_position = global_position + Vector2(0.0, -6.0)
	get_parent().add_child.call_deferred(bullet)
	if not Game.test_mode:
		Sfx.play("shoot_enemy")


func _draw() -> void:
	var base_color: Color = _SP_BASE_HIT if _hit_flash_timer > 0.0 else _SP_BASE
	# Squat pot body, sitting on its bottom edge.
	draw_rect(Rect2(-8.0, -4.0, 16.0, 10.0), base_color)
	# Rim around the mouth.
	draw_rect(Rect2(-8.0, -7.0, 16.0, 3.0), _SP_RIM)
	# Dark mouth opening, angled toward the facing side.
	var mouth_x: float = -2.0 if direction >= 0 else -4.0
	draw_rect(Rect2(mouth_x, -8.0, 6.0, 3.0), _SP_MOUTH)
	# Glowing eye on the body.
	draw_rect(Rect2(-2.0, 0.0, 4.0, 3.0), _SP_EYE)

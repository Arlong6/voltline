## Voltline — stationary turret enemy.
##
## Inherits Enemy's hp / take_damage / die plumbing but never patrols —
## just gravity-falls onto whatever surface it spawns on, then fires
## tracked EnemyBullets at the player on a fixed cadence.
class_name Turret
extends "res://scripts/enemy.gd"

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

@export var shoot_interval: float = 2.5
@export var bullet_speed: float = 150.0
@export var bullet_initial_delay: float = 1.0

# ---------------------------------------------------------------------------
# Visuals — gun-mounted base
# ---------------------------------------------------------------------------

const _TURRET_BASE_COLOR: Color = Color("#806040")
const _TURRET_GUN_COLOR: Color = Color("#A07050")
const _TURRET_EYE_COLOR: Color = Color("#FF6040")
const _TURRET_HIT_COLOR: Color = Color("#FFE0E0")

const _BULLET_SCENE: PackedScene = preload("res://scenes/enemy_bullet.tscn")

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _shoot_timer: float = 0.0


func _ready() -> void:
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
		_fire_at_player()
	move_and_slide()
	queue_redraw()


func _fire_at_player() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var direction: Vector2 = (player.global_position - global_position).normalized()
	var bullet: EnemyBullet = _BULLET_SCENE.instantiate() as EnemyBullet
	bullet.velocity = direction * bullet_speed
	bullet.global_position = global_position
	get_parent().add_child(bullet)
	if not Game.test_mode:
		Sfx.play("shoot_enemy")


func _draw() -> void:
	var base_color: Color = _TURRET_HIT_COLOR if _hit_flash_timer > 0.0 else _TURRET_BASE_COLOR
	# Base — wider than tall, sits on its bottom edge.
	draw_rect(Rect2(-7.0, 0.0, 14.0, 6.0), base_color)
	# Gun barrel sticking up.
	draw_rect(Rect2(-2.0, -8.0, 4.0, 8.0), _TURRET_GUN_COLOR)
	# Targeting eye on the base.
	draw_rect(Rect2(-2.0, 2.0, 4.0, 2.0), _TURRET_EYE_COLOR)

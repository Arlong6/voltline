## Voltline — Stage 2 boss (V-010 + V-011 lite).
##
## Stationary CharacterBody2D miniboss that periodically fires a tracked
## EnemyBullet at the player. Inherits hp / take_damage / die from Enemy
## so player bullets damage it through the existing wiring; emits a
## `died` signal so the stage script can drive the clear flow.
##
## Behaviour: gravity pulls the boss to the floor on _ready; afterwards
## velocity.x = 0 (no patrol). Every `shoot_interval` seconds it aims at
## the current player position and spawns one EnemyBullet.
class_name Boss
extends "res://scripts/enemy.gd"

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Seconds between boss shots.
@export var shoot_interval: float = 0.9

## EnemyBullet velocity magnitude (px/s).
@export var bullet_speed: float = 180.0

## Initial delay before the boss's first shot, so the player has a beat
## to read the room after entering.
@export var bullet_initial_delay: float = 1.0

## Seconds between boss hops. Adds vertical body-position variation so
## the player can't camp one shooting line.
@export var hop_interval: float = 2.5

## Vertical velocity applied on each hop (negative = up).
@export var hop_velocity: float = -240.0

## Phase-2 threshold — once `hp / max_hp` falls below this, the boss
## switches from a single tracked bullet to a 3-bullet ±15° spread.
@export var phase_2_hp_pct: float = 0.5

## Half-angle (degrees) of the phase-2 spread relative to the centre shot.
@export var spread_angle_deg: float = 15.0

# ---------------------------------------------------------------------------
# Visuals — bigger silhouette than a regular enemy
# ---------------------------------------------------------------------------

const _BOSS_SIZE: Vector2 = Vector2(32.0, 32.0)
const _BOSS_COLOR_BODY: Color = Color("#E25040")
const _BOSS_COLOR_BODY_HIT: Color = Color("#FFE0E0")
const _BOSS_COLOR_EYE: Color = Color("#FFE066")
const _BOSS_COLOR_ANTENNA: Color = Color("#982D20")

const _BULLET_SCENE: PackedScene = preload("res://scenes/enemy_bullet.tscn")

# ---------------------------------------------------------------------------
# Public events
# ---------------------------------------------------------------------------

## Fired exactly once when the boss's hp hits zero. Stage scripts use
## this to roll the clear flow (banner + fade + scene transition).
signal died

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _shoot_timer: float = 0.0
var _hop_timer: float = 0.0


func _ready() -> void:
	hp = max_hp  # Enemy._ready does this; explicit here in case super isn't called.
	_shoot_timer = bullet_initial_delay
	_hop_timer = hop_interval * 0.5  # phase the first hop slightly out of sync


func _physics_process(delta: float) -> void:
	if Game.test_mode or not is_alive:
		return
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	# Stationary horizontally — only gravity + periodic hop affect velocity.y.
	velocity.x = 0.0
	velocity.y = minf(velocity.y + gravity * delta, terminal_velocity)
	# Hop on a fixed cadence whenever we're standing on the floor.
	_hop_timer -= delta
	if _hop_timer <= 0.0 and is_on_floor():
		_hop_timer = hop_interval
		velocity.y = hop_velocity
	# Shoot on cadence — pattern depends on hp percentage (phase 1 vs 2).
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = shoot_interval
		_fire_at_player()
	move_and_slide()
	queue_redraw()


# v0.63 — phase-aware RANDOMIZED pattern picker. R-08 keeps a small pool
# (it's the first boss) but no longer fires a fixed pattern. Subclasses
# (FinalBoss / TyrantZ / TyrantZ2 / GridZero) override with their own pools.
func _fire_at_player() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var direction: Vector2 = (player.global_position - global_position).normalized()
	var hp_pct: float = float(hp) / float(max_hp)

	var pool: PackedStringArray
	if hp_pct < phase_2_hp_pct:
		# Phase 2: spread + volley + occasional aimed.
		pool = PackedStringArray(["spread", "spread", "volley", "aimed"])
	else:
		# Phase 1: mostly aimed but throw in one volley so the player
		# can't camp a single line forever.
		pool = PackedStringArray(["aimed", "aimed", "aimed", "volley"])

	var pattern: String = pool[randi() % pool.size()]
	match pattern:
		"aimed":  _attack_aimed_single(direction)
		"spread": _attack_spread_n(direction, 3, spread_angle_deg)
		"volley": _attack_volley_3(direction)

	_shoot_timer = randf_range(0.4, 0.9)

	if not Game.test_mode:
		Sfx.play("shoot_enemy")


func _spawn_enemy_bullet(direction: Vector2) -> void:
	var bullet: EnemyBullet = _BULLET_SCENE.instantiate() as EnemyBullet
	bullet.velocity = direction * bullet_speed
	bullet.global_position = global_position
	get_parent().add_child(bullet)


# ---------------------------------------------------------------------------
# Shared attack pattern helpers (v0.63 — subclasses pick from these)
# ---------------------------------------------------------------------------

## Single tracked bullet aimed at the player.
func _attack_aimed_single(direction: Vector2) -> void:
	_spawn_enemy_bullet(direction)


## N-bullet symmetric fan with `spread_deg` half-angle. count must be odd.
func _attack_spread_n(direction: Vector2, count: int, spread_deg: float) -> void:
	var spread: float = deg_to_rad(spread_deg)
	var half: int = (count - 1) / 2
	for i in range(-half, half + 1):
		var angle: float = spread * float(i) / float(maxi(half, 1))
		_spawn_enemy_bullet(direction.rotated(angle))


## 8-bullet 360° radial burst originating from the boss.
func _attack_radial_8() -> void:
	for i in 8:
		var angle: float = TAU * float(i) / 8.0
		_spawn_enemy_bullet(Vector2.RIGHT.rotated(angle))


## 4-bullet cardinal radial (up/down/left/right).
func _attack_radial_4() -> void:
	_spawn_enemy_bullet(Vector2.UP)
	_spawn_enemy_bullet(Vector2.DOWN)
	_spawn_enemy_bullet(Vector2.LEFT)
	_spawn_enemy_bullet(Vector2.RIGHT)


## 3 quick shots aimed at the player with small angle jitter — reads
## as a concentrated burst.
func _attack_volley_3(direction: Vector2) -> void:
	for i in 3:
		var jitter: float = deg_to_rad(randf_range(-6.0, 6.0))
		_spawn_enemy_bullet(direction.rotated(jitter))


# Override Enemy.die so the stage gets a single signal it can hook into,
# then defer to the same is_alive / queue_free cleanup.
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	hp = 0
	Game.register_kill()
	died.emit()
	if not Game.test_mode:
		Sfx.play("enemy_die")
		_spawn_boss_death_particles()
		_drop_coins(10, 18.0)
		# Climactic hit-stop + heavy shake on boss death — punctuates
		# the kill in a way that regular grunts shouldn't.
		Game.hit_stop(0.22, 0.0)
		Game.request_shake(6.0)
	queue_free()


# Bigger particle burst than a regular enemy.
func _spawn_boss_death_particles() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.color = _BOSS_COLOR_BODY
	burst.count = 20
	burst.duration = 0.9
	burst.speed_max = 160.0
	burst.global_position = global_position
	parent.add_child(burst)


func _draw() -> void:
	var body_color: Color = _BOSS_COLOR_BODY_HIT if _hit_flash_timer > 0.0 else _BOSS_COLOR_BODY
	# Body
	draw_rect(Rect2(-_BOSS_SIZE.x * 0.5, -_BOSS_SIZE.y * 0.5, _BOSS_SIZE.x, _BOSS_SIZE.y), body_color)
	# Single eye centred near the top.
	draw_rect(Rect2(-3.0, -10.0, 6.0, 4.0), _BOSS_COLOR_EYE)
	# Two antennae sticking up from the head.
	draw_rect(Rect2(-12.0, -22.0, 2.0, 6.0), _BOSS_COLOR_ANTENNA)
	draw_rect(Rect2(10.0, -22.0, 2.0, 6.0), _BOSS_COLOR_ANTENNA)

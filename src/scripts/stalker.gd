## Voltline — flying stalker enemy (v0.68).
##
## Ignores gravity. Tracks the player horizontally at a configurable
## chase speed while maintaining a fixed vertical offset ABOVE the
## player (so it hovers like a drone and you never get to camp under it
## the way you can with a turret). Drops a tracked EnemyBullet straight
## down at the player on a cadence.
##
## Inherits Enemy's hp / take_damage / die / drop pipeline. Pure-logic
## tick_movement(delta, player_pos) lets tests drive it without a
## SceneTree or physics world.
class_name Stalker
extends "res://scripts/enemy.gd"

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Horizontal chase speed (px/s) toward the player's x.
@export var chase_speed: float = 90.0

## Pixels above the player the stalker tries to hover at. The Y track
## is a critically-damped approach (closes the gap, doesn't oscillate).
@export var hover_offset_y: float = -60.0

## Approach rate on the vertical axis — fraction of remaining distance
## closed per second. 4.0 = closes ~63% of the gap each second.
@export var vertical_rate: float = 4.0

## Seconds between drop shots.
@export var shoot_interval: float = 2.4

## Initial fire delay so the player has time to read the encounter.
@export var bullet_initial_delay: float = 1.0

## Drop-shot velocity (px/s).
@export var bullet_speed: float = 180.0

# ---------------------------------------------------------------------------
# Visuals — angular flier silhouette
# ---------------------------------------------------------------------------

const _ST_BODY: Color = Color("#8A30D0")
const _ST_BODY_HIT: Color = Color("#FFE0E0")
const _ST_EYE: Color = Color("#FFD24A")
const _ST_BLADE: Color = Color("#5A1080")

const _BULLET_SCENE: PackedScene = preload("res://scenes/enemy_bullet.tscn")

var _shoot_timer: float = 0.0


func _ready() -> void:
	# Spawn defaults — light HP, no gravity, no patrol bounds.
	if max_hp == 2:
		max_hp = 4
	hp = max_hp
	gravity = 0.0
	terminal_velocity = 240.0
	_shoot_timer = bullet_initial_delay


func _physics_process(delta: float) -> void:
	if Game.test_mode or not is_alive:
		return
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null:
		tick_chase(delta, player.global_position)
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = shoot_interval
		_drop_shot()
	move_and_slide()
	queue_redraw()


## Pure-logic movement step. Pulls horizontally toward `player_pos.x` at
## chase_speed and damps the y toward (player.y + hover_offset_y). Tests
## drive this with synthetic player positions and zero physics. Named
## `tick_chase` (not `tick_movement`) so it doesn't conflict with the
## Enemy base's tick_movement signature.
func tick_chase(delta: float, player_pos: Vector2) -> void:
	var dx: float = player_pos.x - global_position.x
	var x_dir: float = 0.0
	if absf(dx) > 1.0:
		x_dir = signf(dx)
	velocity.x = x_dir * chase_speed
	# Update facing so the eye + drop-shot read correctly.
	if x_dir != 0.0:
		direction = 1 if x_dir > 0.0 else -1

	var target_y: float = player_pos.y + hover_offset_y
	var dy: float = target_y - global_position.y
	# Critically-damped pull — proportional in `vertical_rate` per second.
	velocity.y = dy * vertical_rate


func _drop_shot() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var bullet: EnemyBullet = _BULLET_SCENE.instantiate() as EnemyBullet
	# Aim straight down with a small lead toward the player so the round
	# actually lands where the player is rather than where they were.
	var lead_x: float = clampf(
		(player.global_position.x - global_position.x) * 0.4,
		-bullet_speed * 0.3, bullet_speed * 0.3
	)
	bullet.velocity = Vector2(lead_x, bullet_speed)
	bullet.global_position = global_position + Vector2(0.0, 6.0)
	get_parent().add_child.call_deferred(bullet)
	if not Game.test_mode:
		Sfx.play("shoot_enemy")


func _draw() -> void:
	var body_color: Color = _ST_BODY_HIT if _hit_flash_timer > 0.0 else _ST_BODY
	# Diamond silhouette so it reads as airborne.
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -7.0), Vector2(8.0, 0.0),
		Vector2(0.0, 7.0),  Vector2(-8.0, 0.0),
	])
	draw_polygon(pts, PackedColorArray([body_color]))
	# Side blades.
	draw_rect(Rect2(-10.0, -1.0, 4.0, 2.0), _ST_BLADE)
	draw_rect(Rect2(6.0, -1.0, 4.0, 2.0), _ST_BLADE)
	# Eye facing the player's side.
	var eye_x: float = 2.0 if direction > 0 else -4.0
	draw_rect(Rect2(eye_x, -1.0, 2.0, 2.0), _ST_EYE)

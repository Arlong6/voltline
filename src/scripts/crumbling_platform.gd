## Voltline — crumbling platform (v0.62).
##
## AnimatableBody2D platform that idles until the player stands on it.
## After `step_delay` seconds it shakes for `shake_duration`, then drops
## via gravity until offscreen. Cannot be re-stood-on once shaking.
##
## Detects "player standing on top" via a child Area2D HurtBox-style
## sensor that checks for Player overlap; the platform itself can't see
## that with built-in get_floor_normal() since AnimatableBody2D doesn't
## report contacts to GDScript reliably.
class_name CrumblingPlatform
extends AnimatableBody2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Seconds the platform stays put after the player first lands.
@export var step_delay: float = 0.5

## Seconds the shake telegraph plays before the drop starts.
@export var shake_duration: float = 0.3

## Vertical fall acceleration once dropping.
@export var fall_gravity: float = 600.0

## Pixel y past which the platform is considered "off screen" and is
## queue_free'd. Defaults far enough below the 216-px viewport that even
## a high-spawned platform falls off cleanly.
@export var fall_kill_y: float = 320.0

## Visible size — drawn centred on the body.
@export var size: Vector2 = Vector2(48.0, 8.0)

## Visible color — defaults to a stone-brown so it reads as "fragile".
@export var color: Color = Color("#8A7A4A")

const _COLOR_CRACK: Color = Color("#3A2818")
const _COLOR_SHAKE: Color = Color("#FF8030")

# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

enum Phase { STABLE, ARMED, SHAKING, FALLING, GONE }

var _phase: int = Phase.STABLE
var _phase_t: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _fall_velocity: float = 0.0
var _sensor: Area2D
var _player_present: bool = false


func _ready() -> void:
	_origin = position
	_build_sensor()


func _physics_process(delta: float) -> void:
	if Game.test_mode:
		return
	tick(delta)
	queue_redraw()


## Pure-logic state-machine tick. Tests drive this directly. The
## `player_on` parameter overrides _player_present for synthetic ticks.
func tick(delta: float, player_on: bool = _player_present) -> void:
	match _phase:
		Phase.STABLE:
			if player_on:
				_phase = Phase.ARMED
				_phase_t = 0.0
		Phase.ARMED:
			_phase_t += delta
			if _phase_t >= step_delay:
				_phase = Phase.SHAKING
				_phase_t = 0.0
		Phase.SHAKING:
			_phase_t += delta
			if _phase_t >= shake_duration:
				_phase = Phase.FALLING
				_phase_t = 0.0
				_fall_velocity = 0.0
		Phase.FALLING:
			_fall_velocity += fall_gravity * delta
			position.y += _fall_velocity * delta
			# Disable collision once we start falling — player lands
			# nowhere.
			collision_layer = 0
			if position.y >= fall_kill_y:
				_phase = Phase.GONE
				call_deferred("queue_free")
		Phase.GONE:
			pass


# A child Area2D sits just above the platform's top surface; when the
# Player overlaps it, _player_present flips on, kicking the state
# machine off ARMED.
func _build_sensor() -> void:
	_sensor = Area2D.new()
	_sensor.name = &"Sensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2  # Player layer
	_sensor.position = Vector2(0.0, -size.y * 0.5 - 4.0)
	add_child(_sensor)
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(size.x, 8.0)
	collider.shape = shape
	_sensor.add_child(collider)
	_sensor.body_entered.connect(_on_player_entered)
	_sensor.body_exited.connect(_on_player_exited)


func _on_player_entered(body: Node2D) -> void:
	if body is Player:
		_player_present = true


func _on_player_exited(body: Node2D) -> void:
	if body is Player:
		_player_present = false


func _draw() -> void:
	var draw_offset: Vector2 = Vector2.ZERO
	if _phase == Phase.SHAKING:
		# Sub-pixel high-frequency rattle.
		draw_offset.x = sin(_phase_t * 60.0) * 1.5
	# Body — color shifts to orange during shake to telegraph the drop.
	var body_color: Color = color
	if _phase == Phase.SHAKING:
		body_color = color.lerp(_COLOR_SHAKE, 0.5)
	draw_rect(Rect2(-size * 0.5 + draw_offset, size), body_color)
	# Hairline crack across the top so the player reads it as fragile.
	draw_line(
		Vector2(-size.x * 0.5 + 6.0 + draw_offset.x, -size.y * 0.5 + 2.0 + draw_offset.y),
		Vector2(size.x * 0.5 - 6.0 + draw_offset.x, -size.y * 0.5 + 4.0 + draw_offset.y),
		_COLOR_CRACK, 1.0
	)

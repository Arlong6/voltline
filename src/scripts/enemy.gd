## Voltline — patrolling sweeper enemy (V-008).
##
## CharacterBody2D enemy that walks back and forth between patrol_min_x
## and patrol_max_x bounds, reverses on wall contact (so it can't get
## stuck on level geometry), falls under gravity, and dies after taking
## `max_hp` worth of bullet damage. Touching the player triggers the
## player's damage signal via the HurtBox Area2D child.
##
## Pure-logic tick_movement(delta, on_wall) lets unit tests drive the
## enemy without a SceneTree or physics world.
class_name Enemy
extends CharacterBody2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Pixel-per-second horizontal patrol speed.
@export var walk_speed: float = 30.0

## Downward acceleration.
@export var gravity: float = 800.0

## Max downward velocity.
@export var terminal_velocity: float = 360.0

## 1 = walking right initially, -1 = walking left.
@export var direction: int = 1

## Patrol bounds — set by the level when spawning the enemy.
@export var patrol_min_x: float = 0.0
@export var patrol_max_x: float = 100.0

## Maximum hit points. Charged player bullets do 2 damage; normal bullets
## do 1. Tune per stage to escalate difficulty.
@export var max_hp: int = 2

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## Set false by die() when hp reaches 0. Once false, _physics_process
## short-circuits and the queue_free path takes over.
var is_alive: bool = true

## Current hit points. Reset to max_hp in _ready.
var hp: int = 0

# ---------------------------------------------------------------------------
# Visuals — sweeper-bot silhouette with a brief white hit-flash
# ---------------------------------------------------------------------------

const _COLOR_BODY: Color = Color("#C04030")
const _COLOR_BODY_HIT: Color = Color("#FFE0E0")
const _COLOR_EYE: Color = Color("#FFE066")
const _COLOR_LEGS: Color = Color("#802020")
const _HIT_FLASH_DURATION: float = 0.08

var _hit_flash_timer: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	hp = max_hp


func _physics_process(delta: float) -> void:
	if Game.test_mode or not is_alive:
		return
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	tick_movement(delta, is_on_wall())
	move_and_slide()
	queue_redraw()


## Pure-logic patrol step. Reverses `direction` on wall contact OR on
## reaching either patrol bound, then sets velocity from direction × speed
## and applies gravity. Tests drive this directly with synthesized values.
func tick_movement(delta: float, on_wall: bool = false) -> void:
	var hit_max: bool = direction > 0 and global_position.x >= patrol_max_x
	var hit_min: bool = direction < 0 and global_position.x <= patrol_min_x
	if on_wall or hit_max or hit_min:
		direction = -direction

	velocity.x = float(direction) * walk_speed
	velocity.y = minf(velocity.y + gravity * delta, terminal_velocity)


## Bullet handler calls this on hit. Subtracts `amount` from hp; calls
## die() when hp drops to 0 or below. No-op if already dead.
##
## `from_pos` is the world position the hit came from (the bullet's
## position). The base enemy ignores it; subclasses with directional
## armour (Shieldbearer) read it to decide whether the hit lands.
func take_damage(amount: int, from_pos: Vector2 = Vector2.INF) -> void:
	if not is_alive:
		return
	hp -= amount
	_hit_flash_timer = _HIT_FLASH_DURATION
	if hp <= 0:
		die()
	elif not Game.test_mode:
		Sfx.play("enemy_hit")


## Marks the enemy not-alive, zeroes hp, and removes it from the scene
## tree. queue_free is deferred so the bullet's hit handler can finish
## without a freed-self crash.
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	hp = 0
	Game.register_kill()
	if not Game.test_mode:
		Sfx.play("enemy_die")
		_spawn_death_particles()
		# v0.64 — 5% chance to drop a timed power-up. Mutually exclusive
		# with the existing coin / health drops so the player has to
		# choose between resource pressure and the buff window.
		var roll: float = randf()
		if roll < 0.05:
			_drop_power_up()
		elif roll < 0.35:
			_drop_health()
		else:
			_drop_coins(1, 8.0)
	queue_free()


# Spawns a ParticleBurst at the enemy's death location. Attaches it to
# the parent so the burst persists after queue_free.
func _spawn_death_particles() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.color = _COLOR_BODY
	burst.global_position = global_position
	parent.add_child(burst)


# Drops `count` coins at the enemy's position with a small horizontal
# spread so they don't all overlap. Coins persist after queue_free.
const _COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const _HEALTH_SCENE: PackedScene = preload("res://scenes/health_pickup.tscn")
const _POWERUP_SCENE: PackedScene = preload("res://scenes/power_up.tscn")

# Declared as `var` — PackedStringArray constructors are not constant
# expressions in GDScript. Treat as immutable in code.
static var _POWERUP_TYPES: PackedStringArray = PackedStringArray([
	"invincible", "damage_up", "rapid_fire", "magnet",
])

# NOTE: pickup add_child is deferred. die() runs inside the physics
# query flush (bullet body_entered → take_damage → die); a pickup's
# Area2D toggles monitoring in _ready, which the physics server rejects
# mid-flush ("Can't change this state while flushing queries"). Deferring
# the add_child pushes _ready to after the flush completes.
func _drop_health() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var pickup: HealthPickup = _HEALTH_SCENE.instantiate() as HealthPickup
	pickup.global_position = global_position + Vector2(0.0, -2.0)
	parent.add_child.call_deferred(pickup)


func _drop_power_up() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var pickup: PowerUp = _POWERUP_SCENE.instantiate() as PowerUp
	pickup.buff_type = _POWERUP_TYPES[randi() % _POWERUP_TYPES.size()]
	pickup.global_position = global_position + Vector2(0.0, -2.0)
	parent.add_child.call_deferred(pickup)


func _drop_coins(count: int, spread: float) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	for i in count:
		var coin: Coin = _COIN_SCENE.instantiate() as Coin
		coin.global_position = global_position + Vector2(
			randf_range(-spread, spread), -2.0
		)
		parent.add_child.call_deferred(coin)


func _draw() -> void:
	# Body — brief white flash on hit, otherwise dark red.
	var body_color: Color = _COLOR_BODY_HIT if _hit_flash_timer > 0.0 else _COLOR_BODY
	draw_rect(Rect2(-7.0, -4.0, 14.0, 8.0), body_color)
	# Single eye on facing side.
	var eye_x: float = 2.0 if direction > 0 else -4.0
	draw_rect(Rect2(eye_x, -2.0, 2.0, 2.0), _COLOR_EYE)
	# Three small legs underneath the body.
	draw_rect(Rect2(-5.0, 4.0, 2.0, 3.0), _COLOR_LEGS)
	draw_rect(Rect2(-1.0, 4.0, 2.0, 3.0), _COLOR_LEGS)
	draw_rect(Rect2(3.0, 4.0, 2.0, 3.0), _COLOR_LEGS)

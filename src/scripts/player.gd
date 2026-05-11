## Voltline — player controller (V-002 + V-003 + V-004 + V-005).
##
## CharacterBody2D action-platformer player. Owns walk, gravity, jump
## (with coyote + buffer + variable height), facing, buster shot,
## ground-only dash, and wall slide + wall jump.
##
## Architecture: _physics_process scrapes input, is_on_floor(), and wall
## state from get_wall_normal(); delegates the math to two pure-logic
## functions — tick_movement() (horizontal/vertical, dash, jump, wall
## interactions) and tick_shoot() (cooldown + fire-this-tick boolean).
## Tests call those directly without a SceneTree or input device.
##
## Game.test_mode short-circuits _physics_process so tests never see
## double-stepped state when they drive the tick functions manually.
class_name Player
extends CharacterBody2D

# ---------------------------------------------------------------------------
# Tuning — movement (V-002)
# ---------------------------------------------------------------------------

## Horizontal walk speed in pixels per second.
@export var walk_speed: float = 90.0

## Initial vertical velocity on jump press. Negative = upward in Godot 2D.
@export var jump_velocity: float = -280.0

## Downward acceleration in pixels per second². Applied every physics tick.
@export var gravity: float = 800.0

## Maximum downward velocity (px/s). velocity.y is clamped to this.
@export var terminal_velocity: float = 360.0

## Seconds after leaving the floor during which a jump press still triggers
## a jump. ~6 frames @ 60 fps.
@export var coyote_time: float = 0.1

## Seconds before landing during which a queued jump press fires on touchdown.
@export var jump_buffer: float = 0.1

## Multiplier applied to velocity.y when the jump button is released while
## still rising. 0.4 = "release at apex of a short hop".
@export var short_hop_factor: float = 0.4

## Number of mid-air jumps available between leaving the floor and landing.
## 1 = double jump (1 ground + 1 air). 0 = single jump (legacy). Charges
## are consumed one per air-press and reset only on ground contact —
## wall slides do NOT refill, otherwise wall-jump shafts become trivial.
@export var max_air_jumps: int = 1

## Vertical velocity for an air jump. Slightly weaker than ground
## jump_velocity so the air boost feels intentional, not free flight.
@export var air_jump_velocity: float = -240.0

## Number of mid-air dashes available between leaving the floor and
## landing. 1 enables the v0.56 air dash; 0 reverts to ground-only dash.
## Refills on ground contact (same policy as air jumps).
@export var max_air_dashes: int = 1

# ---------------------------------------------------------------------------
# Tuning — buster shot (V-003)
# ---------------------------------------------------------------------------

## Minimum seconds between consecutive bullet spawns.
@export var shoot_interval: float = 0.15

## Local offset from the player centre at which a bullet spawns. The X
## component is mirrored by `facing`.
@export var bullet_offset: Vector2 = Vector2(8.0, -1.0)

## Seconds of held shoot button required to reach Lv1 charge (V-006).
@export var charge_threshold: float = 0.6

## Seconds of held shoot button required to reach Lv2 super-charge
## (v0.56). Releasing past this threshold fires a 4-damage super blast.
@export var charge_threshold_lv2: float = 1.4

# ---------------------------------------------------------------------------
# Tuning — damage / respawn (V-009 lite)
# ---------------------------------------------------------------------------

## Seconds of post-hit invincibility. Player blinks visibly during this
## window and cannot take a second hit.
@export var invincibility_duration: float = 1.0

## Maximum hit points. Consumed by take_damage(amount); drops to 0 →
## triggers respawn back to spawn point with hp restored.
@export var max_hp: int = 12

## Damage taken from direct enemy contact (vs the smaller projectile damage).
## v0.58: dropped from 4 → 2 — 6 hits to death instead of 3 lets the
## player play more aggressively against the heavier enemy density.
@export var contact_damage: int = 2

## Pushes the player away from danger when hit. x is mirrored by facing
## (positive = away from facing); y is launch upward.
@export var knockback_velocity: Vector2 = Vector2(120.0, -180.0)

## Seconds of horizontal-input lockout after a hit. Lets the knockback
## arc resolve before the player can walk back into the same enemy.
@export var knockback_lockout: float = 0.2

# ---------------------------------------------------------------------------
# Tuning — dash (V-004)
# ---------------------------------------------------------------------------

## Horizontal dash speed in px/s. ~2.4× walk_speed.
@export var dash_speed: float = 220.0

## Active dash duration in seconds. ~14 frames @ 60 fps.
@export var dash_duration: float = 0.233

# ---------------------------------------------------------------------------
# Tuning — wall slide / wall jump (V-005)
# ---------------------------------------------------------------------------

## Maximum velocity.y while wall-sliding. ~22% of terminal_velocity for the
## clear "I'm sticking to this wall" feel.
@export var wall_slide_speed: float = 80.0

## Wall-jump launch — x = horizontal push away from wall, y = vertical lift
## (negative = upward). 240 vertical is slightly weaker than the standard
## jump's 280 so wall-jumps feel like deliberate climbing, not free flight.
@export var wall_jump_velocity: Vector2 = Vector2(180.0, -240.0)

## Seconds after a wall jump during which horizontal input AND facing
## updates are ignored. Stops the player from re-grabbing the wall they
## just kicked off, which would feel like the controller fighting them.
@export var wall_jump_lockout: float = 0.18

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## -1 = facing left, 1 = facing right. Updated each tick from `input_x`;
## locked while dashing or in wall-jump lockout.
var facing: int = 1

## True on ticks when the player is actively wall-sliding. Read by tests
## and (later) visual effects.
var is_wall_sliding: bool = false

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jump_was_held: bool = false
var _input_jump_held_last: bool = false

# Mid-air jumps consumed since the last ground contact. Reset to 0 when
# is_grounded becomes true; incremented each time an air jump fires.
var _air_jumps_used: int = 0

# Mid-air dashes consumed since the last ground contact. Reset to 0 when
# is_grounded becomes true; incremented each time an air dash fires.
var _air_dashes_used: int = 0

# Set true on the tick an air jump fires; consumed (and cleared) by
# _physics_process to spawn a one-shot puff particle. Tests can read
# this to verify air-jump activation without inspecting velocity.
var did_air_jump_this_tick: bool = false

# Set true on the tick an air dash fires (same particle-spawn pattern
# as did_air_jump_this_tick). Visible to tests for direct assertion.
var did_air_dash_this_tick: bool = false

var _shoot_cooldown: float = 0.0
var _input_shoot_held_last: bool = false

# Charge accumulator — counts up while the shoot button is held; consumed
# (and reset) on release if it crossed `charge_threshold`.
var _charge_timer: float = 0.0

var _dash_timer: float = 0.0
var _input_dash_held_last: bool = false

# Counts down after a wall jump; while > 0 the player has no horizontal
# walk control and facing stays locked.
var _wall_jump_lockout_timer: float = 0.0

# Counts down after a hit; same effect as wall_jump_lockout but kept
# separate so the two can be diagnosed independently.
var _knockback_lockout_timer: float = 0.0

# Position the player respawns at on death — captured in _ready() from
# whatever the spawning level set as the initial position.
var _spawn_position: Vector2 = Vector2.ZERO

# Invincibility timer — counts down from invincibility_duration after a
# hit; while > 0 the hurt detector ignores enemies and the body blinks.
var _invincible_timer: float = 0.0

# Programmatic Area2D child for enemy-overlap detection (V-009).
var _hurt_detector: Area2D

# Current hit points. Reset to max_hp on _ready and on respawn.
var hp: int = 0

# Tracks whether the charge_ready SFX has fired for the current hold so
# we don't spam the chime every frame once the charge is full.
var _charge_ready_played: bool = false

# Same idea but for Lv2 super-charge (v0.56). Reset on release.
var _charge_lv2_played: bool = false

# ---------------------------------------------------------------------------
# Visual constants — stacked-rect mech silhouette inside the 12×16 collider
# ---------------------------------------------------------------------------

const _COLOR_HEAD: Color = Color("#5BC0F0")
const _COLOR_VISOR: Color = Color("#FFFFFF")
const _COLOR_BODY: Color = Color("#38B0E8")
const _COLOR_BUSTER: Color = Color("#7AD8FF")
const _COLOR_LEGS: Color = Color("#1E6FA0")
const _COLOR_CHARGE_READY: Color = Color("#FFE066")
const _COLOR_CHARGE_LV2: Color = Color("#FF8030")

const BULLET_SCENE: PackedScene = preload("res://scenes/bullet.tscn")

const _HURT_BOX_SIZE: Vector2 = Vector2(12.0, 16.0)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_spawn_position = global_position
	hp = max_hp
	add_to_group("player")  # boss looks us up via this group
	_build_hurt_detector()


# Programmatic Area2D so player.tscn stays a minimal script-attach.
# Detects bodies on the Enemy collision layer (mask = 4) and forwards
# them to _on_enemy_hit.
func _build_hurt_detector() -> void:
	_hurt_detector = Area2D.new()
	_hurt_detector.name = &"HurtDetector"
	_hurt_detector.collision_layer = 0
	_hurt_detector.collision_mask = 4  # Enemy layer
	add_child(_hurt_detector)

	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = _HURT_BOX_SIZE
	collider.shape = shape
	_hurt_detector.add_child(collider)

	_hurt_detector.body_entered.connect(_on_enemy_hit)

# ---------------------------------------------------------------------------
# Frame loop
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Game.test_mode:
		return

	# Decay invincibility + drive the post-hit blink (8 Hz sin).
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)
	if _invincible_timer > 0.0:
		visible = sin(_invincible_timer * 50.0) > 0.0
	else:
		visible = true

	var input_x: float = Input.get_axis("ui_left", "ui_right")

	var jump_held: bool = Input.is_action_pressed("jump")
	var jump_pressed: bool = jump_held and not _input_jump_held_last
	_input_jump_held_last = jump_held

	var shoot_held: bool = Input.is_action_pressed("shoot")
	var shoot_pressed: bool = shoot_held and not _input_shoot_held_last
	var shoot_released: bool = (not shoot_held) and _input_shoot_held_last
	_input_shoot_held_last = shoot_held

	var dash_held: bool = Input.is_action_pressed("dash")
	var dash_pressed: bool = dash_held and not _input_dash_held_last
	_input_dash_held_last = dash_held

	# Wall state from the previous frame's move_and_slide. Normal points
	# AWAY from the wall surface, so a wall on the player's LEFT yields
	# wall_normal.x = +1, and a wall on the RIGHT yields wall_normal.x = -1.
	var on_wall: bool = is_on_wall()
	var wall_normal: Vector2 = get_wall_normal() if on_wall else Vector2.ZERO
	var wall_left: bool = on_wall and wall_normal.x > 0.5
	var wall_right: bool = on_wall and wall_normal.x < -0.5

	tick_movement(
		delta,
		input_x,
		jump_pressed,
		jump_held,
		is_on_floor(),
		dash_pressed,
		wall_left,
		wall_right
	)

	if tick_shoot(delta, shoot_pressed):
		_spawn_bullet(0)
		Sfx.play("shoot_normal")
	var charge_fired: int = tick_charge(delta, shoot_held, shoot_released)
	if charge_fired > 0:
		_spawn_bullet(charge_fired)
		Sfx.play("shoot_super" if charge_fired >= 2 else "shoot_charged")

	move_and_slide()
	if did_air_jump_this_tick:
		_spawn_air_jump_puff()
	if did_air_dash_this_tick:
		_spawn_air_dash_puff()
	queue_redraw()


## Pure-logic movement step. Tests call this directly with synthesized
## inputs — no SceneTree, no real input device. See V-005 implementation
## notes for the strict ordering: lockout decay → facing → dash trigger →
## horizontal velocity → gravity → wall slide → timer decay → jump (wall
## jump priority) → variable jump cutoff.
##
## Parameters past `dash_pressed` default to false, so older 4–6-arg call
## sites (V-002, V-003, V-004 tests) stay green without changes.
func tick_movement(
	delta: float,
	input_x: float,
	jump_pressed: bool,
	jump_held: bool,
	is_grounded: bool,
	dash_pressed: bool = false,
	is_wall_left: bool = false,
	is_wall_right: bool = false
) -> void:
	# 0. Consume last tick's one-shot flags so the new tick can re-arm them.
	did_air_jump_this_tick = false
	did_air_dash_this_tick = false

	# 1. Decay both lockouts. Either one suspends walk velocity + facing
	#    updates so the imposed velocity (wall-jump push or knockback)
	#    survives long enough to feel committed.
	_wall_jump_lockout_timer = maxf(_wall_jump_lockout_timer - delta, 0.0)
	_knockback_lockout_timer = maxf(_knockback_lockout_timer - delta, 0.0)
	var input_locked_out: bool = (
		_wall_jump_lockout_timer > 0.0 or _knockback_lockout_timer > 0.0
	)

	# 2. Facing — locked while dashing or in lockout.
	if input_x != 0.0 and _dash_timer <= 0.0 and not input_locked_out:
		facing = int(signf(input_x))

	# 3. Dash trigger — ground dash always allowed; air dash gated on the
	#    air-dash charge pool.
	if dash_pressed and _dash_timer <= 0.0:
		if is_grounded:
			_dash_timer = dash_duration
			Sfx.play("dash")
		elif _air_dashes_used < max_air_dashes:
			_dash_timer = dash_duration
			_air_dashes_used += 1
			# Clean horizontal blast — wipe vertical so the dash arc is flat.
			velocity.y = 0.0
			did_air_dash_this_tick = true
			Sfx.play("dash")

	# 4. Horizontal velocity. Lockout window keeps wall-jump push intact.
	#    Airborne control preserves momentum (no air friction) so dash-jumps
	#    don't suddenly snap to walk speed mid-arc. Pressing the SAME
	#    direction in air keeps the higher boost speed; pressing OPPOSITE
	#    snaps to walk speed (instant air control); no input preserves vx.
	if not input_locked_out:
		if _dash_timer > 0.0:
			velocity.x = float(facing) * dash_speed
		elif is_grounded:
			velocity.x = input_x * walk_speed
		elif input_x != 0.0:
			var input_dir: float = signf(input_x)
			if signf(velocity.x) == input_dir:
				# Same direction — preserve boost, never below walk_speed.
				velocity.x = input_dir * maxf(absf(velocity.x), walk_speed)
			else:
				# Opposite (or stationary): snap to walk speed in input direction.
				velocity.x = input_dir * walk_speed
		# Airborne with no input → preserve velocity.x (no air friction).

	# 5. Gravity, clamped to terminal velocity. Suspended while a dash is
	#    active so air-dashes ride a flat horizontal line.
	if _dash_timer > 0.0:
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + gravity * delta, terminal_velocity)

	# 6. Wall slide — airborne + falling + pressing into the wall on that
	#    side. Cancelled by lockout (otherwise the wall-jump arc would
	#    immediately re-engage slide as the player drifts back).
	var pressing_into_left_wall: bool = is_wall_left and input_x < 0.0 and not input_locked_out
	var pressing_into_right_wall: bool = is_wall_right and input_x > 0.0 and not input_locked_out
	var can_slide: bool = (
		not is_grounded
		and velocity.y > 0.0
		and (pressing_into_left_wall or pressing_into_right_wall)
	)
	if can_slide:
		velocity.y = minf(velocity.y, wall_slide_speed)
	is_wall_sliding = can_slide

	# 7. Other timers + air-charge refresh on ground contact.
	if is_grounded:
		_coyote_timer = coyote_time
		_air_jumps_used = 0
		_air_dashes_used = 0
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_timer = maxf(_dash_timer - delta, 0.0)

	# 8. Jump trigger — priority order: wall jump → coyote/regular jump →
	#    air jump → buffer. Air jump only fires when there's no coyote left
	#    (so a freshly-walked-off ledge spends coyote first, not an air
	#    charge) and we still have charges remaining.
	if jump_pressed:
		if can_slide:
			# Wall jump: lift + push away + flip facing + arm lockout.
			velocity.y = wall_jump_velocity.y
			var push_dir: int = 1 if pressing_into_left_wall else -1
			velocity.x = wall_jump_velocity.x * float(push_dir)
			facing = push_dir
			_wall_jump_lockout_timer = wall_jump_lockout
			Sfx.play("jump")
		elif _coyote_timer > 0.0:
			velocity.y = jump_velocity
			_coyote_timer = 0.0
			Sfx.play("jump")
		elif _air_jumps_used < max_air_jumps:
			velocity.y = air_jump_velocity
			_air_jumps_used += 1
			did_air_jump_this_tick = true
			Sfx.play("jump")
		else:
			_jump_buffer_timer = jump_buffer
	elif is_grounded and _jump_buffer_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		Sfx.play("jump")

	# 9. Variable jump cutoff — applies to all upward arcs uniformly.
	if _jump_was_held and not jump_held and velocity.y < 0.0:
		velocity.y *= short_hop_factor
	_jump_was_held = jump_held


## Pure-logic tap-shot step. Decrements cooldown and returns true exactly
## on the tick a normal bullet should be spawned (V-003).
func tick_shoot(delta: float, shoot_pressed: bool) -> bool:
	_shoot_cooldown = maxf(_shoot_cooldown - delta, 0.0)
	if shoot_pressed and _shoot_cooldown <= 0.0:
		_shoot_cooldown = shoot_interval
		return true
	return false


## Pure-logic charge step (V-006 + v0.56). Accumulates `_charge_timer`
## while held; chimes once at Lv1 and once at Lv2. On release, returns
## the highest charge level the hold reached:
##   0 = released below charge_threshold (no charged shot)
##   1 = released between charge_threshold and charge_threshold_lv2
##   2 = released past charge_threshold_lv2 (super blast)
## Cooldown does NOT gate charged shots — the hold itself is the rate limiter.
func tick_charge(delta: float, shoot_held: bool, shoot_released: bool) -> int:
	var was_below_lv1: bool = _charge_timer < charge_threshold
	var was_below_lv2: bool = _charge_timer < charge_threshold_lv2
	if shoot_held:
		_charge_timer += delta
		if was_below_lv1 and _charge_timer >= charge_threshold and not _charge_ready_played:
			_charge_ready_played = true
			Sfx.play("charge_ready")
		if was_below_lv2 and _charge_timer >= charge_threshold_lv2 and not _charge_lv2_played:
			_charge_lv2_played = true
			Sfx.play("charge_lv2")
	else:
		_charge_ready_played = false
		_charge_lv2_played = false
	if shoot_released:
		var level: int = 0
		if _charge_timer >= charge_threshold_lv2:
			level = 2
		elif _charge_timer >= charge_threshold:
			level = 1
		_charge_timer = 0.0
		_charge_ready_played = false
		_charge_lv2_played = false
		return level
	return 0

# ---------------------------------------------------------------------------
# Spawn helpers
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Damage / respawn (V-009 lite)
# ---------------------------------------------------------------------------

# Hurt-detector callback. Fires when an Enemy CharacterBody2D overlaps
# the player's hurt rectangle. Inflicts contact_damage; respawn happens
# automatically inside take_damage if hp drops to 0.
func _on_enemy_hit(body: Node2D) -> void:
	if Game.test_mode:
		return
	if body is Enemy and body.is_alive:
		take_damage(contact_damage)


## Inflicts `amount` damage. No-op while invincible. If hp drops to 0 the
## player is sent back to spawn with full hp; otherwise hp drops, the
## hurt SFX plays, knockback fires, and invincibility is armed for the
## blink window.
func take_damage(amount: int) -> void:
	if _invincible_timer > 0.0:
		return
	hp = maxi(hp - amount, 0)
	_invincible_timer = invincibility_duration
	Game.register_hit()
	if hp <= 0:
		respawn()
	elif not Game.test_mode:
		Sfx.play("hurt")
		_shake_camera(4.0)
		# Knockback — push opposite of facing, lift up, lock horizontal
		# input briefly so the player can't walk straight back in.
		velocity.x = -float(facing) * knockback_velocity.x
		velocity.y = knockback_velocity.y
		_knockback_lockout_timer = knockback_lockout


## Restores `amount` HP, clamped to max_hp. Called by HealthPickup.
func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)


## Updates the spawn point used by respawn(). Called by Checkpoint when
## the player walks over it. Idempotent — safe to call repeatedly.
func set_checkpoint(pos: Vector2) -> void:
	_spawn_position = pos


## Public shake entry — Game.request_shake() calls this on the active
## player so bullet hits, boss deaths, etc. can drive the camera kick
## without each caller looking up the player themselves.
func shake(strength: float) -> void:
	_shake_camera(strength)


# Tweens the child Camera2D's offset for a brief left-right kick.
# No-op if the camera hasn't been attached yet (e.g. test environment).
func _shake_camera(strength: float) -> void:
	var camera: Camera2D = null
	for child in get_children():
		if child is Camera2D:
			camera = child
			break
	if camera == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(camera, "offset", Vector2(strength, 0.0), 0.03)
	tween.tween_property(camera, "offset", Vector2(-strength, 0.0), 0.03)
	tween.tween_property(camera, "offset", Vector2(strength * 0.5, 0.0), 0.03)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)


## Sends the player back to the spawn point with hp + invincibility
## restored. Called by take_damage on death; exposed so future systems
## (pits, instakill traps) can trigger a respawn directly.
func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	hp = max_hp
	_invincible_timer = invincibility_duration
	if not Game.test_mode:
		Sfx.play("hurt")

# ---------------------------------------------------------------------------
# Spawn helpers
# ---------------------------------------------------------------------------

# Spawns a brief downward-puff particle burst at the player's feet on
# the tick an air jump fires. Attached to the parent so it survives a
# player respawn.
func _spawn_air_jump_puff() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.color = _COLOR_BUSTER
	burst.count = 6
	burst.duration = 0.35
	burst.speed_min = 30.0
	burst.speed_max = 70.0
	burst.gravity = 320.0
	burst.global_position = global_position + Vector2(0.0, 6.0)
	parent.add_child(burst)


# Companion to the air-jump puff: shoots a short streak of particles
# OPPOSITE the dash direction (so it reads as exhaust trailing behind).
func _spawn_air_dash_puff() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.color = _COLOR_HEAD
	burst.count = 8
	burst.duration = 0.30
	burst.speed_min = 40.0
	burst.speed_max = 90.0
	burst.gravity = 80.0
	burst.global_position = global_position + Vector2(-float(facing) * 6.0, 0.0)
	parent.add_child(burst)


# Instantiates a Bullet pointed in the player's facing and attaches it as
# a sibling of the player so it persists independently after firing.
# `charge_level` is propagated to the bullet for visual + speed variation.
func _spawn_bullet(charge_level: int) -> void:
	var bullet: Bullet = BULLET_SCENE.instantiate() as Bullet
	bullet.direction = facing
	bullet.charge_level = charge_level
	bullet.global_position = global_position + Vector2(
		bullet_offset.x * float(facing),
		bullet_offset.y
	)
	get_parent().add_child(bullet)

# ---------------------------------------------------------------------------
# Rendering — stacked rectangles fitting inside the 12×16 collider
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Head: 6 wide × 5 tall, centred horizontally.
	draw_rect(Rect2(-3.0, -8.0, 6.0, 5.0), _COLOR_HEAD)
	# Visor: 3 wide × 1 tall white slit on the facing half of the head.
	var visor_x: float = 0.0 if facing > 0 else -3.0
	draw_rect(Rect2(visor_x, -7.0, 3.0, 1.0), _COLOR_VISOR)

	# Shoulder pads — 2×2 lighter pips at body-top corners.
	draw_rect(Rect2(-5.0, -3.0, 2.0, 2.0), _COLOR_HEAD)
	draw_rect(Rect2(3.0, -3.0, 2.0, 2.0), _COLOR_HEAD)

	# Body — colour shifts with charge state to telegraph the charge level.
	#   • Charge Lv2 (super) → solid orange-red
	#   • Charge Lv1 (ready) → solid yellow
	#   • Charging mid-way → pulsing lerp between body and white
	#   • Otherwise → standard body cyan
	var body_color: Color = _COLOR_BODY
	if _charge_timer >= charge_threshold_lv2:
		body_color = _COLOR_CHARGE_LV2
	elif _charge_timer >= charge_threshold:
		body_color = _COLOR_CHARGE_READY
	elif _charge_timer > 0.0:
		var pulse: float = sin(_charge_timer * 28.0) * 0.5 + 0.5
		body_color = _COLOR_BODY.lerp(Color.WHITE, pulse * 0.45)
	draw_rect(Rect2(-4.0, -3.0, 8.0, 6.0), body_color)

	# Buster arm: 3 wide × 3 tall protrusion on the facing side. Tints to
	# match the body's charge state so the muzzle reads as "loaded".
	var buster_x: float = 4.0 if facing > 0 else -7.0
	var buster_color: Color = _COLOR_BUSTER
	if _charge_timer >= charge_threshold_lv2:
		buster_color = _COLOR_CHARGE_LV2
	elif _charge_timer >= charge_threshold:
		buster_color = _COLOR_CHARGE_READY
	draw_rect(Rect2(buster_x, -1.0, 3.0, 3.0), buster_color)

	# Legs: two 2×5 darker rectangles with a 2-px gap (boots silhouette).
	draw_rect(Rect2(-3.0, 3.0, 2.0, 5.0), _COLOR_LEGS)
	draw_rect(Rect2(1.0, 3.0, 2.0, 5.0), _COLOR_LEGS)

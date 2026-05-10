## V-008 — Enemy patrol + die tests.
##
## Drives Enemy.tick_movement() directly with synthesized deltas.
## Game.test_mode short-circuits the real _physics_process so our manual
## ticks aren't double-stepped.
extends GutTest

const ENEMY_SCRIPT: GDScript = preload("res://scripts/enemy.gd")
const FRAME: float = 0.016

var enemy: Enemy


func before_each() -> void:
	Game.test_mode = true
	enemy = ENEMY_SCRIPT.new()
	add_child_autofree(enemy)


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Patrol movement
# ---------------------------------------------------------------------------

func test_walk_velocity_matches_direction_and_speed() -> void:
	enemy.direction = 1
	enemy.patrol_min_x = -1000.0
	enemy.patrol_max_x = 1000.0  # well past current position
	enemy.tick_movement(FRAME)
	assert_eq(enemy.velocity.x, enemy.walk_speed,
		"direction=1 should yield velocity.x = walk_speed")


func test_gravity_accumulates_below_terminal_velocity() -> void:
	enemy.velocity.y = 0.0
	enemy.tick_movement(FRAME)
	assert_gt(enemy.velocity.y, 0.0,
		"single tick should add positive (downward) gravity to velocity.y")
	assert_lt(enemy.velocity.y, enemy.terminal_velocity,
		"single-frame gravity should not yet hit terminal velocity")


func test_reverses_at_max_x_when_walking_right() -> void:
	enemy.patrol_min_x = 0.0
	enemy.patrol_max_x = 100.0
	enemy.direction = 1
	enemy.global_position = Vector2(101.0, 0.0)  # past max
	enemy.tick_movement(FRAME)
	assert_eq(enemy.direction, -1,
		"enemy past patrol_max_x while walking right should reverse to left")
	assert_eq(enemy.velocity.x, -enemy.walk_speed,
		"reversed enemy should walk leftward")


func test_reverses_at_min_x_when_walking_left() -> void:
	enemy.patrol_min_x = 0.0
	enemy.patrol_max_x = 100.0
	enemy.direction = -1
	enemy.global_position = Vector2(-1.0, 0.0)  # past min
	enemy.tick_movement(FRAME)
	assert_eq(enemy.direction, 1,
		"enemy past patrol_min_x while walking left should reverse to right")


func test_reverses_on_wall_contact_within_patrol_bounds() -> void:
	# Patrol bounds well outside; wall contact alone should reverse.
	enemy.patrol_min_x = -1000.0
	enemy.patrol_max_x = 1000.0
	enemy.direction = 1
	enemy.global_position = Vector2(50.0, 0.0)
	enemy.tick_movement(FRAME, true)  # on_wall=true
	assert_eq(enemy.direction, -1,
		"wall contact must reverse direction even when patrol bounds are far away")


# ---------------------------------------------------------------------------
# HP / damage
# ---------------------------------------------------------------------------

func test_hp_initialised_to_max_hp_on_ready() -> void:
	# enemy was added to tree in before_each, _ready set hp = max_hp.
	assert_eq(enemy.hp, enemy.max_hp,
		"enemy.hp should equal max_hp after _ready")


func test_take_damage_reduces_hp_without_killing_above_zero() -> void:
	enemy.max_hp = 3
	enemy.hp = 3
	enemy.take_damage(1)
	assert_eq(enemy.hp, 2,
		"taking 1 damage from 3 hp should leave 2 hp")
	assert_true(enemy.is_alive,
		"enemy with hp > 0 must remain alive")


func test_take_damage_to_zero_kills_enemy() -> void:
	enemy.max_hp = 2
	enemy.hp = 2
	enemy.take_damage(2)
	assert_eq(enemy.hp, 0)
	assert_false(enemy.is_alive,
		"hp dropping to 0 should call die() and clear is_alive")


func test_take_damage_overkill_still_kills_once() -> void:
	enemy.max_hp = 1
	enemy.hp = 1
	enemy.take_damage(99)
	assert_false(enemy.is_alive)


func test_take_damage_after_death_is_noop() -> void:
	enemy.die()
	enemy.take_damage(1)
	assert_eq(enemy.hp, 0,
		"already-dead enemy should not have hp decremented further")


# ---------------------------------------------------------------------------
# Death
# ---------------------------------------------------------------------------

func test_die_marks_enemy_not_alive() -> void:
	assert_true(enemy.is_alive, "enemy should start alive")
	enemy.die()
	assert_false(enemy.is_alive, "die() should set is_alive to false")

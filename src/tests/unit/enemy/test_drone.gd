## v0.54 — Drone hover + patrol tests.
##
## Drone inherits Enemy's hp / take_damage pipeline, so we focus tests on
## the divergent tick_movement behaviour: hover correction toward
## `hover_y` instead of gravity, and the same patrol-bound + wall reverse
## logic. Game.test_mode short-circuits _physics_process so our manual
## ticks aren't double-stepped.
extends GutTest

const DRONE_SCRIPT: GDScript = preload("res://scripts/drone.gd")
const FRAME: float = 0.016

var drone: Drone


func before_each() -> void:
	Game.test_mode = true
	drone = DRONE_SCRIPT.new()
	add_child_autofree(drone)


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Patrol movement (horizontal)
# ---------------------------------------------------------------------------

func test_walk_velocity_matches_direction_and_speed() -> void:
	drone.direction = 1
	drone.patrol_min_x = -1000.0
	drone.patrol_max_x = 1000.0
	drone.global_position = Vector2(0.0, drone.hover_y)
	drone.tick_movement(FRAME)
	assert_eq(drone.velocity.x, drone.walk_speed,
		"direction=1 should yield velocity.x = walk_speed")


func test_reverses_at_max_x_when_walking_right() -> void:
	drone.patrol_min_x = 0.0
	drone.patrol_max_x = 100.0
	drone.direction = 1
	drone.global_position = Vector2(101.0, drone.hover_y)
	drone.tick_movement(FRAME)
	assert_eq(drone.direction, -1,
		"drone past patrol_max_x walking right should reverse")


func test_reverses_at_min_x_when_walking_left() -> void:
	drone.patrol_min_x = 0.0
	drone.patrol_max_x = 100.0
	drone.direction = -1
	drone.global_position = Vector2(-1.0, drone.hover_y)
	drone.tick_movement(FRAME)
	assert_eq(drone.direction, 1,
		"drone past patrol_min_x walking left should reverse")


func test_reverses_on_wall_contact() -> void:
	drone.patrol_min_x = -1000.0
	drone.patrol_max_x = 1000.0
	drone.direction = 1
	drone.global_position = Vector2(50.0, drone.hover_y)
	drone.tick_movement(FRAME, true)
	assert_eq(drone.direction, -1,
		"wall contact must reverse direction even when patrol bounds are far away")


# ---------------------------------------------------------------------------
# Hover behaviour (vertical) — replaces Enemy's gravity
# ---------------------------------------------------------------------------

func test_hover_pulls_down_when_above_target() -> void:
	# Drone sits 20 px ABOVE its hover_y (smaller y == higher on screen),
	# so the correction should push it downward (positive velocity.y).
	drone.hover_y = 80.0
	drone.global_position = Vector2(0.0, 60.0)
	drone.tick_movement(FRAME)
	assert_gt(drone.velocity.y, 0.0,
		"drone above hover_y should pull downward (positive velocity.y)")


func test_hover_pulls_up_when_below_target() -> void:
	drone.hover_y = 80.0
	drone.global_position = Vector2(0.0, 100.0)
	drone.tick_movement(FRAME)
	assert_lt(drone.velocity.y, 0.0,
		"drone below hover_y should pull upward (negative velocity.y)")


func test_hover_velocity_does_not_accumulate_like_gravity() -> void:
	# Sanity: parking the drone exactly on hover_y should NOT yield a large
	# downward velocity after multiple ticks (which would happen under
	# gravity). The bobbing sine adds a small offset but its amplitude is
	# bounded by bob_amplitude × 6.0.
	drone.hover_y = 80.0
	drone.bob_amplitude = 4.0
	drone.global_position = Vector2(0.0, 80.0)
	for i in 30:
		drone.tick_movement(FRAME)
	# Bound the magnitude well below Enemy's terminal velocity (360).
	assert_lt(absf(drone.velocity.y), 60.0,
		"hover correction must keep velocity.y bounded — no gravity accumulation")


# ---------------------------------------------------------------------------
# HP / damage — confirm Enemy plumbing still works through Drone
# ---------------------------------------------------------------------------

func test_hp_initialised_to_max_hp_on_ready() -> void:
	assert_eq(drone.hp, drone.max_hp,
		"drone.hp should equal max_hp after _ready")


func test_take_damage_to_zero_kills_drone() -> void:
	drone.max_hp = 2
	drone.hp = 2
	drone.take_damage(2)
	assert_eq(drone.hp, 0)
	assert_false(drone.is_alive,
		"hp dropping to 0 should call die() and clear is_alive")

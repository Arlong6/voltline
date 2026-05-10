## v0.56 — Brute charging-enemy tests.
extends GutTest

const BRUTE_SCRIPT: GDScript = preload("res://scripts/brute.gd")
const FRAME: float = 0.016

var brute: Brute


func before_each() -> void:
	Game.test_mode = true
	brute = BRUTE_SCRIPT.new()
	add_child_autofree(brute)
	# Wide patrol bounds so reverse logic never triggers in the tests
	# unless explicitly testing it.
	brute.patrol_min_x = -1000.0
	brute.patrol_max_x = 1000.0


func after_each() -> void:
	Game.test_mode = false


func test_default_max_hp_is_twelve() -> void:
	assert_eq(brute.max_hp, 12,
		"v0.56 brute should spawn with 12 HP by default")


func test_idle_walks_at_walk_speed_when_no_player_in_range() -> void:
	# No player in the scene — brute should patrol normally.
	brute.direction = 1
	brute.tick_movement(FRAME)
	assert_almost_eq(brute.velocity.x, brute.walk_speed, 0.001,
		"with no player nearby, brute should patrol at walk_speed")
	assert_false(brute._is_charging,
		"_is_charging should remain false without a target in range")


func test_reverses_at_max_x_when_idle() -> void:
	brute.patrol_min_x = 0.0
	brute.patrol_max_x = 100.0
	brute.direction = 1
	brute.global_position = Vector2(101.0, 0.0)
	brute.tick_movement(FRAME)
	assert_eq(brute.direction, -1,
		"idle brute past patrol_max_x should reverse")


func test_reverses_on_wall_contact() -> void:
	brute.direction = 1
	brute.global_position = Vector2(50.0, 0.0)
	brute.tick_movement(FRAME, true)  # on_wall=true
	assert_eq(brute.direction, -1,
		"wall contact must reverse direction even mid-charge")

## v0.56 — Kamikaze flying-bomb tests.
extends GutTest

const KAMIKAZE_SCRIPT: GDScript = preload("res://scripts/kamikaze.gd")
const FRAME: float = 0.016

var kamikaze: Kamikaze


func before_each() -> void:
	Game.test_mode = true
	kamikaze = KAMIKAZE_SCRIPT.new()
	add_child_autofree(kamikaze)
	kamikaze.patrol_min_x = -1000.0
	kamikaze.patrol_max_x = 1000.0


func after_each() -> void:
	Game.test_mode = false


func test_default_max_hp_is_three() -> void:
	assert_eq(kamikaze.max_hp, 3,
		"v0.56 kamikaze should spawn with 3 HP — fragile but dangerous")


func test_idle_does_not_apply_gravity() -> void:
	# Park on hover_y; without a player, velocity.y should stay bounded
	# by the hover correction, not accumulate downward like gravity.
	kamikaze.hover_y = 80.0
	kamikaze.global_position = Vector2(0.0, 80.0)
	for i in 30:
		kamikaze.tick_movement(FRAME)
	assert_lt(absf(kamikaze.velocity.y), 60.0,
		"idle hover must keep velocity.y bounded — no gravity accumulation")


func test_idle_patrols_horizontally() -> void:
	kamikaze.direction = 1
	kamikaze.tick_movement(FRAME)
	assert_almost_eq(kamikaze.velocity.x, kamikaze.walk_speed, 0.001,
		"idle kamikaze should patrol at walk_speed")


func test_idle_reverses_at_patrol_bounds() -> void:
	kamikaze.patrol_min_x = 0.0
	kamikaze.patrol_max_x = 100.0
	kamikaze.direction = 1
	kamikaze.global_position = Vector2(101.0, 80.0)
	kamikaze.tick_movement(FRAME)
	assert_eq(kamikaze.direction, -1,
		"idle kamikaze past patrol_max_x should reverse")

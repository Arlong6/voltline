## V-004 — Dash tests.
##
## Verifies dash trigger gating (grounded only), duration, direction lock,
## walk override, and that re-pressing dash mid-dash doesn't refresh the
## timer. All tests drive tick_movement() directly with synthesized inputs.
extends GutTest

const PLAYER_SCRIPT: GDScript = preload("res://scripts/player.gd")
const FRAME: float = 0.016

var player: Player


func before_each() -> void:
	Game.test_mode = true
	player = PLAYER_SCRIPT.new()
	add_child_autofree(player)


func after_each() -> void:
	Game.test_mode = false


func test_dash_press_grounded_sets_dash_speed_in_facing_direction() -> void:
	player.facing = 1
	player.tick_movement(FRAME, 0.0, false, false, true, true)
	assert_eq(player.velocity.x, player.dash_speed,
		"grounded dash press while facing right should set velocity.x = +dash_speed")


func test_dash_press_grounded_facing_left_dashes_left() -> void:
	player.facing = -1
	player.tick_movement(FRAME, 0.0, false, false, true, true)
	assert_eq(player.velocity.x, -player.dash_speed,
		"grounded dash press while facing left should set velocity.x = -dash_speed")


func test_dash_continues_during_dash_window() -> void:
	player.facing = 1
	player.tick_movement(FRAME, 0.0, false, false, true, true)  # start
	# Mid-dash tick with no fresh dash press, no walk input.
	player.tick_movement(FRAME, 0.0, false, false, true, false)
	assert_eq(player.velocity.x, player.dash_speed,
		"dash should keep velocity.x at dash_speed for the duration")


func test_dash_ends_after_duration_returns_to_walk_speed() -> void:
	player.facing = 1
	player.tick_movement(FRAME, 0.0, false, false, true, true)  # start dash
	# Run past the dash window with no input.
	var elapsed: float = FRAME
	while elapsed < player.dash_duration + 0.05:
		player.tick_movement(FRAME, 0.0, false, false, true, false)
		elapsed += FRAME
	# Now dash should be over — input_x = 0 should yield velocity.x = 0.
	assert_eq(player.velocity.x, 0.0,
		"after dash_duration elapses, walk input must drive velocity.x")


func test_dash_press_airborne_does_not_initiate_dash_when_air_dash_disabled() -> void:
	# v0.56 enables air dash by default; disable it here so this test stays
	# focused on the legacy ground-only dash semantics. Air-dash behaviour
	# is covered in test_player_air_dash.gd.
	player.max_air_dashes = 0
	player.facing = 1
	player.tick_movement(FRAME, 0.0, false, false, false, true)  # airborne press
	assert_eq(player.velocity.x, 0.0,
		"with air dash disabled, airborne dash press should not initiate dash")


func test_dash_does_not_reverse_when_opposite_input_pressed() -> void:
	player.facing = 1
	player.tick_movement(FRAME, 0.0, false, false, true, true)  # dash starts right
	# Mid-dash, push LEFT — should NOT reverse, facing stays +1, dash speed positive.
	player.tick_movement(FRAME, -1.0, false, false, true, false)
	assert_eq(player.velocity.x, player.dash_speed,
		"dash must override opposite walk input (no mid-dash reversal)")


func test_dash_re_press_during_active_dash_does_not_refresh_timer() -> void:
	player.facing = 1
	player.tick_movement(FRAME, 0.0, false, false, true, true)  # start
	var timer_after_start: float = player._dash_timer
	# Re-press dash mid-window.
	player.tick_movement(FRAME, 0.0, false, false, true, true)
	# Timer should be lower (one frame elapsed) — NOT reset back to dash_duration.
	assert_lt(player._dash_timer, timer_after_start,
		"mid-dash dash press must not refresh _dash_timer")

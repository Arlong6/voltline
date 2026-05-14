## v0.68 — Slide + Dive tests.
##
## Drives Player.tick_movement directly with synthetic inputs. The new
## `input_y` parameter at the end of the tick_movement signature decides
## whether a dash press routes to slide / dive / regular dash.
extends GutTest

const PLAYER_SCRIPT: GDScript = preload("res://scripts/player.gd")
const FRAME: float = 0.016

var player: Player


func before_each() -> void:
	Game.test_mode = true
	player = PLAYER_SCRIPT.new()
	add_child_autofree(player)
	player.facing = 1


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Slide — DOWN + DASH on the ground
# ---------------------------------------------------------------------------

func test_slide_enters_when_dashing_with_down_on_ground() -> void:
	player.tick_movement(FRAME, 0.0, false, false, true, true, false, false, 1.0)
	assert_gt(player.slide_timer, 0.0,
		"DOWN+DASH on the ground should engage the slide")


func test_slide_velocity_uses_slide_speed_facing_direction() -> void:
	player.tick_movement(FRAME, 0.0, false, false, true, true, false, false, 1.0)
	assert_almost_eq(player.velocity.x, player.slide_speed, 0.001,
		"slide.x must equal slide_speed in the facing direction")


func test_slide_does_not_engage_without_down_input() -> void:
	player.tick_movement(FRAME, 0.0, false, false, true, true, false, false, 0.0)
	assert_eq(player.slide_timer, 0.0,
		"plain DASH on the ground should not engage the slide")


func test_slide_does_not_engage_in_the_air() -> void:
	# Airborne + DOWN + DASH should route to dive, not slide.
	player.tick_movement(FRAME, 0.0, false, false, false, true, false, false, 1.0)
	assert_eq(player.slide_timer, 0.0,
		"DOWN+DASH airborne must not engage the slide")


func test_slide_decays_after_slide_duration() -> void:
	player.tick_movement(FRAME, 0.0, false, false, true, true, false, false, 1.0)
	# Now run plain ticks until slide expires.
	var safety: int = 200
	while player.slide_timer > 0.0 and safety > 0:
		player.tick_movement(FRAME, 0.0, false, false, true, false, false, false, 0.0)
		safety -= 1
	assert_eq(player.slide_timer, 0.0,
		"slide_timer must decay to zero within a bounded number of ticks")


# ---------------------------------------------------------------------------
# Dive — DOWN + DASH in the air
# ---------------------------------------------------------------------------

func test_dive_enters_when_dashing_with_down_airborne() -> void:
	player.tick_movement(FRAME, 0.0, false, false, false, true, false, false, 1.0)
	assert_true(player.is_diving,
		"DOWN+DASH airborne should engage the dive")


func test_dive_locks_velocity_to_dive_speed() -> void:
	player.tick_movement(FRAME, 0.0, false, false, false, true, false, false, 1.0)
	assert_almost_eq(player.velocity.y, player.dive_speed, 0.001,
		"dive.y must equal dive_speed while diving")
	# x velocity is clamped to zero during the dive — straight drop.
	assert_almost_eq(player.velocity.x, 0.0, 0.001,
		"dive should zero horizontal velocity")


func test_dive_ends_on_landing_and_sets_one_shot_flag() -> void:
	# Engage dive in the air.
	player.tick_movement(FRAME, 0.0, false, false, false, true, false, false, 1.0)
	assert_true(player.is_diving)
	# Next tick — touchdown. Plain dash_pressed=false, is_grounded=true.
	player.tick_movement(FRAME, 0.0, false, false, true, false, false, false, 0.0)
	assert_false(player.is_diving,
		"is_diving must clear on touchdown")
	assert_true(player.did_dive_land_this_tick,
		"did_dive_land_this_tick should fire exactly once on touchdown")


func test_dive_land_flag_clears_next_tick() -> void:
	# Set up the landing tick from the previous test.
	player.tick_movement(FRAME, 0.0, false, false, false, true, false, false, 1.0)
	player.tick_movement(FRAME, 0.0, false, false, true, false, false, false, 0.0)
	# A subsequent tick on the ground without diving should NOT keep the flag set.
	player.tick_movement(FRAME, 0.0, false, false, true, false, false, false, 0.0)
	assert_false(player.did_dive_land_this_tick,
		"did_dive_land_this_tick is a one-shot — must clear the next tick")

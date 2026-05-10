## v0.55 — Player double / multi-jump tests.
##
## Air jumps fire when the player presses jump while truly airborne (no
## coyote left), draw from a per-leap pool of `max_air_jumps` charges,
## and refill only on ground contact (not on wall slide). Wall-jump
## priority over air jump is verified explicitly.
extends GutTest

const PLAYER_SCRIPT: GDScript = preload("res://scripts/player.gd")
const FRAME: float = 0.016

var player: Player


func before_each() -> void:
	Game.test_mode = true
	player = PLAYER_SCRIPT.new()
	add_child_autofree(player)
	# Default: max_air_jumps = 1 (double jump enabled).


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Air jump triggers
# ---------------------------------------------------------------------------

func test_default_max_air_jumps_is_one() -> void:
	assert_eq(player.max_air_jumps, 1,
		"v0.55 default: 1 air jump = double jump enabled by default")


func test_air_jump_fires_when_airborne_with_no_coyote() -> void:
	# Coyote starts at 0 (never grounded), so the very first airborne jump
	# press must be served by the air-jump branch.
	player.velocity = Vector2.ZERO
	player.tick_movement(FRAME, 0.0, true, true, false)
	assert_almost_eq(player.velocity.y, player.air_jump_velocity, 0.001,
		"airborne jump press without coyote should set velocity.y = air_jump_velocity")
	assert_true(player.did_air_jump_this_tick,
		"did_air_jump_this_tick should latch true on the air-jump tick")


func test_air_jump_consumes_one_charge() -> void:
	player.velocity = Vector2.ZERO
	# Spend the only air jump.
	player.tick_movement(FRAME, 0.0, true, true, false)
	# Second airborne press — no charges remain → only buffer should arm,
	# velocity.y must NOT match air_jump_velocity again.
	player.velocity.y = 0.0
	player.tick_movement(FRAME, 0.0, true, true, false)
	assert_gt(player.velocity.y, 0.0,
		"air-jump charges depleted → second airborne press should not re-fire")


func test_two_air_jumps_when_max_is_two() -> void:
	# Triple jump configuration: 1 ground + 2 air.
	player.max_air_jumps = 2
	player.velocity = Vector2.ZERO
	player.tick_movement(FRAME, 0.0, true, true, false)
	var first_y: float = player.velocity.y
	assert_almost_eq(first_y, player.air_jump_velocity, 0.001,
		"first air jump should fire")
	# Reset velocity to isolate the second jump's contribution.
	player.velocity.y = 0.0
	player.tick_movement(FRAME, 0.0, true, true, false)
	assert_almost_eq(player.velocity.y, player.air_jump_velocity, 0.001,
		"second air jump should also fire when max_air_jumps = 2")


# ---------------------------------------------------------------------------
# Charge refill
# ---------------------------------------------------------------------------

func test_landing_refills_air_jump_charges() -> void:
	# Burn the charge.
	player.tick_movement(FRAME, 0.0, true, true, false)
	# Land — should refill _air_jumps_used.
	player.tick_movement(FRAME, 0.0, false, false, true)
	# Leave ground and burn through the coyote window — otherwise the
	# next jump press would be served by coyote, not the refilled air jump.
	var elapsed: float = 0.0
	while elapsed < player.coyote_time + 0.05:
		player.tick_movement(FRAME, 0.0, false, false, false)
		elapsed += FRAME
	# Now press jump — air jump should re-fire from the refilled pool.
	player.velocity.y = 0.0
	player.tick_movement(FRAME, 0.0, true, true, false)
	assert_almost_eq(player.velocity.y, player.air_jump_velocity, 0.001,
		"landing must refill air-jump charges so the next airborne press fires")


# ---------------------------------------------------------------------------
# Priority — coyote and wall jump must beat air jump
# ---------------------------------------------------------------------------

func test_coyote_jump_takes_priority_over_air_jump() -> void:
	# Establish grounded → arms coyote, refills air jumps.
	player.tick_movement(FRAME, 0.0, false, false, true)
	# Immediately go airborne and press jump within the coyote window.
	player.velocity.y = 0.0
	player.tick_movement(FRAME, 0.0, true, true, false)
	# Should be the regular jump_velocity (-280), NOT air_jump_velocity (-240).
	assert_almost_eq(player.velocity.y, player.jump_velocity, 0.001,
		"coyote-window jump should fire jump_velocity, not air_jump_velocity")
	assert_false(player.did_air_jump_this_tick,
		"coyote jump should not flag did_air_jump_this_tick")


func test_wall_jump_takes_priority_over_air_jump() -> void:
	# Set up a wall slide situation, press jump.
	player.velocity = Vector2(0.0, 50.0)
	player.facing = -1
	# input_x=-1 (into left wall), jump_pressed=true, jump_held=true,
	# is_grounded=false, dash_pressed=false, is_wall_left=true.
	player.tick_movement(0.0, -1.0, true, true, false, false, true, false)
	assert_almost_eq(player.velocity.y, player.wall_jump_velocity.y, 0.001,
		"wall-slide jump should fire wall_jump_velocity.y, not air_jump_velocity")
	assert_false(player.did_air_jump_this_tick,
		"wall jump should not consume an air-jump charge")


# ---------------------------------------------------------------------------
# Disabled configuration
# ---------------------------------------------------------------------------

func test_max_air_jumps_zero_disables_double_jump() -> void:
	player.max_air_jumps = 0
	player.velocity = Vector2.ZERO
	player.tick_movement(FRAME, 0.0, true, true, false)
	assert_gt(player.velocity.y, 0.0,
		"max_air_jumps=0 should restore single-jump behaviour")
	assert_false(player.did_air_jump_this_tick)


# ---------------------------------------------------------------------------
# Wall-slide policy — wall slide must NOT refill air jumps
# ---------------------------------------------------------------------------

func test_wall_slide_does_not_refill_air_jump_charges() -> void:
	# Burn the air jump.
	player.tick_movement(FRAME, 0.0, true, true, false)
	# Wall slide for a few ticks (input into left wall, falling, airborne).
	# Wall sliding alone must NOT refill the spent air jump.
	player.velocity = Vector2(0.0, 50.0)
	for i in 4:
		player.tick_movement(FRAME, -1.0, false, false, false, false, true, false)
	# Press jump while wall-sliding — should be a wall jump (priority),
	# not a refilled air jump. We verify by clearing wall flags and pressing
	# again afterwards: the air-jump charge should still be spent.
	player.tick_movement(FRAME, -1.0, true, true, false, false, true, false)
	# Now leave the wall (no wall flags) and press again — no air jump
	# should be available since the wall slide didn't refill.
	player.velocity.y = 0.0
	# Burn out wall_jump_lockout so input isn't suppressed.
	var elapsed: float = 0.0
	while elapsed < player.wall_jump_lockout + 0.05:
		player.tick_movement(FRAME, 0.0, false, false, false)
		elapsed += FRAME
	player.velocity.y = 0.0
	player.tick_movement(FRAME, 0.0, true, true, false)
	assert_gt(player.velocity.y, 0.0,
		"wall slide must not refill air jumps — second airborne press should NOT fire")

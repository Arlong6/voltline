## v0.56 — Player air-dash tests.
##
## Air dashes fire on dash_pressed while airborne, draw from a pool of
## `max_air_dashes` charges, and refill only on ground contact. Vertical
## velocity is wiped on activation so the dash blasts cleanly horizontal.
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


# ---------------------------------------------------------------------------
# Activation
# ---------------------------------------------------------------------------

func test_default_max_air_dashes_is_one() -> void:
	assert_eq(player.max_air_dashes, 1,
		"v0.56 default: one mid-air dash charge")


func test_air_dash_fires_when_airborne_with_dash_pressed() -> void:
	player.facing = 1
	player.velocity = Vector2(0.0, 200.0)  # falling
	player.tick_movement(FRAME, 0.0, false, false, false, true)  # dash_pressed=true, airborne
	assert_true(player.did_air_dash_this_tick,
		"airborne dash press should latch did_air_dash_this_tick")
	assert_almost_eq(player.velocity.x, player.dash_speed, 0.001,
		"air dash should set velocity.x = facing × dash_speed")
	assert_almost_eq(player.velocity.y, 0.0, 0.001,
		"air dash must wipe vertical velocity for a flat blast")


func test_air_dash_consumes_one_charge() -> void:
	player.tick_movement(FRAME, 0.0, false, false, false, true)
	# Wait for the dash to end so a second press isn't blocked by _dash_timer.
	var elapsed: float = 0.0
	while elapsed < player.dash_duration + 0.05:
		player.tick_movement(FRAME, 0.0, false, false, false)
		elapsed += FRAME
	# Second airborne dash press — pool is empty, no dash should fire.
	player.tick_movement(FRAME, 0.0, false, false, false, true)
	assert_false(player.did_air_dash_this_tick,
		"second airborne dash press without refill must not fire")


# ---------------------------------------------------------------------------
# Charge refill
# ---------------------------------------------------------------------------

func test_landing_refills_air_dash_charge() -> void:
	# Burn the charge.
	player.tick_movement(FRAME, 0.0, false, false, false, true)
	# Wait for dash to expire.
	var elapsed: float = 0.0
	while elapsed < player.dash_duration + 0.05:
		player.tick_movement(FRAME, 0.0, false, false, false)
		elapsed += FRAME
	# Land — refills _air_dashes_used.
	player.tick_movement(FRAME, 0.0, false, false, true)
	# Leave ground; press dash again — should re-fire.
	player.tick_movement(FRAME, 0.0, false, false, false, true)
	assert_true(player.did_air_dash_this_tick,
		"landing must refill air-dash pool")


# ---------------------------------------------------------------------------
# Disabled configuration
# ---------------------------------------------------------------------------

func test_max_air_dashes_zero_blocks_air_dash() -> void:
	player.max_air_dashes = 0
	player.tick_movement(FRAME, 0.0, false, false, false, true)
	assert_false(player.did_air_dash_this_tick,
		"max_air_dashes=0 should block air dashes entirely")


# ---------------------------------------------------------------------------
# Independence from air jumps
# ---------------------------------------------------------------------------

func test_air_dash_does_not_consume_air_jump_charge() -> void:
	# Trigger an air dash.
	player.tick_movement(FRAME, 0.0, false, false, false, true)
	# Wait dash out so the next press can re-arm.
	var elapsed: float = 0.0
	while elapsed < player.dash_duration + 0.05:
		player.tick_movement(FRAME, 0.0, false, false, false)
		elapsed += FRAME
	# Now press jump airborne — air jump should still fire (charge intact).
	player.velocity.y = 0.0
	player.tick_movement(FRAME, 0.0, true, true, false)
	assert_true(player.did_air_jump_this_tick,
		"air dash and air jump pools must be independent")

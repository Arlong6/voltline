## V-002 — Player controller logic tests.
##
## All tests drive Player.tick_movement() directly with synthesized inputs
## so neither the real physics world nor the input device is involved.
## Game.test_mode is set so any accidental _physics_process call short-
## circuits without double-stepping the controller.
extends GutTest

const PLAYER_SCRIPT: GDScript = preload("res://scripts/player.gd")

# Standard 60fps frame delta — matches Godot's default physics tick.
const FRAME: float = 0.016

var player: Player


func before_each() -> void:
	Game.test_mode = true
	player = PLAYER_SCRIPT.new()
	add_child_autofree(player)


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Gravity
# ---------------------------------------------------------------------------

func test_gravity_accumulates_below_terminal() -> void:
	player.velocity = Vector2.ZERO
	player.tick_movement(FRAME, 0.0, false, false, false)
	assert_gt(player.velocity.y, 0.0,
		"airborne tick should add positive (downward) velocity from gravity")
	assert_lt(player.velocity.y, player.terminal_velocity,
		"single-frame gravity should not yet hit terminal velocity")


func test_gravity_clamps_at_terminal_velocity() -> void:
	player.velocity = Vector2(0.0, 350.0)
	# One frame at 800 px/s² adds ~12.8 px/s, which would exceed 360 → clamp.
	player.tick_movement(FRAME, 0.0, false, false, false)
	assert_almost_eq(player.velocity.y, player.terminal_velocity, 0.001,
		"velocity.y must clamp to terminal_velocity")


# ---------------------------------------------------------------------------
# Walk
# ---------------------------------------------------------------------------

func test_walk_left_sets_negative_x_velocity() -> void:
	player.tick_movement(FRAME, -1.0, false, false, true)
	assert_eq(player.velocity.x, -player.walk_speed,
		"input_x = -1 should yield velocity.x = -walk_speed")


func test_walk_right_sets_positive_x_velocity() -> void:
	player.tick_movement(FRAME, 1.0, false, false, true)
	assert_eq(player.velocity.x, player.walk_speed,
		"input_x = 1 should yield velocity.x = walk_speed")


func test_no_input_zeroes_x_velocity() -> void:
	player.velocity = Vector2(50.0, 0.0)
	player.tick_movement(FRAME, 0.0, false, false, true)
	assert_eq(player.velocity.x, 0.0,
		"input_x = 0 should zero velocity.x (no momentum / no friction)")


# ---------------------------------------------------------------------------
# Jump trigger
# ---------------------------------------------------------------------------

func test_jump_press_while_grounded_sets_jump_velocity() -> void:
	player.velocity = Vector2.ZERO
	player.tick_movement(FRAME, 0.0, true, true, true)
	assert_eq(player.velocity.y, player.jump_velocity,
		"grounded jump press should set velocity.y = jump_velocity")


func test_jump_press_while_airborne_does_not_jump() -> void:
	# Disable air jumps so this test stays focused on coyote/buffer
	# semantics — air-jump behaviour is covered in test_player_air_jump.gd.
	player.max_air_jumps = 0
	player.velocity = Vector2.ZERO
	# Coyote timer is 0 by default (never been grounded); pressing jump in
	# the air should arm the buffer but NOT fire a jump.
	player.tick_movement(FRAME, 0.0, true, true, false)
	assert_gt(player.velocity.y, 0.0,
		"airborne jump press without coyote → no upward velocity (gravity only)")


# ---------------------------------------------------------------------------
# Coyote time
# ---------------------------------------------------------------------------

func test_coyote_time_allows_jump_after_leaving_ground() -> void:
	# Establish grounded → coyote timer = coyote_time.
	player.tick_movement(FRAME, 0.0, false, false, true)
	# Immediately go airborne and press jump within the coyote window.
	player.velocity.y = 0.0
	player.tick_movement(FRAME, 0.0, true, true, false)
	assert_eq(player.velocity.y, player.jump_velocity,
		"jump press within coyote window after leaving ground should fire")


func test_coyote_time_expires_after_window() -> void:
	# Disable air jumps so this test isolates coyote behaviour.
	player.max_air_jumps = 0
	# Establish grounded.
	player.tick_movement(FRAME, 0.0, false, false, true)
	# Spend 0.15s airborne (past the 0.1s coyote window) without input.
	var elapsed: float = 0.0
	while elapsed < 0.15:
		player.tick_movement(FRAME, 0.0, false, false, false)
		elapsed += FRAME
	# Now press jump — coyote has expired, only buffer should arm.
	player.velocity.y = 0.0
	player.tick_movement(FRAME, 0.0, true, true, false)
	assert_gt(player.velocity.y, 0.0,
		"coyote-expired jump press should not produce upward velocity")


# ---------------------------------------------------------------------------
# Jump buffer
# ---------------------------------------------------------------------------

func test_jump_buffer_consumed_on_landing() -> void:
	# Disable air jumps so the airborne press arms the buffer instead of
	# being consumed by an air-jump charge.
	player.max_air_jumps = 0
	player.velocity = Vector2.ZERO
	# Tick 1 — airborne, press jump → buffer armed.
	player.tick_movement(FRAME, 0.0, true, true, false)
	# Tick 2 — still airborne, no fresh press.
	player.tick_movement(FRAME, 0.0, false, false, false)
	# Tick 3 — land (no fresh press) — buffer should fire the jump.
	player.tick_movement(FRAME, 0.0, false, false, true)
	assert_eq(player.velocity.y, player.jump_velocity,
		"buffered jump press must fire on landing")


func test_jump_buffer_expires_after_window() -> void:
	# Disable air jumps so the airborne press arms the buffer instead of
	# consuming an air-jump charge.
	player.max_air_jumps = 0
	player.velocity = Vector2.ZERO
	# Arm the buffer with an airborne press.
	player.tick_movement(FRAME, 0.0, true, true, false)
	# Stay airborne for 0.15s without a fresh press → buffer expires.
	var elapsed: float = FRAME
	while elapsed < 0.15:
		player.tick_movement(FRAME, 0.0, false, false, false)
		elapsed += FRAME
	# Land now — buffer should be empty, no jump.
	player.tick_movement(FRAME, 0.0, false, false, true)
	assert_gt(player.velocity.y, 0.0,
		"expired buffer should not fire on landing")


# ---------------------------------------------------------------------------
# Variable jump (short-hop cutoff)
# ---------------------------------------------------------------------------

func test_variable_jump_cutoff_when_released_early() -> void:
	# Frame 1 — grounded, jump pressed AND held → fires standard jump.
	player.velocity = Vector2.ZERO
	player.tick_movement(0.0, 0.0, true, true, true)
	assert_eq(player.velocity.y, player.jump_velocity,
		"sanity check: standard jump should set velocity.y")
	# Frame 2 — airborne, jump released. delta = 0 isolates the cutoff math
	# from gravity so the assertion stays exact.
	player.tick_movement(0.0, 0.0, false, false, false)
	assert_almost_eq(
		player.velocity.y,
		player.jump_velocity * player.short_hop_factor,
		0.001,
		"releasing jump while rising should multiply velocity.y by short_hop_factor"
	)


func test_variable_jump_no_cutoff_when_falling() -> void:
	# Player is falling (positive y velocity) and releases jump → cutoff
	# logic should not apply (only rising velocity gets shortened).
	player.velocity = Vector2(0.0, 100.0)
	player._jump_was_held = true
	player.tick_movement(0.0, 0.0, false, false, false)
	assert_eq(player.velocity.y, 100.0,
		"jump release while falling must not multiply velocity.y")


# ---------------------------------------------------------------------------
# Airborne control (preserves dash-jump and wall-jump momentum)
# ---------------------------------------------------------------------------

func test_air_preserves_horizontal_momentum_when_no_input() -> void:
	# Simulates the post-wall-jump arc once lockout has expired: player has
	# horizontal velocity, no input — momentum must persist (no air friction).
	player.velocity = Vector2(180.0, 0.0)
	player.tick_movement(0.0, 0.0, false, false, false)
	assert_almost_eq(player.velocity.x, 180.0, 0.001,
		"airborne with no input should preserve velocity.x")


func test_air_pressing_same_direction_preserves_higher_boost() -> void:
	# Dashing right (220 px/s), jump-ending mid-air, player still pressing
	# right — boost should NOT drop to walk_speed.
	player.velocity = Vector2(220.0, 0.0)
	player.tick_movement(0.0, 1.0, false, false, false)
	assert_almost_eq(player.velocity.x, 220.0, 0.001,
		"airborne pressing same direction must preserve higher dash speed")


func test_air_pressing_opposite_direction_snaps_to_walk_speed() -> void:
	# Player flying right at 220, presses left → instant air-control flip
	# to -walk_speed.
	player.velocity = Vector2(220.0, 0.0)
	player.tick_movement(0.0, -1.0, false, false, false)
	assert_almost_eq(player.velocity.x, -player.walk_speed, 0.001,
		"airborne opposite-direction press should snap to -walk_speed")


func test_air_pressing_direction_below_walk_speed_boosts_to_walk_speed() -> void:
	# Slow drift (50 px/s), player presses same direction — should pop up
	# to walk_speed, not stay at 50 (player input should give meaningful response).
	player.velocity = Vector2(50.0, 0.0)
	player.tick_movement(0.0, 1.0, false, false, false)
	assert_almost_eq(player.velocity.x, player.walk_speed, 0.001,
		"airborne press with sub-walk-speed momentum should rise to walk_speed")

## V-005 — Wall slide and wall jump tests.
##
## Drives Player.tick_movement() with synthesized wall flags. Wall-side
## detection is a pure parameter (is_wall_left / is_wall_right) — the real
## CharacterBody2D physics that derives them is exercised by playtest.
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
# Wall slide engagement
# ---------------------------------------------------------------------------

func test_wall_slide_clamps_fall_speed_when_pressing_left_into_left_wall() -> void:
	player.velocity = Vector2(0.0, 200.0)  # falling fast
	# delta=0 isolates the slide clamp from the gravity step.
	player.tick_movement(0.0, -1.0, false, false, false, false, true, false)
	assert_almost_eq(player.velocity.y, player.wall_slide_speed, 0.001,
		"wall slide should clamp velocity.y to wall_slide_speed")
	assert_true(player.is_wall_sliding,
		"is_wall_sliding flag should be set during a slide")


func test_wall_slide_clamps_fall_speed_when_pressing_right_into_right_wall() -> void:
	player.velocity = Vector2(0.0, 200.0)
	player.tick_movement(0.0, 1.0, false, false, false, false, false, true)
	assert_almost_eq(player.velocity.y, player.wall_slide_speed, 0.001,
		"right-wall slide should also clamp velocity.y to wall_slide_speed")


func test_wall_slide_does_not_engage_when_grounded() -> void:
	player.velocity = Vector2(0.0, 200.0)
	# is_grounded = true → no wall slide regardless of wall touch.
	player.tick_movement(0.0, -1.0, false, false, true, false, true, false)
	assert_false(player.is_wall_sliding,
		"grounded player must not register as wall sliding")


func test_wall_slide_does_not_engage_when_rising() -> void:
	player.velocity = Vector2(0.0, -100.0)  # rising
	player.tick_movement(0.0, -1.0, false, false, false, false, true, false)
	assert_false(player.is_wall_sliding,
		"slide must require velocity.y > 0 (falling)")


func test_wall_slide_does_not_engage_without_pressing_input() -> void:
	player.velocity = Vector2(0.0, 200.0)
	# No directional input — touching wall but not pressing into it.
	player.tick_movement(0.0, 0.0, false, false, false, false, true, false)
	assert_false(player.is_wall_sliding,
		"slide must require directional input pressing INTO the wall")


func test_wall_slide_does_not_engage_when_pressing_away_from_wall() -> void:
	player.velocity = Vector2(0.0, 200.0)
	# Wall on left, but player presses RIGHT (away from wall).
	player.tick_movement(0.0, 1.0, false, false, false, false, true, false)
	assert_false(player.is_wall_sliding,
		"slide must NOT engage when pressing away from the wall")


# ---------------------------------------------------------------------------
# Wall jump
# ---------------------------------------------------------------------------

func test_wall_jump_left_wall_kicks_right_and_up() -> void:
	# Set up a wall slide situation, then press jump.
	player.velocity = Vector2(0.0, 50.0)
	player.facing = -1
	player.tick_movement(0.0, -1.0, true, true, false, false, true, false)
	assert_almost_eq(player.velocity.y, player.wall_jump_velocity.y, 0.001,
		"wall jump should set velocity.y = wall_jump_velocity.y (negative)")
	assert_almost_eq(player.velocity.x, player.wall_jump_velocity.x, 0.001,
		"left-wall jump should push positive (right)")


func test_wall_jump_right_wall_kicks_left_and_up() -> void:
	player.velocity = Vector2(0.0, 50.0)
	player.facing = 1
	player.tick_movement(0.0, 1.0, true, true, false, false, false, true)
	assert_almost_eq(player.velocity.y, player.wall_jump_velocity.y, 0.001,
		"wall jump from right wall should still set vertical lift")
	assert_almost_eq(player.velocity.x, -player.wall_jump_velocity.x, 0.001,
		"right-wall jump should push negative (left)")


func test_wall_jump_changes_facing_to_away_from_wall() -> void:
	player.velocity = Vector2(0.0, 50.0)
	player.facing = -1  # was facing into left wall
	player.tick_movement(0.0, -1.0, true, true, false, false, true, false)
	assert_eq(player.facing, 1,
		"after wall-jumping a left wall, facing should flip to right (+1)")


func test_wall_jump_locks_horizontal_input_for_lockout_duration() -> void:
	# Trigger the wall jump.
	player.velocity = Vector2(0.0, 50.0)
	player.facing = -1
	player.tick_movement(0.0, -1.0, true, true, false, false, true, false)
	var x_after_jump: float = player.velocity.x
	# Next tick — try to walk LEFT (back into the wall). Lockout should
	# preserve the wall-jump push instead of overwriting velocity.x.
	player.tick_movement(0.0, -1.0, false, false, false, false, false, false)
	assert_almost_eq(player.velocity.x, x_after_jump, 0.001,
		"velocity.x must be preserved during wall_jump_lockout")


func test_wall_jump_lockout_expires_returns_horizontal_control() -> void:
	# Trigger wall jump.
	player.velocity = Vector2(0.0, 50.0)
	player.facing = -1
	player.tick_movement(FRAME, -1.0, true, true, false, false, true, false)
	# Burn lockout by ticking past wall_jump_lockout seconds with no input.
	var elapsed: float = FRAME
	while elapsed < player.wall_jump_lockout + 0.05:
		player.tick_movement(FRAME, 0.0, false, false, false, false, false, false)
		elapsed += FRAME
	# Now press LEFT — control should be back, velocity.x = -walk_speed.
	player.tick_movement(FRAME, -1.0, false, false, false, false, false, false)
	assert_almost_eq(player.velocity.x, -player.walk_speed, 0.001,
		"after lockout expires, walk input should drive velocity.x normally")

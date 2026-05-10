## V-003 — Player facing tests.
##
## Verifies that horizontal input rotates the `facing` field, that no input
## preserves the prior facing, and that an active dash locks facing.
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


func test_facing_starts_right() -> void:
	assert_eq(player.facing, 1,
		"default facing should be +1 (right) on spawn")


func test_walk_right_sets_facing_right() -> void:
	player.facing = -1
	player.tick_movement(FRAME, 1.0, false, false, true)
	assert_eq(player.facing, 1,
		"input_x = +1 should flip facing to right")


func test_walk_left_sets_facing_left() -> void:
	player.tick_movement(FRAME, -1.0, false, false, true)
	assert_eq(player.facing, -1,
		"input_x = -1 should flip facing to left")


func test_no_input_preserves_facing() -> void:
	player.tick_movement(FRAME, -1.0, false, false, true)  # face left
	player.tick_movement(FRAME, 0.0, false, false, true)
	assert_eq(player.facing, -1,
		"input_x = 0 must not reset facing")


func test_facing_locked_during_dash() -> void:
	# Initiate dash facing right.
	player.facing = 1
	player.tick_movement(FRAME, 0.0, false, false, true, true)
	# Now press LEFT during dash — facing should NOT flip until dash ends.
	player.tick_movement(FRAME, -1.0, false, false, false, false)
	assert_eq(player.facing, 1,
		"facing must stay locked while _dash_timer > 0")

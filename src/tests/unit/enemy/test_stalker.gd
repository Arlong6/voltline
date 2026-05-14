## v0.68 — Stalker chase logic tests.
##
## Drives Stalker.tick_movement directly with synthesized player positions
## and asserts the horizontal pull + hover-offset behaviour.
extends GutTest

const STALKER_SCRIPT: GDScript = preload("res://scripts/stalker.gd")
const FRAME: float = 0.016

var stalker: Stalker


func before_each() -> void:
	Game.test_mode = true
	stalker = STALKER_SCRIPT.new()
	add_child_autofree(stalker)


func after_each() -> void:
	Game.test_mode = false


func test_chases_right_when_player_is_to_the_right() -> void:
	stalker.global_position = Vector2(0.0, 0.0)
	stalker.tick_chase(FRAME, Vector2(200.0, 0.0))
	assert_gt(stalker.velocity.x, 0.0,
		"player to the right must produce a positive horizontal velocity")


func test_chases_left_when_player_is_to_the_left() -> void:
	stalker.global_position = Vector2(0.0, 0.0)
	stalker.tick_chase(FRAME, Vector2(-200.0, 0.0))
	assert_lt(stalker.velocity.x, 0.0)


func test_hovers_above_player_by_offset() -> void:
	# Stalker is BELOW the desired hover line — should accelerate upward.
	stalker.global_position = Vector2(100.0, 100.0)
	# Target_y = player.y + hover_offset_y = 80 + -60 = 20. We are at y=100,
	# so dy = 20 - 100 = -80 (negative = upward). velocity.y should be < 0.
	stalker.tick_chase(FRAME, Vector2(100.0, 80.0))
	assert_lt(stalker.velocity.y, 0.0,
		"if the stalker is below its hover line, it must pull upward")


func test_no_horizontal_motion_when_aligned_with_player() -> void:
	stalker.global_position = Vector2(100.0, 100.0)
	stalker.tick_chase(FRAME, Vector2(100.0, 200.0))
	assert_almost_eq(stalker.velocity.x, 0.0, 0.001,
		"perfect x alignment should produce zero horizontal pull")


func test_facing_flips_toward_player() -> void:
	stalker.global_position = Vector2(0.0, 0.0)
	stalker.tick_chase(FRAME, Vector2(50.0, 0.0))
	assert_eq(stalker.direction, 1,
		"chasing right should flip direction to +1")
	stalker.tick_chase(FRAME, Vector2(-50.0, 0.0))
	assert_eq(stalker.direction, -1,
		"chasing left should flip direction to -1")

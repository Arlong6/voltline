## v0.66 — Spitter ballistic lob tests.
##
## lob_velocity_for is a pure function — given self pos + target coords +
## the spitter's tuning, it returns the launch velocity for a gravity-
## affected EnemyBullet. We assert the velocity has the right horizontal
## sign, an upward component, and obeys the max-speed clamp.
extends GutTest

const SPITTER_SCRIPT: GDScript = preload("res://scripts/spitter.gd")

var spitter: Spitter


func before_each() -> void:
	Game.test_mode = true
	spitter = SPITTER_SCRIPT.new()
	add_child_autofree(spitter)


func after_each() -> void:
	Game.test_mode = false


func test_lob_aims_horizontally_toward_target_on_right() -> void:
	var v: Vector2 = spitter.lob_velocity_for(
		Vector2(100.0, 100.0), 200.0, 100.0
	)
	assert_gt(v.x, 0.0,
		"target to the right must produce a positive horizontal velocity")
	assert_lt(v.y, 0.0,
		"a lob launches upward — y component must be negative")


func test_lob_aims_horizontally_toward_target_on_left() -> void:
	var v: Vector2 = spitter.lob_velocity_for(
		Vector2(100.0, 100.0), 20.0, 100.0
	)
	assert_lt(v.x, 0.0,
		"target to the left must produce a negative horizontal velocity")


func test_lob_speed_clamped_for_distant_target() -> void:
	# Far enough away that the unclamped ballistic speed exceeds the cap.
	var v: Vector2 = spitter.lob_velocity_for(
		Vector2(0.0, 0.0), 10000.0, 0.0
	)
	assert_lte(v.length(), spitter.max_launch_speed + 0.01,
		"launch speed must not exceed max_launch_speed")


func test_lob_yields_nonzero_velocity_for_nearby_target() -> void:
	var v: Vector2 = spitter.lob_velocity_for(
		Vector2(100.0, 100.0), 130.0, 100.0
	)
	assert_gt(v.length(), 0.0,
		"a nearby target should still produce a non-zero lob")

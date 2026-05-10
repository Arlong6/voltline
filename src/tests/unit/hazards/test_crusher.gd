## v0.59 — Crusher 4-phase state machine test.
extends GutTest

const CRUSHER_SCRIPT: GDScript = preload("res://scripts/crusher.gd")
const FRAME: float = 0.016

var crusher: Crusher


func before_each() -> void:
	Game.test_mode = true
	crusher = CRUSHER_SCRIPT.new()
	add_child_autofree(crusher)


func after_each() -> void:
	Game.test_mode = false


func test_starts_in_idle_phase() -> void:
	assert_eq(crusher._phase, Crusher.Phase.IDLE,
		"crusher should start in IDLE")


func test_transitions_idle_to_slam_after_idle_time() -> void:
	crusher.idle_time = 0.5
	# Tick past idle_time.
	var elapsed: float = 0.0
	while elapsed < crusher.idle_time + FRAME:
		crusher.tick(FRAME)
		elapsed += FRAME
	assert_eq(crusher._phase, Crusher.Phase.SLAM,
		"after idle_time elapses, phase should advance to SLAM")


func test_slam_descends_to_full_distance() -> void:
	crusher.idle_time = 0.0
	crusher.slam_time = 0.2
	crusher.slam_distance = 100.0
	# Tick through idle (0s) and the full slam.
	var elapsed: float = 0.0
	while elapsed < 0.25:
		crusher.tick(FRAME)
		elapsed += FRAME
	assert_almost_eq(crusher.current_offset_y, 100.0, 1.0,
		"after slam_time, crusher should be at full slam_distance offset")


func test_full_cycle_returns_to_origin() -> void:
	crusher.idle_time = 0.1
	crusher.slam_time = 0.1
	crusher.hold_time = 0.1
	crusher.retract_time = 0.1
	crusher.slam_distance = 80.0
	# Total cycle = 0.4s; tick a full cycle + small slack.
	var elapsed: float = 0.0
	while elapsed < 0.45:
		crusher.tick(FRAME)
		elapsed += FRAME
	# After a full cycle the crusher should be back in IDLE at zero offset.
	assert_eq(crusher._phase, Crusher.Phase.IDLE,
		"after one full cycle, phase should be IDLE again")
	assert_almost_eq(crusher.current_offset_y, 0.0, 1.0,
		"crusher should return to zero offset after a full cycle")

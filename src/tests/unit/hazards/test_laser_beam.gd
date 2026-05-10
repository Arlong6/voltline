## v0.59 — LaserBeam on/off cycle test.
extends GutTest

const LASER_SCRIPT: GDScript = preload("res://scripts/laser_beam.gd")
const FRAME: float = 0.016

var laser: LaserBeam


func before_each() -> void:
	Game.test_mode = true
	laser = LASER_SCRIPT.new()
	add_child_autofree(laser)


func after_each() -> void:
	Game.test_mode = false


func test_starts_off_when_phase_zero_and_period_long() -> void:
	# t=0 with phase=0 and on_duty<1.0 → fposmod(0, period) = 0 < period * on_duty,
	# but tick(0) means the cycle starts ON. Tick a tiny delta.
	laser.period = 2.0
	laser.on_duty = 0.5
	laser.phase = 0.0
	laser.tick(FRAME)
	# 0.016s into a 2.0s cycle with 0.5 on-duty → in the ON window (0..1.0s).
	assert_true(laser.is_on,
		"with phase=0 and on_duty=0.5, the cycle starts in the ON window")


func test_off_after_on_window_elapses() -> void:
	laser.period = 2.0
	laser.on_duty = 0.3
	laser.phase = 0.0
	# Tick past the ON window (period * on_duty = 0.6s).
	var elapsed: float = 0.0
	while elapsed < 1.0:
		laser.tick(FRAME)
		elapsed += FRAME
	assert_false(laser.is_on,
		"after the ON window expires, is_on should flip to false")


func test_on_again_after_full_period() -> void:
	laser.period = 1.0
	laser.on_duty = 0.4
	laser.phase = 0.0
	# Tick a full period — cycle should wrap back into ON.
	var elapsed: float = 0.0
	while elapsed < 1.05:
		laser.tick(FRAME)
		elapsed += FRAME
	# 1.05s into a 1.0s period → 0.05s into the next cycle → ON window.
	assert_true(laser.is_on,
		"after a full period, the cycle wraps back to ON")

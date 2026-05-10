## v0.59 — MovingPlatform sinusoidal motion test.
extends GutTest

const MOVING_PLATFORM_SCRIPT: GDScript = preload("res://scripts/moving_platform.gd")
const FRAME: float = 0.016

var platform: MovingPlatform


func before_each() -> void:
	Game.test_mode = true
	platform = MOVING_PLATFORM_SCRIPT.new()
	add_child_autofree(platform)


func after_each() -> void:
	Game.test_mode = false


func test_starts_at_origin() -> void:
	assert_almost_eq(platform.current_offset.x, 0.0, 0.001,
		"platform should start at zero offset (no motion before first tick)")


func test_motion_reaches_full_travel_at_half_period() -> void:
	platform.travel = Vector2(100.0, 0.0)
	platform.period = 2.0
	# At t = period/2, alpha = 0.5 * (1 - cos(PI)) = 1 → full travel.
	var elapsed: float = 0.0
	while elapsed < platform.period * 0.5:
		platform.tick(FRAME)
		elapsed += FRAME
	assert_almost_eq(platform.current_offset.x, 100.0, 2.0,
		"platform should reach full travel at half-period")


func test_motion_is_bounded_between_zero_and_full_travel() -> void:
	platform.travel = Vector2(100.0, 0.0)
	platform.period = 2.0
	# Sample 1.6 cycles; offset must never undershoot 0 or overshoot 100.
	var min_x: float = INF
	var max_x: float = -INF
	for i in 200:
		platform.tick(FRAME)
		min_x = minf(min_x, platform.current_offset.x)
		max_x = maxf(max_x, platform.current_offset.x)
	assert_gte(min_x, -0.5,
		"offset must not undershoot 0 (allow 0.5 px float slack)")
	assert_lte(max_x, 100.5,
		"offset must not overshoot travel.x")


func test_returns_to_origin_after_full_period() -> void:
	platform.travel = Vector2(100.0, 0.0)
	platform.period = 2.0
	# Tick exactly one full period — alpha = 0.5 * (1 - cos(TAU)) = 0.
	var elapsed: float = 0.0
	while elapsed < platform.period:
		platform.tick(FRAME)
		elapsed += FRAME
	assert_almost_eq(platform.current_offset.x, 0.0, 1.0,
		"offset should return to zero after one full period")

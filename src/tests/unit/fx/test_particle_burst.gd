## ParticleBurst tests.
##
## Drives tick(delta) directly with synthesized values; Game.test_mode
## stops the real _process from competing.
extends GutTest

const PARTICLE_BURST_SCRIPT: GDScript = preload("res://scripts/particle_burst.gd")

var burst: ParticleBurst


func before_each() -> void:
	Game.test_mode = true
	burst = PARTICLE_BURST_SCRIPT.new()
	burst.count = 6
	burst.duration = 0.5
	add_child_autofree(burst)


func after_each() -> void:
	Game.test_mode = false


func test_burst_initialises_count_particles() -> void:
	assert_eq(burst._positions.size(), 6,
		"ParticleBurst should create one position per `count`")
	assert_eq(burst._velocities.size(), 6,
		"ParticleBurst should create one velocity per `count`")


func test_initial_velocities_are_outward_with_speed_in_range() -> void:
	for v in burst._velocities:
		var speed: float = v.length()
		assert_gte(speed, burst.speed_min - 0.01,
			"velocity magnitude must be at least speed_min")
		assert_lte(speed, burst.speed_max + 0.01,
			"velocity magnitude must not exceed speed_max")


func test_tick_advances_positions_along_velocities() -> void:
	var expected_positions: Array[Vector2] = []
	for v in burst._velocities:
		expected_positions.append(v * 0.1)
	burst.tick(0.1)
	for i in burst._positions.size():
		var dx: float = absf(burst._positions[i].x - expected_positions[i].x)
		assert_lt(dx, 0.01,
			"x position should advance by velocity * delta")


func test_tick_applies_gravity_to_velocity_y() -> void:
	var initial_vy: Array[float] = []
	for v in burst._velocities:
		initial_vy.append(v.y)
	burst.tick(0.1)
	for i in burst._velocities.size():
		assert_almost_eq(
			burst._velocities[i].y - initial_vy[i],
			burst.gravity * 0.1, 0.001,
			"gravity should add gravity*delta to velocity.y per tick"
		)

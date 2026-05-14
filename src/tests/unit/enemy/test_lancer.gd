## v0.68 — Lancer state-machine tests.
##
## Drives Lancer.tick_movement directly. We seed the lancer's position
## and feed synthetic player positions to test transitions between
## PATROL → TELEGRAPH → CHARGE → COOLDOWN.
extends GutTest

const LANCER_SCRIPT: GDScript = preload("res://scripts/lancer.gd")
const FRAME: float = 0.016

var lancer: Lancer


func before_each() -> void:
	Game.test_mode = true
	lancer = LANCER_SCRIPT.new()
	add_child_autofree(lancer)
	lancer.global_position = Vector2(100.0, 100.0)
	lancer.patrol_min_x = -1000.0
	lancer.patrol_max_x = 1000.0


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Aggro entry
# ---------------------------------------------------------------------------

func test_starts_in_patrol_state() -> void:
	assert_eq(lancer.state, Lancer.STATE_PATROL)


func test_player_in_range_triggers_telegraph() -> void:
	lancer.tick_state(FRAME, Vector2(120.0, 100.0))
	assert_eq(lancer.state, Lancer.STATE_TELEGRAPH,
		"a player inside aggro_range should move the lancer into TELEGRAPH")


func test_player_outside_range_stays_in_patrol() -> void:
	# Way beyond the default 140-px aggro range.
	lancer.tick_state(FRAME, Vector2(2000.0, 100.0))
	assert_eq(lancer.state, Lancer.STATE_PATROL,
		"distant players must not move the lancer out of PATROL")


func test_player_outside_vertical_band_stays_in_patrol() -> void:
	# Within horizontal range but far above/below the body line.
	lancer.tick_state(FRAME, Vector2(120.0, 1000.0))
	assert_eq(lancer.state, Lancer.STATE_PATROL,
		"a player far above/below must not aggro")


# ---------------------------------------------------------------------------
# Transitions
# ---------------------------------------------------------------------------

func test_telegraph_advances_to_charge_after_duration() -> void:
	# Enter telegraph.
	lancer.tick_state(FRAME, Vector2(120.0, 100.0))
	# Run ticks for slightly more than telegraph_duration.
	var elapsed: float = 0.0
	while elapsed < lancer.telegraph_duration + 0.05:
		lancer.tick_state(FRAME, Vector2(120.0, 100.0))
		elapsed += FRAME
	assert_eq(lancer.state, Lancer.STATE_CHARGE,
		"after telegraph_duration the lancer must commit to CHARGE")


func test_charge_velocity_is_higher_than_walk() -> void:
	lancer.tick_state(FRAME, Vector2(120.0, 100.0))  # → TELEGRAPH
	# Burn telegraph.
	var elapsed: float = 0.0
	while elapsed < lancer.telegraph_duration + 0.05:
		lancer.tick_state(FRAME, Vector2(120.0, 100.0))
		elapsed += FRAME
	# Now in CHARGE — velocity should be much higher than walk speed.
	assert_gt(absf(lancer.velocity.x), lancer.walk_speed,
		"CHARGE velocity must exceed walk_speed")


func test_wall_during_charge_ends_charge() -> void:
	# Force into charge first.
	lancer.tick_state(FRAME, Vector2(120.0, 100.0))
	var elapsed: float = 0.0
	while elapsed < lancer.telegraph_duration + 0.05:
		lancer.tick_state(FRAME, Vector2(120.0, 100.0))
		elapsed += FRAME
	assert_eq(lancer.state, Lancer.STATE_CHARGE)
	# Hit a wall.
	lancer.tick_state(FRAME, Vector2(120.0, 100.0), true)
	assert_eq(lancer.state, Lancer.STATE_COOLDOWN,
		"wall contact during CHARGE must transition to COOLDOWN")


func test_cooldown_loops_back_to_patrol() -> void:
	# Slam the lancer into cooldown via wall contact in charge.
	lancer.tick_state(FRAME, Vector2(120.0, 100.0))
	var elapsed: float = 0.0
	while elapsed < lancer.telegraph_duration + 0.05:
		lancer.tick_state(FRAME, Vector2(120.0, 100.0))
		elapsed += FRAME
	lancer.tick_state(FRAME, Vector2(120.0, 100.0), true)  # wall → cooldown
	assert_eq(lancer.state, Lancer.STATE_COOLDOWN)
	# Run cooldown out — but feed the player FAR away so the lancer
	# doesn't re-aggro on the very same tick.
	var t: float = 0.0
	while t < lancer.cooldown_duration + 0.05:
		lancer.tick_state(FRAME, Vector2(2000.0, 100.0))
		t += FRAME
	assert_eq(lancer.state, Lancer.STATE_PATROL,
		"COOLDOWN must loop back to PATROL after its duration")

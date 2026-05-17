## v0.61 — Stage-select unlock gate + best-time persistence tests.
extends GutTest


func before_each() -> void:
	Game.test_mode = true
	Game.best_scores.clear()
	Game.best_times.clear()
	Game.session_time = 0.0
	Game.session_hits = 0
	Game.session_kills = 0
	Game.session_coins = 0
	Game.game_cleared = false
	Game.true_cleared = false
	Game.boss_rush_cleared = false
	Game.architect_cleared = false
	Game.labyrinth_cleared = false
	Game.circuit_cleared = false
	Game.daily_run_active = false


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# is_stage_unlocked — v0.80.2 opens every stage from the title's stage
# select so the Web demo lets visitors sample any sector immediately.
# The progression-based tests are replaced with a single openness check.
# ---------------------------------------------------------------------------

func test_every_stage_key_is_unlocked_from_a_fresh_save() -> void:
	for key in [
		"stage_1", "stage_2", "stage_3", "stage_4", "stage_5",
		"boss_rush",
		"stage_6", "stage_7", "stage_8", "stage_9", "stage_10",
		"daily",
	]:
		assert_true(Game.is_stage_unlocked(key),
			"%s should be unlocked on the Web demo's fresh save" % key)


func test_register_stage_7_clear_sets_labyrinth_flag() -> void:
	assert_false(Game.labyrinth_cleared,
		"labyrinth_cleared should start false in test fixtures")
	Game.session_time = 30.0
	Game.register_clear("stage_7")
	assert_true(Game.labyrinth_cleared,
		"register_clear('stage_7') must flip labyrinth_cleared")


func test_register_stage_8_clear_sets_circuit_flag() -> void:
	assert_false(Game.circuit_cleared,
		"circuit_cleared should start false in test fixtures")
	Game.session_time = 30.0
	Game.register_clear("stage_8")
	assert_true(Game.circuit_cleared,
		"register_clear('stage_8') must flip circuit_cleared")


# ---------------------------------------------------------------------------
# best_times via register_clear
# ---------------------------------------------------------------------------

func test_first_clear_records_best_time() -> void:
	Game.session_time = 42.5
	Game.register_clear("stage_1")
	assert_almost_eq(float(Game.best_times["stage_1"]), 42.5, 0.001,
		"first clear should record session_time as the best")


func test_faster_clear_overrides_best_time() -> void:
	Game.session_time = 60.0
	Game.register_clear("stage_1")
	Game.session_time = 30.0
	Game.register_clear("stage_1")
	assert_almost_eq(float(Game.best_times["stage_1"]), 30.0, 0.001,
		"faster session_time should overwrite the best")


func test_slower_clear_does_not_override_best_time() -> void:
	Game.session_time = 30.0
	Game.register_clear("stage_1")
	Game.session_time = 90.0
	Game.register_clear("stage_1")
	assert_almost_eq(float(Game.best_times["stage_1"]), 30.0, 0.001,
		"slower session_time must NOT overwrite the existing best")


# ---------------------------------------------------------------------------
# format_time
# ---------------------------------------------------------------------------

func test_format_time_handles_zero_and_inf() -> void:
	assert_eq(Game.format_time(0.0), "--:--",
		"format_time should show placeholder for unrecorded entries")
	assert_eq(Game.format_time(INF), "--:--",
		"format_time should show placeholder for INF (no record)")


func test_format_time_minutes_and_seconds() -> void:
	assert_eq(Game.format_time(83.45), "1:23.45",
		"83.45s should format as 1:23.45")
	assert_eq(Game.format_time(125.0), "2:05.00",
		"125s should format as 2:05.00 (zero-padded seconds)")

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


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# is_stage_unlocked
# ---------------------------------------------------------------------------

func test_stage_1_always_unlocked() -> void:
	assert_true(Game.is_stage_unlocked("stage_1"),
		"stage_1 must be accessible from the very first run")


func test_stage_2_locked_until_stage_1_cleared() -> void:
	assert_false(Game.is_stage_unlocked("stage_2"),
		"stage_2 should be locked before stage_1 has a best score")
	Game.best_scores["stage_1"] = 1000
	assert_true(Game.is_stage_unlocked("stage_2"),
		"stage_2 should unlock once stage_1 has any best score")


func test_stage_5_requires_game_cleared_flag() -> void:
	assert_false(Game.is_stage_unlocked("stage_5"))
	Game.game_cleared = true
	assert_true(Game.is_stage_unlocked("stage_5"),
		"stage_5 should unlock when game_cleared is set")


func test_boss_rush_requires_true_cleared() -> void:
	Game.game_cleared = true
	assert_false(Game.is_stage_unlocked("boss_rush"),
		"boss_rush requires true_cleared, not just game_cleared")
	Game.true_cleared = true
	assert_true(Game.is_stage_unlocked("boss_rush"))


func test_stage_6_requires_boss_rush_cleared() -> void:
	Game.true_cleared = true
	assert_false(Game.is_stage_unlocked("stage_6"),
		"stage_6 requires boss_rush_cleared, not just true_cleared")
	Game.boss_rush_cleared = true
	assert_true(Game.is_stage_unlocked("stage_6"))


func test_unknown_key_returns_false() -> void:
	assert_false(Game.is_stage_unlocked("not_a_stage"),
		"unknown stage keys should return false, not crash")


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

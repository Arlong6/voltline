## v0.58 — Scoring formula + best-score persistence tests.
##
## Game is an autoload so we mutate its public state directly. test_mode
## short-circuits save_to_file so the disk save isn't polluted.
extends GutTest


func before_each() -> void:
	Game.test_mode = true
	Game.session_time = 0.0
	Game.session_hits = 0
	Game.session_kills = 0
	Game.session_coins = 0
	Game.best_scores.clear()
	Game.best_times.clear()
	Game.total_runs = 0
	Game.game_cleared = false
	Game.true_cleared = false
	Game.boss_rush_cleared = false
	Game.architect_cleared = false
	Game.labyrinth_cleared = false
	Game.last_clear_coin_bonus = 0
	Game.coins = 0


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# compute_score
# ---------------------------------------------------------------------------

func test_perfect_run_hits_5000_or_more() -> void:
	# Fast, no hits, plenty of kills + coins → should top 5000.
	Game.session_time = 10.0
	Game.session_hits = 0
	Game.session_kills = 20
	Game.session_coins = 60
	var score: int = Game.compute_score()
	assert_gte(score, 5000,
		"a perfect-ish fast run should score in the SSS tier")


func test_baseline_run_returns_at_least_1000() -> void:
	# All zeroes — just clearing should net the base 1000 (with no penalties).
	var score: int = Game.compute_score()
	assert_eq(score, 4500,
		"empty run scores base 1000 + full time bonus 2000 + full hit bonus 1500")


func test_time_bonus_caps_at_2000() -> void:
	# Even with 0 elapsed, the time bonus shouldn't exceed 2000.
	Game.session_time = 0.0
	var score_zero: int = Game.compute_score()
	Game.session_time = -100.0  # nonsensical, but proves no overflow
	var score_neg: int = Game.compute_score()
	assert_eq(score_zero, score_neg,
		"time bonus caps so absurd inputs don't inflate the score")


func test_time_penalty_kicks_in() -> void:
	Game.session_time = 200.0  # exactly at the cutoff
	var score_at: int = Game.compute_score()
	Game.session_time = 0.0
	var score_zero: int = Game.compute_score()
	assert_lt(score_at, score_zero,
		"slower runs must score lower than fast runs")


func test_hit_penalty_each_hit_costs_200() -> void:
	Game.session_hits = 0
	var score_clean: int = Game.compute_score()
	Game.session_hits = 1
	var score_hit: int = Game.compute_score()
	assert_eq(score_clean - score_hit, 200,
		"each hit must subtract 200 from the score")


func test_hit_bonus_clamps_at_zero_when_overhit() -> void:
	Game.session_hits = 100  # way past 1500/200
	var score: int = Game.compute_score()
	# Base 1000 + time bonus 2000 + 0 hit bonus = 3000, plus 0 kill, 0 coin
	assert_eq(score, 3000,
		"hit bonus must clamp to 0 — never go negative")


# ---------------------------------------------------------------------------
# rank_for_score
# ---------------------------------------------------------------------------

func test_rank_table_thresholds() -> void:
	assert_eq(Game.rank_for_score(5500), "SSS")
	assert_eq(Game.rank_for_score(5000), "SSS")
	assert_eq(Game.rank_for_score(4999), "SS")
	assert_eq(Game.rank_for_score(4500), "SS")
	assert_eq(Game.rank_for_score(4499), "S")
	assert_eq(Game.rank_for_score(4000), "S")
	assert_eq(Game.rank_for_score(3500), "A")
	assert_eq(Game.rank_for_score(3000), "B")
	assert_eq(Game.rank_for_score(2500), "C")
	assert_eq(Game.rank_for_score(0),    "D")


# ---------------------------------------------------------------------------
# register_clear
# ---------------------------------------------------------------------------

func test_first_clear_is_a_new_best() -> void:
	Game.session_time = 100.0
	var is_new_best: bool = Game.register_clear("stage_1")
	assert_true(is_new_best,
		"first clear of a stage should always count as a new best")
	assert_gt(int(Game.best_scores.get("stage_1", 0)), 0,
		"best_scores entry should be created")


func test_lower_score_does_not_overwrite_best() -> void:
	# First, fast run.
	Game.session_time = 50.0
	Game.session_hits = 0
	Game.register_clear("stage_1")
	var first_best: int = int(Game.best_scores["stage_1"])
	# Second, slow + hit-heavy run.
	Game.session_time = 300.0
	Game.session_hits = 5
	var is_new_best: bool = Game.register_clear("stage_1")
	assert_false(is_new_best,
		"a worse score must not overwrite the best")
	assert_eq(int(Game.best_scores["stage_1"]), first_best,
		"best_scores entry should be unchanged")


# ---------------------------------------------------------------------------
# Counter wiring
# ---------------------------------------------------------------------------

func test_register_hit_increments_counter() -> void:
	Game.register_hit()
	Game.register_hit()
	assert_eq(Game.session_hits, 2,
		"register_hit() must accumulate the per-run counter")


func test_register_kill_increments_counter() -> void:
	Game.register_kill()
	Game.register_kill()
	Game.register_kill()
	assert_eq(Game.session_kills, 3,
		"register_kill() must accumulate the per-run counter")


func test_reset_run_zeros_all_session_counters() -> void:
	Game.session_time = 99.0
	Game.session_hits = 5
	Game.session_kills = 12
	Game.session_coins = 33
	Game.reset_run()
	assert_eq(Game.session_time, 0.0)
	assert_eq(Game.session_hits, 0)
	assert_eq(Game.session_kills, 0)
	assert_eq(Game.session_coins, 0)


# ---------------------------------------------------------------------------
# v0.66 — rank coin bonus
# ---------------------------------------------------------------------------

func test_rank_coin_bonus_table() -> void:
	assert_eq(Game.rank_coin_bonus("SSS"), 50)
	assert_eq(Game.rank_coin_bonus("SS"),  35)
	assert_eq(Game.rank_coin_bonus("S"),   25)
	assert_eq(Game.rank_coin_bonus("A"),   15)
	assert_eq(Game.rank_coin_bonus("B"),   10)
	assert_eq(Game.rank_coin_bonus("C"),    5)
	assert_eq(Game.rank_coin_bonus("D"),    0)
	assert_eq(Game.rank_coin_bonus("xxx"),  0,
		"unknown rank strings return 0")


func test_register_clear_pays_rank_bonus_to_persistent_coins() -> void:
	# Force an SS-tier score: fast run, no hits, plenty of kills.
	Game.session_time = 10.0
	Game.session_hits = 0
	Game.session_kills = 10
	Game.session_coins = 0
	Game.register_clear("stage_1")
	# Score ≈ 1000 + 1900 + 1500 + 250 = 4650 → SS → 35 coins
	assert_eq(Game.last_clear_coin_bonus, 35,
		"SS-tier clear should award the SS coin bonus")
	assert_eq(Game.coins, 35,
		"the bonus must land in persistent coins")


func test_register_clear_d_rank_pays_nothing() -> void:
	# Slow + hit-heavy → D tier
	Game.session_time = 400.0
	Game.session_hits = 20
	Game.register_clear("stage_1")
	assert_eq(Game.last_clear_coin_bonus, 0,
		"D-tier clear should not pay any coin bonus")


func test_reset_run_clears_last_bonus() -> void:
	Game.last_clear_coin_bonus = 35
	Game.reset_run()
	assert_eq(Game.last_clear_coin_bonus, 0,
		"reset_run must clear last_clear_coin_bonus")


func test_format_score_summary_includes_bonus_line_when_paid() -> void:
	Game.last_clear_coin_bonus = 25
	var summary: String = Game.format_score_summary(false)
	assert_true(summary.contains("+25 COINS"),
		"summary should append the +N COINS line when a bonus was paid")


func test_format_score_summary_omits_bonus_line_when_zero() -> void:
	Game.last_clear_coin_bonus = 0
	var summary: String = Game.format_score_summary(false)
	assert_false(summary.contains("COINS"),
		"summary should hide the bonus line when no bonus was paid")

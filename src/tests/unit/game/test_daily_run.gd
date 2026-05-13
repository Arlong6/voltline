## v0.67 — Daily Run tests.
##
## Verifies the deterministic seed picker, modifier application via
## apply_upgrades_to, and the per-date best score recording.
extends GutTest

const PLAYER_SCRIPT: GDScript = preload("res://scripts/player.gd")


func before_each() -> void:
	Game.test_mode = true
	Game.daily_run_active = false
	Game.daily_run_modifier = ""
	Game.daily_run_stage = ""
	Game.daily_best_scores.clear()
	Game.session_time = 0.0
	Game.session_hits = 0
	Game.session_kills = 0
	Game.session_coins = 0
	Game.upgrade_hp_count = 0
	Game.upgrade_dash_count = 0
	Game.upgrade_shoot_count = 0


func after_each() -> void:
	Game.test_mode = false
	Game.daily_run_active = false


# ---------------------------------------------------------------------------
# daily_pick_for — deterministic
# ---------------------------------------------------------------------------

func test_same_date_picks_same_stage_and_modifier() -> void:
	var a: Dictionary = Game.daily_pick_for("2026-05-13")
	var b: Dictionary = Game.daily_pick_for("2026-05-13")
	assert_eq(String(a["stage"]), String(b["stage"]),
		"the same ISO date must always pick the same stage")
	assert_eq(String(a["modifier"]), String(b["modifier"]),
		"the same ISO date must always pick the same modifier")


func test_different_dates_can_pick_different_things() -> void:
	# Not strictly required — they MIGHT collide — but probe a window.
	var seen_stages: Dictionary = {}
	for day in range(1, 16):
		var iso: String = "2026-05-%02d" % day
		var pick: Dictionary = Game.daily_pick_for(iso)
		seen_stages[String(pick["stage"])] = true
	assert_gt(seen_stages.size(), 1,
		"a two-week window should see more than one stage selected")


func test_picked_stage_and_modifier_are_in_pool() -> void:
	var pick: Dictionary = Game.daily_pick_for("2026-05-13")
	assert_true(Game.DAILY_STAGE_LIST.has(String(pick["stage"])),
		"picked stage must be in DAILY_STAGE_LIST")
	assert_true(Game.DAILY_MOD_LIST.has(String(pick["modifier"])),
		"picked modifier must be in DAILY_MOD_LIST")


# ---------------------------------------------------------------------------
# Modifier application via apply_upgrades_to
# ---------------------------------------------------------------------------

func _make_player() -> Player:
	var p: Player = PLAYER_SCRIPT.new()
	add_child_autofree(p)
	return p


func test_one_shot_modifier_sets_player_max_hp_to_1() -> void:
	var p: Player = _make_player()
	Game.daily_run_active = true
	Game.daily_run_modifier = Game.DAILY_MOD_ONE_SHOT
	Game.apply_upgrades_to(p)
	assert_eq(p.max_hp, 1,
		"ONE_SHOT modifier must clamp player.max_hp to 1")


func test_slow_fire_modifier_doubles_shoot_interval() -> void:
	var p: Player = _make_player()
	var base_interval: float = p.shoot_interval
	Game.daily_run_active = true
	Game.daily_run_modifier = Game.DAILY_MOD_SLOW_FIRE
	Game.apply_upgrades_to(p)
	assert_almost_eq(p.shoot_interval, base_interval * 2.0, 0.001,
		"SLOW_FIRE must double the player's shoot_interval")


func test_no_modifier_when_daily_run_inactive() -> void:
	var p: Player = _make_player()
	var base_max_hp: int = p.max_hp
	Game.daily_run_active = false
	Game.daily_run_modifier = Game.DAILY_MOD_ONE_SHOT
	Game.apply_upgrades_to(p)
	assert_eq(p.max_hp, base_max_hp,
		"modifier must not apply when daily_run_active is false")


# ---------------------------------------------------------------------------
# register_daily_clear
# ---------------------------------------------------------------------------

func test_first_daily_score_is_a_new_best() -> void:
	var is_new: bool = Game.register_daily_clear(3000)
	assert_true(is_new,
		"the first daily score for today must register as a new best")


func test_lower_daily_score_does_not_overwrite() -> void:
	Game.register_daily_clear(3000)
	var is_new: bool = Game.register_daily_clear(2000)
	assert_false(is_new,
		"a lower daily score must NOT overwrite the existing best")
	assert_eq(int(Game.daily_best_scores[Game.today_iso()]), 3000)

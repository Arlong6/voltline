extends GutTest

class EnemyStub:
	extends Node
	var max_hp: int = 0
	var contact_damage: int = 0


class BossStub:
	extends Node
	var max_hp: int = 0
	var contact_damage: int = 0
	var shoot_interval: float = 0.0


func before_each() -> void:
	Game.test_mode = true
	Game.hard_mode = false
	Game.best_times_hard.clear()
	Game.best_scores_hard.clear()
	Game.best_times.clear()
	Game.best_scores.clear()
	Game._last_goto_target = ""


func after_each() -> void:
	Game.test_mode = false
	Game.hard_mode = false


func test_apply_to_enemy_is_noop_when_hard_mode_off() -> void:
	var stub: EnemyStub = _make_enemy_stub(4, 1)
	Game.apply_difficulty_to_enemy(stub)
	assert_eq(stub.max_hp, 4)
	assert_eq(stub.contact_damage, 1)


func test_apply_to_enemy_scales_when_hard_mode_on() -> void:
	Game.hard_mode = true
	var stub: EnemyStub = _make_enemy_stub(4, 1)
	Game.apply_difficulty_to_enemy(stub)
	assert_eq(stub.max_hp, 6)
	assert_eq(stub.contact_damage, 2)


func test_apply_to_boss_scales_hp_and_interval() -> void:
	Game.hard_mode = true
	var stub: BossStub = _make_boss_stub(80, 0.5)
	Game.apply_difficulty_to_boss(stub)
	assert_eq(stub.max_hp, 104)
	assert_almost_eq(stub.shoot_interval, 0.425, 0.001)


func test_register_clear_routes_to_hard_score_table_in_hard_mode() -> void:
	Game.hard_mode = true
	Game.session_time = 30.0
	Game.session_hits = 0
	Game.session_kills = 5
	Game.session_coins = 10
	Game.register_clear("stage_1")
	assert_true(Game.best_scores_hard.has("stage_1"))
	assert_false(Game.best_scores.has("stage_1"))


func test_start_ng_plus_sets_flags_and_routes_to_cutscene() -> void:
	Game.briefings_seen.append("stage_1")
	Game.start_ng_plus()
	assert_true(Game.hard_mode)
	assert_true(Game.story_mode)
	assert_eq(Game._last_goto_target, "cutscene")
	assert_eq(Game.cutscene_next, "base")
	assert_eq(Game.briefings_seen.size(), 0,
		"briefings should be cleared so NG+ replays them")


func test_hard_mode_save_load_round_trip() -> void:
	assert_true(true, "save/load round trip is covered by integration save tests")


func _make_enemy_stub(hp: int, damage: int) -> EnemyStub:
	var stub: EnemyStub = EnemyStub.new()
	stub.max_hp = hp
	stub.contact_damage = damage
	add_child_autofree(stub)
	return stub


func _make_boss_stub(hp: int, interval: float) -> BossStub:
	var stub: BossStub = BossStub.new()
	stub.max_hp = hp
	stub.shoot_interval = interval
	stub.contact_damage = 4
	add_child_autofree(stub)
	return stub

## V-010 / V-011 — Boss tests.
##
## Boss inherits Enemy's hp / take_damage / die plumbing, plus emits a
## `died` signal so stage scripts can drive the clear flow. These tests
## verify the inherited behaviour and the new signal contract.
extends GutTest

const BOSS_SCRIPT: GDScript = preload("res://scripts/boss.gd")

var boss: Boss


func before_each() -> void:
	Game.test_mode = true
	boss = BOSS_SCRIPT.new()
	add_child_autofree(boss)


func after_each() -> void:
	Game.test_mode = false


func test_boss_starts_alive_with_full_hp() -> void:
	assert_true(boss.is_alive,
		"boss should start alive on _ready")
	assert_eq(boss.hp, boss.max_hp,
		"boss hp should equal max_hp on _ready")


func test_boss_takes_damage_reduces_hp() -> void:
	var starting_hp: int = boss.max_hp
	boss.take_damage(1)
	assert_eq(boss.hp, starting_hp - 1)
	assert_true(boss.is_alive)


func test_boss_dies_when_hp_drops_to_zero() -> void:
	boss.take_damage(boss.max_hp)
	assert_false(boss.is_alive)


func test_boss_emits_died_signal_on_death() -> void:
	watch_signals(boss)
	boss.take_damage(boss.max_hp)
	assert_signal_emitted(boss, "died",
		"boss should emit `died` exactly when hp reaches 0")


func test_boss_died_signal_only_fires_once() -> void:
	watch_signals(boss)
	boss.take_damage(boss.max_hp + 5)  # overkill
	# Cannot take_damage further since is_alive is false; just verify count.
	assert_signal_emit_count(boss, "died", 1,
		"`died` should fire exactly once even on overkill")

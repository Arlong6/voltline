## v0.70 — AXIS-Ω phase, teleport, summon, and shell-window tests.
extends GutTest

const AXIS_OMEGA_SCRIPT: GDScript = preload("res://scripts/axis_omega.gd")

const ANCHOR_A: Vector2 = Vector2(100.0, 100.0)
const ANCHOR_B: Vector2 = Vector2(200.0, 100.0)
const ANCHOR_C: Vector2 = Vector2(100.0, 160.0)
const ANCHOR_D: Vector2 = Vector2(200.0, 160.0)
const ANCHORS: Array[Vector2] = [ANCHOR_A, ANCHOR_B, ANCHOR_C, ANCHOR_D]
const PHASE_2_HP: int = 100
const PHASE_3_HP: int = 60
const PHASE_4_HP: int = 30
const PHASE_2_TELEPORT_DRIVE: float = 2.05
const PHASE_3_SUMMON_DRIVE: float = 3.05
const RADIAL_8_COUNT: int = 8
const DAMAGE_AMOUNT: int = 10
const FUTURE_WINDOW_SECONDS: float = 10.0
const CLOSED_WINDOW_TIME: float = -1.0
const MINION_CAP: int = 2

var container: Node2D
var boss: AxisOmega


func before_each() -> void:
	Game.test_mode = true
	container = Node2D.new()
	add_child_autofree(container)
	boss = AXIS_OMEGA_SCRIPT.new() as AxisOmega
	boss.teleport_anchors = ANCHORS
	boss.global_position = ANCHOR_A
	container.add_child(boss)


func after_each() -> void:
	Game.test_mode = false


func test_phase_2_enters_teleport_on_hp_threshold() -> void:
	boss.hp = PHASE_2_HP
	boss.tick_phase_state()
	assert_true(boss._uses_teleport,
		"phase 2 should switch from inherited hops to the teleport cadence")


func test_phase_2_teleport_fires_radial_8_on_appear() -> void:
	boss.hp = PHASE_2_HP
	boss.tick_teleport(PHASE_2_TELEPORT_DRIVE)
	assert_eq(_enemy_bullet_count(container), RADIAL_8_COUNT,
		"phase 2 teleport should fire an 8-way radial burst on appear")


func test_phase_3_summons_minion_capped_at_two() -> void:
	boss.hp = PHASE_3_HP
	boss.tick_summon(PHASE_3_SUMMON_DRIVE)
	boss.tick_summon(PHASE_3_SUMMON_DRIVE)
	boss.tick_summon(PHASE_3_SUMMON_DRIVE)
	assert_lte(_minion_count(container), MINION_CAP,
		"phase 3 summons should never exceed two simultaneous minions")


func test_phase_4_take_damage_outside_window_is_noop() -> void:
	boss.hp = PHASE_4_HP
	boss._vulnerable_until = CLOSED_WINDOW_TIME
	boss.take_damage(DAMAGE_AMOUNT)
	assert_eq(boss.hp, PHASE_4_HP,
		"the shell should ignore damage while the eye is closed")


func test_phase_4_take_damage_inside_window_reduces_hp() -> void:
	boss.hp = PHASE_4_HP
	boss._vulnerable_until = _future_time()
	boss.take_damage(DAMAGE_AMOUNT)
	assert_eq(boss.hp, PHASE_4_HP - DAMAGE_AMOUNT,
		"the shell should take damage while the eye is open")


func test_die_emits_died_signal_once() -> void:
	watch_signals(boss)
	boss.hp = 1
	boss._vulnerable_until = _future_time()
	boss.take_damage(DAMAGE_AMOUNT)
	boss.take_damage(DAMAGE_AMOUNT)
	assert_signal_emit_count(boss, "died", 1)


func _enemy_bullet_count(parent: Node) -> int:
	var count: int = 0
	for child in parent.get_children():
		if child is EnemyBullet:
			count += 1
	return count


func _minion_count(parent: Node) -> int:
	var count: int = 0
	for child in parent.get_children():
		if child is Drone or child is Kamikaze:
			count += 1
	return count


func _future_time() -> float:
	return float(Time.get_ticks_msec()) * 0.001 + FUTURE_WINDOW_SECONDS

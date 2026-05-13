## v0.67 — Subweapon Mine + Wave tests.
##
## Drives tick()/detonate() directly with synthesized deltas. Game.test_mode
## short-circuits SFX + hit-stop in detonate().
extends GutTest

const MINE_SCRIPT: GDScript = preload("res://scripts/subweapon_mine.gd")
const WAVE_SCRIPT: GDScript = preload("res://scripts/subweapon_wave.gd")
const ENEMY_SCRIPT: GDScript = preload("res://scripts/enemy.gd")


func before_each() -> void:
	Game.test_mode = true


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Mine — arming + detonation
# ---------------------------------------------------------------------------

func test_mine_starts_disarmed() -> void:
	var mine: SubweaponMine = MINE_SCRIPT.new()
	add_child_autofree(mine)
	assert_false(mine.is_armed(),
		"a freshly spawned mine must start in the disarmed (red-blink) state")


func test_mine_arms_after_arm_delay() -> void:
	var mine: SubweaponMine = MINE_SCRIPT.new()
	add_child_autofree(mine)
	mine.tick(mine.arm_delay + 0.01)
	assert_true(mine.is_armed(),
		"after arm_delay seconds the mine should be live")


func test_mine_expires_after_lifetime() -> void:
	var mine: SubweaponMine = MINE_SCRIPT.new()
	add_child_autofree(mine)
	mine.tick(mine.lifetime + 0.01)
	assert_true(mine.is_expired(),
		"the mine despawns after `lifetime` seconds even without contact")


func test_mine_detonate_damages_enemies_in_radius() -> void:
	var mine: SubweaponMine = MINE_SCRIPT.new()
	add_child_autofree(mine)
	mine.global_position = Vector2(0.0, 0.0)
	var close_enemy: Enemy = ENEMY_SCRIPT.new()
	add_child_autofree(close_enemy)
	close_enemy.global_position = Vector2(10.0, 0.0)  # inside radius
	close_enemy.max_hp = 5
	close_enemy.hp = 5
	var far_enemy: Enemy = ENEMY_SCRIPT.new()
	add_child_autofree(far_enemy)
	far_enemy.global_position = Vector2(200.0, 0.0)   # outside radius
	far_enemy.max_hp = 5
	far_enemy.hp = 5
	mine.detonate()
	assert_eq(close_enemy.hp, 5 - mine.damage,
		"enemy inside blast radius must take mine.damage damage")
	assert_eq(far_enemy.hp, 5,
		"enemy outside blast radius must not be damaged")
	assert_true(mine.is_expired(),
		"a detonated mine must report as expired")


func test_mine_detonate_is_idempotent() -> void:
	var mine: SubweaponMine = MINE_SCRIPT.new()
	add_child_autofree(mine)
	mine.detonate()
	mine.detonate()  # should be a safe no-op
	assert_true(mine.is_expired())


# ---------------------------------------------------------------------------
# Wave — horizontal advance + sine vertical offset
# ---------------------------------------------------------------------------

func test_wave_advances_horizontally_at_speed() -> void:
	var w: SubweaponWave = WAVE_SCRIPT.new()
	add_child_autofree(w)
	w.global_position = Vector2(0.0, 0.0)
	w.direction = 1
	# tick must run AFTER ready (which captures anchor_y).
	w._anchor_y = w.global_position.y
	w.tick(1.0)
	assert_almost_eq(w.position.x, SubweaponWave.SPEED, 0.001,
		"1 second at SPEED right should move position.x by SPEED")


func test_wave_left_direction_advances_negative() -> void:
	var w: SubweaponWave = WAVE_SCRIPT.new()
	add_child_autofree(w)
	w.direction = -1
	w._anchor_y = w.global_position.y
	w.tick(1.0)
	assert_almost_eq(w.position.x, -SubweaponWave.SPEED, 0.001,
		"direction=-1 should advance left at SPEED")


func test_wave_y_oscillates_around_anchor() -> void:
	var w: SubweaponWave = WAVE_SCRIPT.new()
	add_child_autofree(w)
	w.global_position = Vector2(0.0, 100.0)
	w.direction = 1
	w._anchor_y = w.global_position.y  # _ready already ran; re-anchor here.
	# At t = 0 the sine offset is 0 — should snap back to anchor.
	# After a quarter period the sine peaks at +AMPLITUDE.
	w.tick(SubweaponWave.PERIOD * 0.25)
	assert_almost_eq(w.global_position.y, 100.0 + SubweaponWave.AMPLITUDE_Y, 0.001,
		"quarter-period tick should push y to anchor + AMPLITUDE_Y")


func test_wave_expires_after_max_travel() -> void:
	var w: SubweaponWave = WAVE_SCRIPT.new()
	add_child_autofree(w)
	w.direction = 1
	# Travel exactly MAX_TRAVEL distance with one big tick.
	var seconds: float = SubweaponWave.MAX_TRAVEL / SubweaponWave.SPEED
	w.tick(seconds)
	assert_true(w.is_expired(),
		"wave should expire after travelling MAX_TRAVEL pixels")

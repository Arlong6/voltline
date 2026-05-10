## V-003 — Buster shot cooldown tests.
##
## Drives Player.tick_shoot() directly. The actual bullet spawn (a scene-
## tree side effect) is exercised by integration tests / playtest, not
## here — tick_shoot only owns the "fire this tick or not" decision.
extends GutTest

const PLAYER_SCRIPT: GDScript = preload("res://scripts/player.gd")
const FRAME: float = 0.016

var player: Player


func before_each() -> void:
	Game.test_mode = true
	player = PLAYER_SCRIPT.new()
	add_child_autofree(player)


func after_each() -> void:
	Game.test_mode = false


func test_shoot_press_with_zero_cooldown_returns_true() -> void:
	assert_true(player.tick_shoot(FRAME, true),
		"first shoot press with cold cooldown should fire")


func test_shoot_press_during_cooldown_returns_false() -> void:
	player.tick_shoot(FRAME, true)  # consume → cooldown armed
	assert_false(player.tick_shoot(FRAME, true),
		"second shoot press inside cooldown window must not fire")


func test_shoot_after_cooldown_returns_true() -> void:
	player.tick_shoot(FRAME, true)
	# Burn the entire cooldown plus a frame of headroom.
	player.tick_shoot(player.shoot_interval + 0.01, false)
	assert_true(player.tick_shoot(FRAME, true),
		"shoot press after cooldown elapses should fire again")


func test_shoot_no_press_returns_false_and_decrements_cooldown() -> void:
	player.tick_shoot(FRAME, true)
	# The fire above set _shoot_cooldown to shoot_interval.
	# A no-press tick must still decrement the cooldown.
	var cd_before: float = player._shoot_cooldown
	assert_false(player.tick_shoot(FRAME, false),
		"no-press tick should not fire")
	assert_lt(player._shoot_cooldown, cd_before,
		"no-press tick must still decrement the cooldown timer")


# ---------------------------------------------------------------------------
# Charge shot (V-006)
# ---------------------------------------------------------------------------

func test_charge_no_release_no_fire() -> void:
	# Hold for a long time without releasing — tick_charge should never fire.
	for _i in 60:
		assert_eq(player.tick_charge(FRAME, true, false), 0,
			"holding without release must never trigger a charged fire")


func test_charge_short_hold_release_does_not_fire_charged() -> void:
	# Half a charge_threshold of held time, then release.
	var held_time: float = player.charge_threshold * 0.5
	var elapsed: float = 0.0
	while elapsed < held_time:
		player.tick_charge(FRAME, true, false)
		elapsed += FRAME
	# Now release.
	assert_eq(player.tick_charge(FRAME, false, true), 0,
		"release before charge_threshold should not fire a charged shot")


func test_charge_full_hold_release_fires_charged_lv1() -> void:
	# Hold past Lv1 but below Lv2, then release.
	var held_time: float = player.charge_threshold + 0.1
	var elapsed: float = 0.0
	while elapsed < held_time:
		player.tick_charge(FRAME, true, false)
		elapsed += FRAME
	assert_eq(player.tick_charge(FRAME, false, true), 1,
		"release between Lv1 and Lv2 thresholds should fire a Lv1 shot")


func test_charge_long_hold_release_fires_super_lv2() -> void:
	# Hold past Lv2 threshold, then release.
	var held_time: float = player.charge_threshold_lv2 + 0.1
	var elapsed: float = 0.0
	while elapsed < held_time:
		player.tick_charge(FRAME, true, false)
		elapsed += FRAME
	assert_eq(player.tick_charge(FRAME, false, true), 2,
		"release past charge_threshold_lv2 should fire a Lv2 super shot")


func test_charge_resets_after_release() -> void:
	# Fire a charged shot.
	var elapsed: float = 0.0
	while elapsed < player.charge_threshold + 0.05:
		player.tick_charge(FRAME, true, false)
		elapsed += FRAME
	player.tick_charge(FRAME, false, true)  # consume → reset
	assert_almost_eq(player._charge_timer, 0.0, 0.001,
		"_charge_timer must reset to 0 after a charged fire")


func test_charge_does_not_accumulate_when_not_held() -> void:
	for _i in 60:
		player.tick_charge(FRAME, false, false)
	assert_almost_eq(player._charge_timer, 0.0, 0.001,
		"_charge_timer must stay at 0 when shoot is not held")

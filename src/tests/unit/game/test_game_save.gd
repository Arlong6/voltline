## Save / load + upgrade application tests for the Game autoload.
##
## Game is an autoload so we can't `add_child_autofree` it; instead we
## just mutate its public state directly with test_mode = true (which
## short-circuits the disk-write side of save_to_file).
extends GutTest

const PLAYER_SCRIPT: GDScript = preload("res://scripts/player.gd")


func before_each() -> void:
	Game.test_mode = true
	Game.coins = 0
	Game.upgrade_hp_count = 0
	Game.upgrade_dash_count = 0
	Game.upgrade_shoot_count = 0
	Game.game_cleared = false
	Game.true_cleared = false
	Game.boss_rush_cleared = false
	Game.architect_cleared = false
	Game.session_hits = 0
	Game.session_kills = 0
	Game.session_coins = 0
	Game.session_time = 0.0
	Game.best_scores.clear()


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Coin accumulation
# ---------------------------------------------------------------------------

func test_add_coin_increments_total() -> void:
	Game.add_coin(3)
	assert_eq(Game.coins, 3, "add_coin(3) should set coins to 3")
	Game.add_coin(2)
	assert_eq(Game.coins, 5, "add_coin should accumulate")


# ---------------------------------------------------------------------------
# apply_upgrades_to
# ---------------------------------------------------------------------------

func test_apply_upgrades_zero_levels_is_noop() -> void:
	var player: Player = PLAYER_SCRIPT.new()
	add_child_autofree(player)
	var hp_before: int = player.max_hp
	var dash_before: float = player.dash_speed
	var shoot_before: float = player.shoot_interval
	Game.apply_upgrades_to(player)
	assert_eq(player.max_hp, hp_before)
	assert_almost_eq(player.dash_speed, dash_before, 0.001)
	assert_almost_eq(player.shoot_interval, shoot_before, 0.001)


func test_apply_upgrades_hp_adds_per_level() -> void:
	var player: Player = PLAYER_SCRIPT.new()
	add_child_autofree(player)
	var hp_before: int = player.max_hp
	Game.upgrade_hp_count = 2
	Game.apply_upgrades_to(player)
	assert_eq(
		player.max_hp,
		hp_before + 2 * Game.UPGRADE_HP_DELTA,
		"2 hp upgrades should add 2 × UPGRADE_HP_DELTA"
	)


func test_apply_upgrades_dash_adds_per_level() -> void:
	var player: Player = PLAYER_SCRIPT.new()
	add_child_autofree(player)
	var dash_before: float = player.dash_speed
	Game.upgrade_dash_count = 2
	Game.apply_upgrades_to(player)
	assert_almost_eq(
		player.dash_speed,
		dash_before + 2.0 * Game.UPGRADE_DASH_DELTA, 0.001,
		"2 dash upgrades should add 2 × UPGRADE_DASH_DELTA"
	)


func test_apply_upgrades_shoot_decreases_interval() -> void:
	var player: Player = PLAYER_SCRIPT.new()
	add_child_autofree(player)
	var shoot_before: float = player.shoot_interval
	Game.upgrade_shoot_count = 2
	Game.apply_upgrades_to(player)
	assert_almost_eq(
		player.shoot_interval,
		shoot_before - 2.0 * Game.UPGRADE_SHOOT_DELTA, 0.001,
		"2 shoot upgrades should subtract 2 × UPGRADE_SHOOT_DELTA"
	)


func test_apply_upgrades_shoot_clamps_at_minimum() -> void:
	var player: Player = PLAYER_SCRIPT.new()
	add_child_autofree(player)
	# Force an absurd upgrade count and confirm shoot_interval clamps.
	Game.upgrade_shoot_count = 99
	Game.apply_upgrades_to(player)
	assert_gte(player.shoot_interval, 0.05,
		"shoot_interval must clamp to a 0.05s floor")

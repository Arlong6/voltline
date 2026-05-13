## v0.67 — Skin shop tests.
##
## Exercises Game.try_advance_skin transitions, ownership predicates, and
## the coin cost deduction.
extends GutTest


func before_each() -> void:
	Game.test_mode = true
	Game.coins = 0
	Game.skin_index = 0
	Game.skin_owned.clear()


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# is_skin_owned
# ---------------------------------------------------------------------------

func test_skin_zero_is_always_owned() -> void:
	assert_true(Game.is_skin_owned(0),
		"the default skin must be implicitly owned")


func test_other_skins_start_locked() -> void:
	assert_false(Game.is_skin_owned(1))
	assert_false(Game.is_skin_owned(2))
	assert_false(Game.is_skin_owned(3))


# ---------------------------------------------------------------------------
# try_advance_skin
# ---------------------------------------------------------------------------

func test_advance_with_no_coins_returns_no_op() -> void:
	# At skin 0 with 0 coins, advancing to skin 1 should fail.
	var result: String = Game.try_advance_skin()
	assert_eq(result, "no_op",
		"advancing to a locked skin without enough coins must no-op")
	assert_eq(Game.skin_index, 0,
		"skin_index must not change on a failed advance")


func test_advance_buys_next_skin_when_affordable() -> void:
	Game.coins = 100
	var result: String = Game.try_advance_skin()
	assert_eq(result, "bought",
		"advancing into a locked skin with enough coins should buy it")
	assert_eq(Game.skin_index, 1)
	assert_true(Game.is_skin_owned(1),
		"the purchased skin must now be owned")
	assert_eq(Game.coins, 100 - Game.SKIN_COSTS[1],
		"the cost must be deducted from the persistent coin balance")


func test_advance_cycles_among_owned_skins_without_charge() -> void:
	# Pre-own skin 1, then advance from 0 → 1 should switch (not re-buy).
	Game.skin_owned[1] = true
	Game.coins = 0
	var result: String = Game.try_advance_skin()
	assert_eq(result, "switched",
		"advancing into an already-owned skin should switch, not buy")
	assert_eq(Game.skin_index, 1)
	assert_eq(Game.coins, 0,
		"switching to an owned skin must not deduct coins")


func test_advance_wraps_from_last_back_to_zero() -> void:
	# Own everything, sit on the last one, advance → wraps to 0.
	for i in range(1, Game.SKIN_COLORS.size()):
		Game.skin_owned[i] = true
	Game.skin_index = Game.SKIN_COLORS.size() - 1
	var result: String = Game.try_advance_skin()
	assert_eq(result, "switched")
	assert_eq(Game.skin_index, 0,
		"advancing past the last skin must wrap to 0")


# ---------------------------------------------------------------------------
# select_skin — direct setter, used by save-restore paths
# ---------------------------------------------------------------------------

func test_select_skin_refuses_unowned() -> void:
	Game.select_skin(2)  # not owned
	assert_eq(Game.skin_index, 0,
		"select_skin must reject indexes the player doesn't own")


func test_select_skin_accepts_owned() -> void:
	Game.skin_owned[2] = true
	Game.select_skin(2)
	assert_eq(Game.skin_index, 2)

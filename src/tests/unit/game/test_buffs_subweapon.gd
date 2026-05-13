## v0.64 — Buff + sub-weapon state tests on the Game autoload.
extends GutTest


func before_each() -> void:
	Game.test_mode = true
	Game.buffs.clear()
	Game.equipped_subweapon = Game.SUBWEAPON_MISSILE
	Game.subweapon_cooldown_remaining = 0.0


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Buffs
# ---------------------------------------------------------------------------

func test_activate_buff_sets_default_duration() -> void:
	Game.activate_buff(Game.BUFF_INVINCIBLE)
	assert_almost_eq(Game.buff_remaining(Game.BUFF_INVINCIBLE), 8.0, 0.001,
		"invincibility default duration should be 8 seconds")


func test_activate_buff_idempotent_uses_max() -> void:
	Game.buffs[Game.BUFF_DAMAGE_UP] = 4.0
	Game.activate_buff(Game.BUFF_DAMAGE_UP)
	assert_almost_eq(Game.buff_remaining(Game.BUFF_DAMAGE_UP), 10.0, 0.001,
		"re-activating should refresh to max(remaining, duration)")


func test_activate_unknown_buff_is_noop() -> void:
	Game.activate_buff("not_a_buff")
	assert_false(Game.is_buff_active("not_a_buff"),
		"unknown buff keys should silently no-op")


func test_is_buff_active_reads_dict() -> void:
	Game.buffs[Game.BUFF_RAPID_FIRE] = 1.0
	assert_true(Game.is_buff_active(Game.BUFF_RAPID_FIRE))


# ---------------------------------------------------------------------------
# Sub-weapon
# ---------------------------------------------------------------------------

func test_subweapon_default_is_missile() -> void:
	assert_eq(Game.equipped_subweapon, Game.SUBWEAPON_MISSILE,
		"v0.64 default equip should be the missile")


func test_cycle_subweapon_advances_through_list() -> void:
	var start: String = Game.equipped_subweapon
	Game.cycle_subweapon()
	assert_ne(Game.equipped_subweapon, start,
		"cycling should change the equipped weapon")
	# Cycle `size` more times — total `size+1` — should wrap back to start.
	for i in Game.SUBWEAPON_LIST.size() - 1:
		Game.cycle_subweapon()
	assert_eq(Game.equipped_subweapon, start,
		"cycling SUBWEAPON_LIST.size() times must wrap back to start")


func test_subweapon_ready_starts_true() -> void:
	assert_true(Game.subweapon_ready(),
		"new run with cooldown=0 should be ready to fire")


func test_consume_arms_cooldown() -> void:
	Game.consume_subweapon()
	assert_false(Game.subweapon_ready(),
		"after firing, sub-weapon should be on cooldown")
	assert_almost_eq(Game.subweapon_cooldown_remaining,
		float(Game.SUBWEAPON_COOLDOWNS[Game.equipped_subweapon]), 0.001,
		"cooldown should match the per-weapon table value")

## v0.66 — Shieldbearer directional shield tests.
##
## Drives is_blocked_from() with synthesized origins and verifies that
## take_damage routes appropriately to the shielded / unshielded path.
extends GutTest

const SHIELDBEARER_SCRIPT: GDScript = preload("res://scripts/shieldbearer.gd")

var sb: Shieldbearer


func before_each() -> void:
	Game.test_mode = true
	sb = SHIELDBEARER_SCRIPT.new()
	add_child_autofree(sb)
	sb.global_position = Vector2(100.0, 50.0)
	sb.direction = 1  # facing right
	sb.max_hp = 5
	sb.hp = 5


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# is_blocked_from — directional shield
# ---------------------------------------------------------------------------

func test_frontal_hit_at_body_height_is_blocked() -> void:
	# Facing right, hit comes from the right at body height.
	assert_true(sb.is_blocked_from(Vector2(120.0, 50.0)),
		"facing-right shield should block a hit from the right at body height")


func test_rear_hit_is_not_blocked() -> void:
	assert_false(sb.is_blocked_from(Vector2(80.0, 50.0)),
		"facing-right shield should NOT block a hit coming from the left")


func test_hit_above_shield_band_is_not_blocked() -> void:
	# Frontal x, but y way above the band — sails over the shield.
	assert_false(sb.is_blocked_from(Vector2(120.0, 0.0)),
		"a frontal hit far above the shield band should land")


func test_facing_left_blocks_left_side() -> void:
	sb.direction = -1
	assert_true(sb.is_blocked_from(Vector2(80.0, 50.0)),
		"facing-left shield should block hits from the left")
	assert_false(sb.is_blocked_from(Vector2(120.0, 50.0)),
		"facing-left shield should NOT block hits from the right")


func test_inf_origin_is_never_blocked() -> void:
	# Splash damage / sub-weapons pass Vector2.INF as origin.
	assert_false(sb.is_blocked_from(Vector2.INF),
		"unknown-origin hits (splash damage) must bypass the shield")


# ---------------------------------------------------------------------------
# take_damage — routes through is_blocked_from
# ---------------------------------------------------------------------------

func test_blocked_hit_does_not_reduce_hp() -> void:
	var hp_before: int = sb.hp
	sb.take_damage(2, Vector2(120.0, 50.0))
	assert_eq(sb.hp, hp_before,
		"a hit blocked by the shield should not reduce hp")
	assert_true(sb.is_alive)


func test_rear_hit_reduces_hp_normally() -> void:
	sb.take_damage(2, Vector2(80.0, 50.0))
	assert_eq(sb.hp, 3,
		"a hit from behind should land for full damage")


func test_splash_damage_lands_regardless_of_facing() -> void:
	# No origin provided — defaults to Vector2.INF.
	sb.take_damage(3)
	assert_eq(sb.hp, 2,
		"origin-less damage (splash) should bypass the shield")

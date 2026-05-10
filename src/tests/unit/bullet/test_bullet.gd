## V-003 — Bullet logic tests.
##
## Drives Bullet.tick() directly with synthesized deltas; Game.test_mode
## stops _process from double-stepping the bullet during the same frame.
extends GutTest

const BULLET_SCRIPT: GDScript = preload("res://scripts/bullet.gd")

var bullet: Bullet


func before_each() -> void:
	Game.test_mode = true
	bullet = BULLET_SCRIPT.new()
	add_child_autofree(bullet)


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func test_bullet_moves_right_at_speed_when_direction_positive() -> void:
	bullet.position = Vector2(100.0, 0.0)
	bullet.direction = 1
	bullet.tick(1.0)
	assert_almost_eq(bullet.position.x, 100.0 + Bullet.SPEED_NORMAL, 0.001,
		"direction=1 should move bullet rightward by SPEED per second")


func test_bullet_moves_left_at_speed_when_direction_negative() -> void:
	bullet.position = Vector2(100.0, 0.0)
	bullet.direction = -1
	bullet.tick(1.0)
	assert_almost_eq(bullet.position.x, 100.0 - Bullet.SPEED_NORMAL, 0.001,
		"direction=-1 should move bullet leftward by SPEED per second")


# ---------------------------------------------------------------------------
# Distance-based expiry
# ---------------------------------------------------------------------------

func test_bullet_not_expired_immediately_after_spawn() -> void:
	bullet.position = Vector2(100.0, 0.0)
	bullet.direction = 1
	assert_false(bullet.is_expired(),
		"bullet must not be expired before any travel")


func test_bullet_not_expired_after_partial_travel() -> void:
	bullet.position = Vector2(0.0, 0.0)
	bullet.direction = 1
	# Travel half the max distance.
	bullet.tick(Bullet.MAX_TRAVEL * 0.5 / Bullet.SPEED_NORMAL)
	assert_false(bullet.is_expired(),
		"bullet should not expire mid-flight")


func test_bullet_expires_after_max_travel_distance() -> void:
	bullet.position = Vector2(0.0, 0.0)
	bullet.direction = 1
	# Travel exactly MAX_TRAVEL pixels in a single tick.
	bullet.tick(Bullet.MAX_TRAVEL / Bullet.SPEED_NORMAL)
	assert_true(bullet.is_expired(),
		"bullet should be expired once cumulative travel hits MAX_TRAVEL")


func test_bullet_expiry_independent_of_world_x_position() -> void:
	# Spawn far past the viewport (e.g., section C of stage_1) and confirm
	# the bullet does NOT immediately expire.
	bullet.position = Vector2(900.0, 0.0)
	bullet.direction = 1
	bullet.tick(0.016)
	assert_false(bullet.is_expired(),
		"bullets fired in scrolled-into-view areas must not insta-expire")


func test_bullet_expiry_uses_absolute_travel_when_moving_left() -> void:
	bullet.position = Vector2(0.0, 0.0)
	bullet.direction = -1
	# Move left by MAX_TRAVEL pixels — distance should accumulate via absf.
	bullet.tick(Bullet.MAX_TRAVEL / Bullet.SPEED_NORMAL)
	assert_true(bullet.is_expired(),
		"left-moving bullet should also expire by accumulated absolute distance")


# ---------------------------------------------------------------------------
# Charge level variants (V-006)
# ---------------------------------------------------------------------------

func test_charged_bullet_moves_at_charged_speed() -> void:
	bullet.position = Vector2(0.0, 0.0)
	bullet.direction = 1
	bullet.charge_level = 1
	bullet.tick(1.0)
	assert_almost_eq(bullet.position.x, Bullet.SPEED_CHARGED, 0.001,
		"charged bullet (level 1) should travel at SPEED_CHARGED, not SPEED_NORMAL")


func test_normal_bullet_speed_accessor() -> void:
	bullet.charge_level = 0
	assert_eq(bullet.speed(), Bullet.SPEED_NORMAL,
		"speed() must return SPEED_NORMAL for charge_level 0")


func test_charged_bullet_speed_accessor() -> void:
	bullet.charge_level = 1
	assert_eq(bullet.speed(), Bullet.SPEED_CHARGED,
		"speed() must return SPEED_CHARGED for charge_level >= 1")


# ---------------------------------------------------------------------------
# Lv2 super-charge (v0.56)
# ---------------------------------------------------------------------------

func test_super_bullet_speed_accessor() -> void:
	bullet.charge_level = 2
	assert_eq(bullet.speed(), Bullet.SPEED_SUPER,
		"speed() must return SPEED_SUPER for charge_level 2")


func test_damage_table_normal() -> void:
	bullet.charge_level = 0
	assert_eq(bullet.damage_for_level(), 1,
		"Lv0 bullet should deal 1 damage")


func test_damage_table_charged() -> void:
	bullet.charge_level = 1
	assert_eq(bullet.damage_for_level(), 2,
		"Lv1 bullet should deal 2 damage")


func test_damage_table_super() -> void:
	bullet.charge_level = 2
	assert_eq(bullet.damage_for_level(), 4,
		"Lv2 super bullet should deal 4 damage")

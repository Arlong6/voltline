## V-011 — EnemyBullet tests.
##
## Drives EnemyBullet.tick() directly with synthesized deltas; Game.test_mode
## stops _process from double-stepping during a tick().
extends GutTest

const ENEMY_BULLET_SCRIPT: GDScript = preload("res://scripts/enemy_bullet.gd")

var bullet: EnemyBullet


func before_each() -> void:
	Game.test_mode = true
	bullet = ENEMY_BULLET_SCRIPT.new()
	add_child_autofree(bullet)


func after_each() -> void:
	Game.test_mode = false


func test_bullet_moves_in_velocity_direction() -> void:
	bullet.position = Vector2(0.0, 0.0)
	bullet.velocity = Vector2(100.0, 50.0)
	bullet.tick(1.0)
	assert_almost_eq(bullet.position.x, 100.0, 0.001,
		"bullet should move +100 x in 1 second at vx=100")
	assert_almost_eq(bullet.position.y, 50.0, 0.001,
		"bullet should move +50 y in 1 second at vy=50")


func test_bullet_not_expired_immediately() -> void:
	bullet.velocity = Vector2(100.0, 0.0)
	assert_false(bullet.is_expired(),
		"bullet must not be expired before any travel")


func test_bullet_expires_after_max_travel() -> void:
	bullet.position = Vector2(0.0, 0.0)
	bullet.velocity = Vector2(EnemyBullet.MAX_TRAVEL, 0.0)  # 1 unit of travel = MAX_TRAVEL px
	bullet.tick(1.0)
	assert_true(bullet.is_expired(),
		"bullet should expire after traveling MAX_TRAVEL pixels")


func test_bullet_expiry_uses_total_distance_with_diagonal_motion() -> void:
	bullet.position = Vector2(0.0, 0.0)
	# 3-4-5 triangle scaled so total length = MAX_TRAVEL.
	var length: float = EnemyBullet.MAX_TRAVEL
	bullet.velocity = Vector2(length * 0.6, length * 0.8)  # |v| = length
	bullet.tick(1.0)
	assert_true(bullet.is_expired(),
		"diagonal travel must accumulate by Euclidean length")


# v0.66 — gravity-affected lob (Spitter's projectile).
func test_bullet_gravity_accumulates_downward_velocity() -> void:
	bullet.position = Vector2(0.0, 0.0)
	bullet.velocity = Vector2(100.0, -100.0)  # launched up-right
	bullet.gravity_accel =200.0
	bullet.tick(0.5)
	# After 0.5s at g=200, velocity.y should have grown by +100 → 0.0
	assert_almost_eq(bullet.velocity.y, 0.0, 0.001,
		"gravity must add g*delta to velocity.y each tick")


func test_bullet_with_zero_gravity_travels_in_a_straight_line() -> void:
	bullet.position = Vector2(0.0, 0.0)
	bullet.velocity = Vector2(100.0, 0.0)
	bullet.gravity_accel =0.0
	bullet.tick(0.5)
	assert_almost_eq(bullet.velocity.y, 0.0, 0.001,
		"zero gravity should leave velocity.y untouched")

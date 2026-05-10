## V-009 — Player HP, take_damage, and respawn tests.
##
## Drives Player.take_damage() and respawn() directly. The full hit→
## respawn path (Enemy Area2D body_entered → _on_enemy_hit → take_damage
## → respawn) is exercised by playtest, since wiring physics overlap
## requires a full SceneTree.
extends GutTest

const PLAYER_SCRIPT: GDScript = preload("res://scripts/player.gd")

var player: Player


func before_each() -> void:
	Game.test_mode = true
	player = PLAYER_SCRIPT.new()
	add_child_autofree(player)
	player._spawn_position = Vector2(48.0, 160.0)
	# _ready ran on add_child and set hp = max_hp; reset for each test.
	player.hp = player.max_hp
	player._invincible_timer = 0.0


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# take_damage
# ---------------------------------------------------------------------------

func test_take_damage_reduces_hp_without_killing_above_zero() -> void:
	player.hp = 16
	player.take_damage(4)
	assert_eq(player.hp, 12,
		"taking 4 damage from full hp should leave 12")


func test_take_damage_arms_invincibility_after_non_lethal_hit() -> void:
	player.take_damage(4)
	assert_almost_eq(player._invincible_timer, player.invincibility_duration, 0.001,
		"non-lethal hit should arm invincibility timer")


func test_take_damage_during_invincibility_is_noop() -> void:
	player.hp = 12
	player._invincible_timer = 0.5  # active
	player.take_damage(99)
	assert_eq(player.hp, 12,
		"damage during invincibility window should be ignored")


func test_take_damage_lethal_triggers_respawn_with_full_hp() -> void:
	player.hp = 2
	player.global_position = Vector2(900.0, 50.0)
	player.take_damage(99)
	assert_eq(player.hp, player.max_hp,
		"lethal damage should respawn the player with full hp")
	assert_eq(player.global_position, player._spawn_position,
		"lethal damage should teleport the player back to spawn")


# ---------------------------------------------------------------------------
# respawn
# ---------------------------------------------------------------------------

func test_respawn_sets_position_to_spawn_point() -> void:
	player.global_position = Vector2(900.0, 50.0)
	player.respawn()
	assert_eq(player.global_position, Vector2(48.0, 160.0),
		"respawn() must teleport the player to _spawn_position")


func test_respawn_zeroes_velocity() -> void:
	player.velocity = Vector2(220.0, -180.0)
	player.respawn()
	assert_eq(player.velocity, Vector2.ZERO,
		"respawn() must zero velocity")


func test_respawn_restores_full_hp() -> void:
	player.hp = 1
	player.respawn()
	assert_eq(player.hp, player.max_hp,
		"respawn() must restore hp to max_hp")


func test_respawn_arms_invincibility_timer() -> void:
	player._invincible_timer = 0.0
	player.respawn()
	assert_almost_eq(player._invincible_timer, player.invincibility_duration, 0.001,
		"respawn() must arm _invincible_timer to invincibility_duration")

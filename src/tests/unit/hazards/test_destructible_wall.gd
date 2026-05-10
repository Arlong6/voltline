## v0.60 — DestructibleWall threshold + state tests.
##
## A wall takes the hit but ONLY breaks when the damage meets
## min_break_damage (default 4 = matches Lv2 super charge exactly).
## Lower-damage hits register a shake without chipping HP — the design
## requires Lv2 to be a deliberate choice.
extends GutTest

const WALL_SCRIPT: GDScript = preload("res://scripts/destructible_wall.gd")

var wall: DestructibleWall


func before_each() -> void:
	Game.test_mode = true
	wall = WALL_SCRIPT.new()
	add_child_autofree(wall)


func after_each() -> void:
	Game.test_mode = false


func test_starts_intact() -> void:
	assert_false(wall.is_destroyed,
		"wall should start intact")


func test_lv0_hit_does_not_break() -> void:
	wall.take_damage(1)
	assert_false(wall.is_destroyed,
		"Lv0 (1 dmg) hits must not chip the wall")


func test_lv1_hit_does_not_break() -> void:
	wall.take_damage(2)
	assert_false(wall.is_destroyed,
		"Lv1 (2 dmg) hits must not chip the wall — Lv2 is mandatory")


func test_lv2_hit_breaks_in_one_shot() -> void:
	wall.take_damage(4)
	assert_true(wall.is_destroyed,
		"Lv2 (4 dmg) hit should break the wall in one shot")


func test_breaking_drops_collision_layer() -> void:
	wall.take_damage(4)
	assert_eq(wall.collision_layer, 0,
		"broken wall must drop collision_layer to 0 so the player walks through")


func test_repeat_damage_after_break_is_noop() -> void:
	wall.take_damage(4)
	wall.take_damage(99)  # should be ignored
	assert_true(wall.is_destroyed,
		"already-broken wall stays broken")


func test_custom_threshold_is_respected() -> void:
	wall.min_break_damage = 6
	wall.take_damage(4)
	assert_false(wall.is_destroyed,
		"raising the threshold should require more damage to break")
	wall.take_damage(6)
	assert_true(wall.is_destroyed,
		"meeting the new threshold should break the wall")


func test_destroy_can_be_called_directly() -> void:
	wall.destroy()
	assert_true(wall.is_destroyed,
		"destroy() must be callable directly (cheats / scripted breaks)")

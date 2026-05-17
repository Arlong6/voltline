## v0.71 — Base hub interaction tests.
extends GutTest

const BASE_SCENE: PackedScene = preload("res://scenes/base.tscn")

var container: Node2D
var base: Node2D


func before_each() -> void:
	Game.test_mode = true
	Game._last_goto_target = ""
	Game.best_scores.clear()
	Game.best_times.clear()
	Game.game_cleared = false
	Game.true_cleared = false
	Game.boss_rush_cleared = false
	Game.architect_cleared = false
	Game.labyrinth_cleared = false
	Game.circuit_cleared = false
	Game.faultline_cleared = false
	Game.terminus_cleared = false
	container = Node2D.new()
	add_child_autofree(container)
	base = BASE_SCENE.instantiate() as Node2D
	container.add_child(base)
	await get_tree().process_frame


func after_each() -> void:
	Game.test_mode = false
	Game._last_goto_target = ""


func test_player_spawn_position_is_grounded() -> void:
	var player: Player = base._player
	assert_almost_eq(player.position.y, 160.0, 5.0,
		"base player should spawn at the grounded hub start position")


func test_interaction_zone_detects_nearby_npc() -> void:
	base._player.position = Vector2(192.0, 156.0)
	base._process_interactions()
	assert_eq(base._nearby_npc, "AKI",
		"standing near AKI should make AKI the active NPC interaction")


func test_terminal_locked_blocks_goto() -> void:
	base.interact_with_terminal(9)
	assert_eq(Game._last_goto_target, "",
		"locked terminal should not route to a stage")


func test_terminal_unlocked_routes_to_stage() -> void:
	Game.best_scores["stage_1"] = 1000
	Game.best_scores["stage_2"] = 1000
	base.interact_with_terminal(3)
	assert_eq(Game._last_goto_target, "stage_3",
		"unlocked terminal should route to its matching stage")

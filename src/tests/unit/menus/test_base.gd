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
	Game.story_mode = false
	Game.briefings_seen.clear()
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


func test_unknown_terminal_index_is_ignored() -> void:
	# v0.80.2 — every legitimate sector is unlocked, but bogus indices
	# (e.g. 0, 11) still must not crash or route anywhere.
	base.interact_with_terminal(0)
	assert_eq(Game._last_goto_target, "",
		"terminal index 0 is out of range and must not route")
	base.interact_with_terminal(11)
	assert_eq(Game._last_goto_target, "",
		"terminal index 11 is out of range and must not route")


func test_terminal_unlocked_routes_to_stage() -> void:
	Game.best_scores["stage_1"] = 1000
	Game.best_scores["stage_2"] = 1000
	base.interact_with_terminal(3)
	assert_eq(Game._last_goto_target, "stage_3",
		"unlocked terminal should route to its matching stage")


# v0.73 — briefing flow

func test_story_mode_first_terminal_entry_plays_briefing() -> void:
	Game.best_scores["stage_1"] = 1000
	Game.best_scores["stage_2"] = 1000
	Game.story_mode = true
	Game.briefings_seen.clear()
	base.interact_with_terminal(3)
	assert_eq(Game._last_goto_target, "cutscene",
		"first entry into a sector in story mode should play the briefing first")
	assert_eq(Game.cutscene_next, "stage_3",
		"the briefing cutscene should continue into the targeted stage")
	assert_true(Game.briefings_seen.has("stage_3"),
		"the briefing should be marked as seen so retries skip it")


func test_story_mode_repeat_terminal_entry_skips_briefing() -> void:
	Game.best_scores["stage_1"] = 1000
	Game.best_scores["stage_2"] = 1000
	Game.story_mode = true
	Game.briefings_seen.clear()
	Game.briefings_seen.append("stage_3")
	base.interact_with_terminal(3)
	assert_eq(Game._last_goto_target, "stage_3",
		"repeat visits should skip the briefing and go straight into the stage")

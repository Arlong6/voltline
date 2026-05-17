## v0.71 — Story mode routing tests.
extends GutTest


func before_each() -> void:
	Game.test_mode = true
	Game._last_goto_target = ""
	Game.story_mode = false
	Game.story_progress = 0
	Game.best_scores.clear()
	Game.best_times.clear()
	Game.session_time = 0.0
	Game.session_hits = 0
	Game.session_kills = 0
	Game.session_coins = 0


func after_each() -> void:
	Game.test_mode = false
	Game.story_mode = false
	Game._last_goto_target = ""


func test_return_to_base_in_story_mode_goes_to_base() -> void:
	Game.story_mode = true
	Game.return_to_base_or_title("stage_3")
	assert_eq(Game._last_goto_target, "base",
		"story clears should route back to the base hub")


func test_return_to_title_outside_story_mode_goes_to_title() -> void:
	Game.story_mode = false
	Game.return_to_base_or_title("stage_3")
	assert_eq(Game._last_goto_target, "title",
		"non-story clears should route back to title")


func test_start_story_mode_sets_flag_and_routes_to_cutscene() -> void:
	Game.start_story_mode()
	assert_true(Game.story_mode,
		"start_story_mode should enable the story flag")
	assert_eq(Game._last_goto_target, "cutscene",
		"start_story_mode should enter the intro cutscene")
	assert_eq(Game.cutscene_next, "base",
		"intro cutscene should continue to the base")

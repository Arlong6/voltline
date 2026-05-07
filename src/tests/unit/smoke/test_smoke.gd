## V-001 smoke test — proves the GUT harness, autoloads, and scene routing
## constants are wired correctly. Replaced / expanded by V-002 as soon as
## the player controller exists.
extends GutTest


func test_game_autoload_exists() -> void:
	assert_not_null(Game,
		"Game autoload should be loaded before any test runs")


func test_game_default_session_time_is_zero() -> void:
	Game.reset_run()
	assert_eq(Game.session_time, 0.0,
		"reset_run() should zero the session timer")


func test_game_level_paths_known_keys() -> void:
	# Lock the v0.1 scene routing so a typo in goto_level("title") later
	# fails loudly here rather than silently no-op'ing in production.
	assert_true(Game.LEVEL_PATHS.has("title"),
		"LEVEL_PATHS must define 'title'")
	assert_true(Game.LEVEL_PATHS.has("stage_1"),
		"LEVEL_PATHS must define 'stage_1'")

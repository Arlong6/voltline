## Voltline — global game state autoload.
##
## Mirrors the night-market pattern: thin coordinator that owns scene
## transitions, the test_mode flag (so headless GUT tests can short-circuit
## time-driven systems), and a per-run timer.
##
## Kept intentionally bare in v0.1; future versions will hang weapon
## inventory + boss-clear flags off this node.
extends Node

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## Name of the active scene/area. Stages set this on _ready so other
## systems (HUD, music, save) can branch by area.
var current_area: String = ""

## True only inside the GUT runner. Time-dependent systems (player physics,
## enemy AI, particle FX) must short-circuit when this is true so unit
## tests stay deterministic.
var test_mode: bool = false

## Seconds the player has spent in a stage since the last reset_run().
var session_time: float = 0.0

## True after the player clears the final stage — title screen reads this
## to swap the prompt for a "GAME CLEAR" celebration line.
var game_cleared: bool = false

## True after the player clears Stage 5 (post-clear bonus stage). Title
## screen swaps the prompt to a "TRUE CLEAR" line and unlocks any future
## post-truth content. Implies game_cleared = true.
var true_cleared: bool = false

## True after the player clears Boss Rush mode (post-true-clear unlock).
## Adds a third tier of celebration text on the title screen.
var boss_rush_cleared: bool = false

# ---------------------------------------------------------------------------
# Cutscene staging — the cutscene scene reads these on _ready.
# ---------------------------------------------------------------------------

## Title shown above the typewriter text in the cutscene scene.
var cutscene_title: String = ""

## Lines of dialogue to type out one at a time (X advances).
var cutscene_lines: PackedStringArray = PackedStringArray()

## Logical scene key the cutscene routes to after the last line.
var cutscene_next: String = "title"

## Coins persisted across all sessions — currency for the title-screen
## shop. Saved to disk after every change so a crash mid-run doesn't lose
## the player's grind.
var coins: int = 0

## Number of times each upgrade has been purchased. Stage spawns apply
## these via `apply_upgrades_to(player)` before the player enters the tree.
var upgrade_hp_count: int = 0
var upgrade_dash_count: int = 0
var upgrade_shoot_count: int = 0

## Save file lives in the user-data dir so it survives reinstalls of the
## project itself.
const SAVE_PATH: String = "user://voltline_save.cfg"

## Per-purchase deltas (how much one upgrade level adds).
const UPGRADE_HP_DELTA: int = 4
const UPGRADE_DASH_DELTA: float = 30.0
const UPGRADE_SHOOT_DELTA: float = 0.03


## Adds `amount` to the persistent coin total and writes the save file.
func add_coin(amount: int) -> void:
	coins += amount
	save_to_file()


## Applies all purchased upgrades to a freshly-instantiated Player BEFORE
## it enters the tree (so its _ready picks up the new max_hp).
func apply_upgrades_to(player: Player) -> void:
	player.max_hp += upgrade_hp_count * UPGRADE_HP_DELTA
	player.dash_speed += upgrade_dash_count * UPGRADE_DASH_DELTA
	player.shoot_interval = maxf(
		0.05,
		player.shoot_interval - float(upgrade_shoot_count) * UPGRADE_SHOOT_DELTA
	)


## Persists coins, upgrade counts, and game_cleared status to disk.
## No-op in test mode so headless GUT runs don't pollute the save file.
func save_to_file() -> void:
	if test_mode:
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("game", "coins", coins)
	cfg.set_value("game", "upgrade_hp", upgrade_hp_count)
	cfg.set_value("game", "upgrade_dash", upgrade_dash_count)
	cfg.set_value("game", "upgrade_shoot", upgrade_shoot_count)
	cfg.set_value("game", "game_cleared", game_cleared)
	cfg.set_value("game", "true_cleared", true_cleared)
	cfg.set_value("game", "boss_rush_cleared", boss_rush_cleared)
	cfg.save(SAVE_PATH)


## Loads persistent state from disk. Called by Title._ready when the
## title screen first comes up; other scenes do NOT call this so a stage
## reload doesn't undo in-stage state.
func load_from_file() -> void:
	if test_mode:
		return
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # fresh start — defaults stay in place
	coins = cfg.get_value("game", "coins", 0)
	upgrade_hp_count = cfg.get_value("game", "upgrade_hp", 0)
	upgrade_dash_count = cfg.get_value("game", "upgrade_dash", 0)
	upgrade_shoot_count = cfg.get_value("game", "upgrade_shoot", 0)
	game_cleared = cfg.get_value("game", "game_cleared", false)
	true_cleared = cfg.get_value("game", "true_cleared", false)
	boss_rush_cleared = cfg.get_value("game", "boss_rush_cleared", false)

# ---------------------------------------------------------------------------
# Scene routing
# ---------------------------------------------------------------------------

const LEVEL_PATHS: Dictionary[String, String] = {
	"title":   "res://scenes/menus/title.tscn",
	"stage_1": "res://scenes/levels/stage_1.tscn",
	"stage_2": "res://scenes/levels/stage_2.tscn",
	"stage_3": "res://scenes/levels/stage_3.tscn",
	"stage_4": "res://scenes/levels/stage_4.tscn",
	"stage_5": "res://scenes/levels/stage_5.tscn",
	"boss_rush": "res://scenes/levels/boss_rush.tscn",
	"cutscene":  "res://scenes/cutscene.tscn",
}


## Convenience: stash the cutscene payload and route to it. The cutscene
## scene reads the three `cutscene_*` fields on _ready and then calls
## goto_level(cutscene_next) when the player advances past the last line.
func play_cutscene(title: String, lines: PackedStringArray, next: String) -> void:
	cutscene_title = title
	cutscene_lines = lines
	cutscene_next = next
	goto_level("cutscene")


func _process(delta: float) -> void:
	if current_area.begins_with("stage_"):
		session_time += delta


## Resolves a logical key to a scene path and triggers a deferred change.
## No-op for unknown keys (warning only) so a typo doesn't crash the game.
func goto_level(key: String) -> void:
	if not LEVEL_PATHS.has(key):
		push_warning("goto_level: unknown key '%s'" % key)
		return
	get_tree().change_scene_to_file(LEVEL_PATHS[key])


## Wipes per-run state. Called by stage scripts on respawn / by the title
## screen on restart. NOTE: coins, upgrades, and game_cleared persist
## across runs (they're saved to disk) — only the per-session timer
## resets here.
func reset_run() -> void:
	session_time = 0.0

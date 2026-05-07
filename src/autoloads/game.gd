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

# ---------------------------------------------------------------------------
# Scene routing
# ---------------------------------------------------------------------------

const LEVEL_PATHS: Dictionary[String, String] = {
	"title":   "res://scenes/menus/title.tscn",
	"stage_1": "res://scenes/levels/stage_1.tscn",
}


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
## screen on restart.
func reset_run() -> void:
	session_time = 0.0

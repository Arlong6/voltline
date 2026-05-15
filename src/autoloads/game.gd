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

## Number of times the player has been hit during the current run.
## Incremented from Player.take_damage; reset by reset_run().
var session_hits: int = 0

## Number of enemies the player has killed during the current run.
## Stages / enemies bump this via Game.register_kill().
var session_kills: int = 0

## Number of coins picked up during the current run (separate from the
## persistent total). Incremented in add_coin; reset by reset_run().
var session_coins: int = 0

## Best score per stage key (e.g. "stage_1" → 4500). Persisted to disk so
## the title-screen leaderboard / stage-clear "NEW BEST" banner survive
## restarts.
var best_scores: Dictionary[String, int] = {}

## Best clear time per stage key (seconds). Lower = better. Persisted.
var best_times: Dictionary[String, float] = {}

## Total number of stage runs initiated since save creation. Bumped by
## reset_run() so dying + retrying counts as one run.
var total_runs: int = 0

## Lifetime count of DestructibleWall instances destroyed across all
## runs. Drives the TREASURE_HUNTER achievement.
var walls_broken: int = 0

# ---------------------------------------------------------------------------
# Achievements (v0.65) — see ACHIEVEMENT_DEFS for the full table.
# ---------------------------------------------------------------------------

## Bool state per achievement id. Persisted across runs.
var achievements: Dictionary[String, bool] = {}

## Achievement definitions in display order. Each entry:
##   id           — stable key, also the dict key in `achievements`
##   name         — short title for the HUD
##   description  — one-line explanation of how to earn it
const ACHIEVEMENT_DEFS: Array = [
	{"id": "first_clear",   "name": "FIRST CLEAR",      "description": "Beat Stage 1"},
	{"id": "game_clear",    "name": "GAME CLEAR",       "description": "Beat TYRANT-Z (Stage 4)"},
	{"id": "true_clear",    "name": "TRUE CLEAR",       "description": "Beat TYRANT-Z² (Stage 5)"},
	{"id": "rush_clear",    "name": "RUSH CLEAR",       "description": "Beat Boss Rush mode"},
	{"id": "architect",     "name": "ARCHITECT FELL",   "description": "Beat GRID-0 (Stage 6)"},
	{"id": "s_rank",        "name": "S-RANK",           "description": "Get S+ rank on any stage"},
	{"id": "sss_rank",      "name": "SSS-RANK",         "description": "Get SSS rank on any stage"},
	{"id": "flawless",      "name": "FLAWLESS",         "description": "Clear any stage with 0 hits"},
	{"id": "speedrun",      "name": "SPEEDRUN",         "description": "Clear Stage 1 in under 60s"},
	{"id": "treasure",      "name": "TREASURE HUNTER",  "description": "Break 5 hidden walls"},
	{"id": "century",       "name": "CENTURY",          "description": "Hold 100+ coins"},
	{"id": "marathoner",    "name": "MARATHONER",       "description": "Start 50 stage runs"},
]


## Unlocks the achievement if not already unlocked. Idempotent; safe to
## call from any trigger site. Returns true on the unlock tick (so HUD
## can spawn a toast banner) and false if already owned.
func unlock_achievement(id: String) -> bool:
	if bool(achievements.get(id, false)):
		return false
	achievements[id] = true
	save_to_file()
	return true


## True if the named achievement has been earned.
func has_achievement(id: String) -> bool:
	return bool(achievements.get(id, false))


## Re-checks the passive achievements (coin / runs / walls thresholds).
## Called from add_coin, reset_run, register_wall_break. Cheap to call
## from anywhere.
func check_passive_achievements() -> void:
	if coins >= 100:
		unlock_achievement("century")
	if total_runs >= 50:
		unlock_achievement("marathoner")
	if walls_broken >= 5:
		unlock_achievement("treasure")


## Called by DestructibleWall when it destroy()s — drives the
## treasure-hunter achievement count.
func register_wall_break() -> void:
	walls_broken += 1
	check_passive_achievements()

# ---------------------------------------------------------------------------
# Hit-stop (v0.63) — Engine.time_scale dial that decays back to 1 over
# `_hit_stop_remaining` seconds. Triggered by impactful events (Lv2 super
# bullet hits enemy, boss damage taken, big boss death). Visual "freeze"
# that punches up the moment of impact.
# ---------------------------------------------------------------------------

var _hit_stop_remaining: float = 0.0
var _hit_stop_scale: float = 1.0

# ---------------------------------------------------------------------------
# Timed power-up buffs (v0.64)
# ---------------------------------------------------------------------------

## Active buffs and their remaining seconds. Keys: BUFF_* string ids.
## Stages / HUD / damage / coin logic check `is_buff_active(key)` or read
## `buffs[key]` directly. Cleared on reset_run.
var buffs: Dictionary[String, float] = {}

const BUFF_INVINCIBLE: String = "invincible"
const BUFF_DAMAGE_UP:  String = "damage_up"
const BUFF_RAPID_FIRE: String = "rapid_fire"
const BUFF_MAGNET:     String = "magnet"

const _BUFF_DURATIONS: Dictionary = {
	BUFF_INVINCIBLE: 8.0,
	BUFF_DAMAGE_UP:  10.0,
	BUFF_RAPID_FIRE: 10.0,
	BUFF_MAGNET:     15.0,
}


# ---------------------------------------------------------------------------
# Sub-weapons (v0.64)
# ---------------------------------------------------------------------------

const SUBWEAPON_MISSILE:   String = "missile"
const SUBWEAPON_SHOCKWAVE: String = "shockwave"
const SUBWEAPON_MINE:      String = "mine"
const SUBWEAPON_WAVE:      String = "wave"

# Declared as `var` because PackedStringArray constructors are not
# constant expressions in GDScript. Treat as immutable in code.
var SUBWEAPON_LIST: PackedStringArray = PackedStringArray([
	SUBWEAPON_MISSILE, SUBWEAPON_SHOCKWAVE, SUBWEAPON_MINE, SUBWEAPON_WAVE,
])

const SUBWEAPON_COOLDOWNS: Dictionary = {
	SUBWEAPON_MISSILE:   2.0,
	SUBWEAPON_SHOCKWAVE: 3.5,
	SUBWEAPON_MINE:      4.0,
	SUBWEAPON_WAVE:      3.0,
}

const SUBWEAPON_LABELS: Dictionary = {
	SUBWEAPON_MISSILE:   "MISSILE",
	SUBWEAPON_SHOCKWAVE: "SHOCKWAVE",
	SUBWEAPON_MINE:      "MINE",
	SUBWEAPON_WAVE:      "WAVE",
}

## Currently equipped sub-weapon key. Player cycles via Q. Persisted.
var equipped_subweapon: String = SUBWEAPON_MISSILE

## Remaining cooldown seconds before the equipped sub-weapon can fire
## again. Decremented in _process; consumed when Player presses SHIFT.
var subweapon_cooldown_remaining: float = 0.0


## Cycles the equipped sub-weapon to the next entry in SUBWEAPON_LIST.
## Resets the cooldown so swapping isn't a free reroll on a ready charge.
func cycle_subweapon() -> void:
	var idx: int = SUBWEAPON_LIST.find(equipped_subweapon)
	idx = (idx + 1) % SUBWEAPON_LIST.size()
	equipped_subweapon = SUBWEAPON_LIST[idx]
	subweapon_cooldown_remaining = 0.5  # short post-swap warmup
	save_to_file()


## True when the equipped sub-weapon is off cooldown and can fire.
func subweapon_ready() -> bool:
	return subweapon_cooldown_remaining <= 0.0


## Called by Player after spawning the projectile/effect — arms the
## per-weapon cooldown.
func consume_subweapon() -> void:
	subweapon_cooldown_remaining = float(SUBWEAPON_COOLDOWNS.get(
		equipped_subweapon, 2.0
	))


## Activates `buff_key` for its default duration. If already active,
## extends to the longer of the two (so picking up two of the same
## doesn't waste the second one).
func activate_buff(buff_key: String) -> void:
	var duration: float = float(_BUFF_DURATIONS.get(buff_key, 0.0))
	if duration <= 0.0:
		return
	var current: float = float(buffs.get(buff_key, 0.0))
	buffs[buff_key] = maxf(current, duration)


## True if the named buff has remaining duration.
func is_buff_active(buff_key: String) -> bool:
	return float(buffs.get(buff_key, 0.0)) > 0.0


## Remaining seconds for the named buff (0 if not active).
func buff_remaining(buff_key: String) -> float:
	return float(buffs.get(buff_key, 0.0))


## Requests a screen-shake on the active player's camera. Pure relay
## so callers (Bullet, Boss death, etc.) don't have to look up the
## player themselves. No-op in test mode and if no player is in the tree.
func request_shake(strength: float) -> void:
	if test_mode:
		return
	var tree: SceneTree = (Engine.get_main_loop() as SceneTree)
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player != null and player.has_method("shake"):
		player.shake(strength)


## Triggers a brief slowdown. `duration` is wall-clock seconds the
## slowdown lasts; `scale` is the time_scale during the freeze (lower =
## more freeze, 0.0 = full pause). Subsequent calls extend if the new
## window is heavier.
func hit_stop(duration: float = 0.06, scale: float = 0.05) -> void:
	if test_mode:
		return
	# Only override if the incoming freeze is at least as heavy.
	if scale < _hit_stop_scale or _hit_stop_remaining <= 0.0:
		_hit_stop_scale = scale
	_hit_stop_remaining = maxf(_hit_stop_remaining, duration)
	Engine.time_scale = _hit_stop_scale


func _process(delta: float) -> void:
	if current_area.begins_with("stage_") or current_area == "boss_rush":
		session_time += delta
	# Decay active buffs.
	if not buffs.is_empty():
		var expired: Array[String] = []
		for key in buffs.keys():
			buffs[key] = buffs[key] - delta
			if buffs[key] <= 0.0:
				expired.append(key)
		for key in expired:
			buffs.erase(key)
	# Decay sub-weapon cooldown.
	if subweapon_cooldown_remaining > 0.0:
		subweapon_cooldown_remaining = maxf(subweapon_cooldown_remaining - delta, 0.0)
	if _hit_stop_remaining > 0.0:
		# Decay in WALL-clock seconds, not delta (delta is already
		# stretched by time_scale). get_process_delta_time() returns
		# unscaled delta when called from _process? Actually it returns
		# scaled. Use raw delta but factor by 1/time_scale.
		var wall_delta: float = delta / maxf(_hit_stop_scale, 0.001)
		_hit_stop_remaining = maxf(_hit_stop_remaining - wall_delta, 0.0)
		if _hit_stop_remaining <= 0.0:
			_hit_stop_scale = 1.0
			Engine.time_scale = 1.0

# ---------------------------------------------------------------------------
# Settings — persisted, mutated by the pause-menu sliders.
# ---------------------------------------------------------------------------

## Linear 0..1 master bus volume multiplier. Default biased low because
## the procedural square waves are bright.
var setting_master_volume: float = 0.7
var setting_sfx_volume: float = 1.0
var setting_music_volume: float = 0.7

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

## True after the player defeats GRID-0 in Stage 6 (the post-rush
## nightmare unlock).
var architect_cleared: bool = false

## True after the player clears Stage 7 (LABYRINTH) — the multi-room
## post-architect mission.
var labyrinth_cleared: bool = false

## True after the player clears Stage 8 (CIRCUIT) — the v0.67 endgame
## stage that mixes the new hazard + enemy roster around a GRID-0
## rematch.
var circuit_cleared: bool = false

## True after the player clears Stage 9 (FAULTLINE) — the v0.69
## post-Circuit stage and VEIN-K encounter.
var faultline_cleared: bool = false

# ---------------------------------------------------------------------------
# Daily Run (v0.67) — seeded by today's date, picks one stage + one
# modifier. Player must beat that combo for the daily score to count.
# The flag is cleared on returning to the title screen.
# ---------------------------------------------------------------------------

## True while the player is inside a Daily Run. Player + Enemy read this
## (plus daily_run_modifier) on _ready to apply the active modifier.
var daily_run_active: bool = false

## Active modifier id when daily_run_active. One of DAILY_MOD_* below.
var daily_run_modifier: String = ""

## Stage key today's daily run selected (one of stage_1..stage_9).
var daily_run_stage: String = ""

const DAILY_MOD_ONE_SHOT:  String = "one_shot"   # max_hp = 1
const DAILY_MOD_TURBO:     String = "turbo"      # enemy speed × 1.5
const DAILY_MOD_SLOW_FIRE: String = "slow_fire"  # player shoot_interval × 2

## Modifier pool the daily picker draws from. Same shape as SUBWEAPON_LIST
## — declared as var to dodge the const-constructor restriction.
var DAILY_MOD_LIST: PackedStringArray = PackedStringArray([
	DAILY_MOD_ONE_SHOT, DAILY_MOD_TURBO, DAILY_MOD_SLOW_FIRE,
])

const DAILY_STAGE_LIST: Array[String] = [
	"stage_1", "stage_2", "stage_3", "stage_4",
	"stage_5", "stage_6", "stage_7", "stage_8", "stage_9",
]

## Per-date best score for daily runs. Key is "YYYY-MM-DD".
var daily_best_scores: Dictionary[String, int] = {}


## Builds today's date string ("YYYY-MM-DD") from system time. Pulled out
## as a function so tests can call it without poking Time directly.
func today_iso() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


## Deterministic daily seed — same calendar day always produces the same
## stage + modifier pick. Tests can override `iso` to drive specific dates.
func daily_seed_for(iso: String) -> int:
	var parts: PackedStringArray = iso.split("-")
	if parts.size() < 3:
		return 0
	return int(parts[0]) * 10000 + int(parts[1]) * 100 + int(parts[2])


## Picks (stage_key, modifier) for the given ISO date. Pure function.
func daily_pick_for(iso: String) -> Dictionary:
	var seed_val: int = daily_seed_for(iso)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(seed_val)
	var stage_idx: int = rng.randi() % DAILY_STAGE_LIST.size()
	var mod_idx: int = rng.randi() % DAILY_MOD_LIST.size()
	return {
		"stage": DAILY_STAGE_LIST[stage_idx],
		"modifier": String(DAILY_MOD_LIST[mod_idx]),
	}


## Starts a daily run: sets the flags + reset_run, then goto_level.
## Called by the title screen when the player picks DAILY RUN.
func begin_daily_run() -> void:
	var pick: Dictionary = daily_pick_for(today_iso())
	daily_run_stage = String(pick["stage"])
	daily_run_modifier = String(pick["modifier"])
	daily_run_active = true
	reset_run()
	goto_level(daily_run_stage)


## Records the daily run's score for today's date. Called by register_clear
## when daily_run_active is true. Returns true on a new daily best.
func register_daily_clear(score: int) -> bool:
	var key: String = today_iso()
	var prev: int = int(daily_best_scores.get(key, 0))
	if score > prev:
		daily_best_scores[key] = score
		return true
	return false

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

# ---------------------------------------------------------------------------
# Skins (v0.67) — cosmetic player palettes, bought with persistent coins.
# Skin 0 is the default and always owned. Higher-index skins cost progressively
# more. Pressing 4 in the title shop tries to switch to / buy the next skin.
# ---------------------------------------------------------------------------

## All four skin palettes, ordered by unlock cost. Player._draw reads
## `SKIN_COLORS[skin_index]` for the body / silhouette tint.
const SKIN_COLORS: Array[Color] = [
	Color("#7AC8FF"),  # default — neon cyan
	Color("#FF6080"),  # crimson
	Color("#FFD24A"),  # gold
	Color("#A060FF"),  # plasma violet
]

# PackedStringArray / PackedInt32Array constructors aren't constant
# expressions — declared as `var` but treated as immutable.
static var SKIN_NAMES: PackedStringArray = PackedStringArray([
	"CYAN", "CRIMSON", "GOLD", "PLASMA",
])

static var SKIN_COSTS: PackedInt32Array = PackedInt32Array([0, 30, 60, 100])

## Currently selected skin (0..3). Player draws using this index.
var skin_index: int = 0

## Per-skin ownership flags. Skin 0 is implicit (always owned).
var skin_owned: Dictionary[int, bool] = {}


## True if the player has unlocked this skin index. Index 0 is always
## considered owned (default skin).
func is_skin_owned(idx: int) -> bool:
	if idx == 0:
		return true
	return bool(skin_owned.get(idx, false))


## Selects the supplied skin index if it's owned. No-op otherwise.
## Saves to disk so the choice survives a restart.
func select_skin(idx: int) -> void:
	if idx < 0 or idx >= SKIN_COLORS.size():
		return
	if not is_skin_owned(idx):
		return
	skin_index = idx
	save_to_file()


## Try to advance to the next skin. Wraps from the last entry back to 0.
## If the destination is already owned, switches to it. If not owned and
## the player can afford it, buys-and-switches. Returns the action taken:
## "switched" / "bought" / "no_op" — so the title can play a different SFX.
func try_advance_skin() -> String:
	var n: int = SKIN_COLORS.size()
	if n <= 1:
		return "no_op"
	var next_idx: int = (skin_index + 1) % n
	if is_skin_owned(next_idx):
		skin_index = next_idx
		save_to_file()
		return "switched"
	var cost: int = SKIN_COSTS[next_idx]
	if coins < cost:
		return "no_op"
	coins -= cost
	skin_owned[next_idx] = true
	skin_index = next_idx
	save_to_file()
	return "bought"

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


## Adds `amount` to the persistent coin total + the per-run session total
## (used by the score formula) and writes the save file.
func add_coin(amount: int) -> void:
	coins += amount
	session_coins += amount
	check_passive_achievements()
	save_to_file()


## Bumped by Player.take_damage on every hit landed against the player.
## Used by the per-stage score formula.
func register_hit() -> void:
	session_hits += 1


## Bumped by Enemy.die when the player's bullet (or other player-driven
## damage) brought the kill. Used by the score formula.
func register_kill() -> void:
	session_kills += 1


## Computes the score for the current run state and rank tier. Pure
## function so tests can drive it with synthesized values. Higher = better.
##
## Formula (max ≈ 5000):
##   base       = 1000  (just for clearing)
##   time_bonus = max(0, 2000 - session_time × 10)   — sub-200s = full bonus
##   hit_bonus  = max(0, 1500 - session_hits × 200)  — no-hit = 1500
##   kill_bonus = session_kills × 25                  — uncapped, ~10 kills = +250
##   coin_bonus = session_coins × 8                   — uncapped, ~30 coins = +240
##   TOTAL      = sum of the above
func compute_score() -> int:
	var base: int = 1000
	var time_bonus: int = clampi(2000 - int(session_time * 10.0), 0, 2000)
	var hit_bonus: int = clampi(1500 - session_hits * 200, 0, 1500)
	var kill_bonus: int = session_kills * 25
	var coin_bonus: int = session_coins * 8
	return base + time_bonus + hit_bonus + kill_bonus + coin_bonus


## Threshold table for the rank tiers — cut points are exclusive lower
## bounds (score >= threshold means at least this rank).
const RANK_TIERS: Array = [
	[5000, "SSS"],
	[4500, "SS"],
	[4000, "S"],
	[3500, "A"],
	[3000, "B"],
	[2500, "C"],
	[0,    "D"],
]


## Returns the rank string for a given score.
func rank_for_score(score: int) -> String:
	for tier in RANK_TIERS:
		if score >= int(tier[0]):
			return String(tier[1])
	return "D"


## Coin payout awarded on clear for each rank tier. Scales hard at the
## top so chasing S/SS/SSS actually funds the shop.
const RANK_COIN_BONUS: Dictionary = {
	"SSS": 50,
	"SS":  35,
	"S":   25,
	"A":   15,
	"B":   10,
	"C":    5,
	"D":    0,
}


## Coin bonus for a rank string (0 for unknown).
func rank_coin_bonus(rank: String) -> int:
	return int(RANK_COIN_BONUS.get(rank, 0))


## Coin bonus awarded by the most recent register_clear() — read by
## format_score_summary so the clear banner can show "+N COINS".
var last_clear_coin_bonus: int = 0


## Records the current run's score against `stage_key`. Persists the
## new best (and the all-flags state) to disk. Returns true if the
## score was a new best, so the stage clear screen can show "NEW BEST".
##
## Also updates best_times when the current session_time beats the
## previous record (independent of score).
func register_clear(stage_key: String) -> bool:
	var score: int = compute_score()
	var prev: int = int(best_scores.get(stage_key, 0))
	var is_new_best: bool = score > prev
	if is_new_best:
		best_scores[stage_key] = score
	var prev_time: float = float(best_times.get(stage_key, INF))
	if session_time < prev_time:
		best_times[stage_key] = session_time
	# v0.65 — achievement triggers tied to clear context.
	if stage_key == "stage_1":
		unlock_achievement("first_clear")
		if session_time < 60.0:
			unlock_achievement("speedrun")
	if stage_key == "stage_7":
		labyrinth_cleared = true
	if stage_key == "stage_8":
		circuit_cleared = true
	if stage_key == "stage_9":
		faultline_cleared = true
	var rank: String = rank_for_score(score)
	if rank == "SSS":
		unlock_achievement("sss_rank")
		unlock_achievement("s_rank")  # SSS implies S
	elif rank == "SS" or rank == "S":
		unlock_achievement("s_rank")
	if session_hits == 0:
		unlock_achievement("flawless")
	if game_cleared:
		unlock_achievement("game_clear")
	if true_cleared:
		unlock_achievement("true_clear")
	if boss_rush_cleared:
		unlock_achievement("rush_clear")
	if architect_cleared:
		unlock_achievement("architect")
	# v0.66 — pay out a coin bonus scaled by rank. add_coin saves the
	# file itself; we still call save_to_file below to capture the
	# best_scores / best_times / clear flags in one write.
	last_clear_coin_bonus = rank_coin_bonus(rank)
	if last_clear_coin_bonus > 0:
		add_coin(last_clear_coin_bonus)
	# v0.67 — daily-run completion logs against today's date independent
	# of the per-stage best_scores entry.
	if daily_run_active:
		register_daily_clear(score)
	save_to_file()
	return is_new_best


## Formats the live score + rank for the stage clear banner. Caller
## passes the boolean returned by register_clear so the "NEW BEST" tag
## can be tacked on.
func format_score_summary(is_new_best: bool) -> String:
	var score: int = compute_score()
	var rank: String = rank_for_score(score)
	var tag: String = "  NEW BEST" if is_new_best else ""
	var bonus_line: String = ""
	if last_clear_coin_bonus > 0:
		bonus_line = "\n+%d COINS" % last_clear_coin_bonus
	return "SCORE %d  RANK %s%s%s" % [score, rank, tag, bonus_line]


## Formats a time in seconds as M:SS.s (e.g., 1:23.4). Used by the
## stage-select panel and the stats summary.
func format_time(seconds: float) -> String:
	if seconds <= 0.0 or seconds == INF:
		return "--:--"
	var mins: int = int(seconds) / 60
	var secs: float = seconds - float(mins * 60)
	return "%d:%05.2f" % [mins, secs]


## True when `stage_key`'s prerequisite has been cleared. Used by the
## stage-select panel + KEY hot-keys to gate access. Stage 1 is always
## free; subsequent stages each require the previous stage's clear or
## an equivalent flag.
func is_stage_unlocked(stage_key: String) -> bool:
	match stage_key:
		"stage_1":
			return true
		"stage_2":
			return best_scores.has("stage_1")
		"stage_3":
			return best_scores.has("stage_2")
		"stage_4":
			return best_scores.has("stage_3")
		"stage_5":
			return game_cleared
		"boss_rush":
			return true_cleared
		"stage_6":
			return boss_rush_cleared
		"stage_7":
			return architect_cleared
		"stage_8":
			return labyrinth_cleared
		"stage_9":
			return circuit_cleared
		"daily":
			# Always available — daily run is the "endless" challenge mode.
			return true
	return false


## Applies all purchased upgrades to a freshly-instantiated Player BEFORE
## it enters the tree (so its _ready picks up the new max_hp).
func apply_upgrades_to(player: Player) -> void:
	player.max_hp += upgrade_hp_count * UPGRADE_HP_DELTA
	player.dash_speed += upgrade_dash_count * UPGRADE_DASH_DELTA
	player.shoot_interval = maxf(
		0.05,
		player.shoot_interval - float(upgrade_shoot_count) * UPGRADE_SHOOT_DELTA
	)
	# v0.67 — daily-run modifiers stack on top of regular upgrades.
	if daily_run_active:
		match daily_run_modifier:
			DAILY_MOD_ONE_SHOT:
				player.max_hp = 1
			DAILY_MOD_SLOW_FIRE:
				player.shoot_interval = player.shoot_interval * 2.0


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
	cfg.set_value("game", "architect_cleared", architect_cleared)
	cfg.set_value("game", "labyrinth_cleared", labyrinth_cleared)
	cfg.set_value("game", "circuit_cleared", circuit_cleared)
	cfg.set_value("game", "faultline_cleared", faultline_cleared)
	var daily_scores: Dictionary = {}
	for key in daily_best_scores.keys():
		daily_scores[String(key)] = int(daily_best_scores[key])
	cfg.set_value("game", "daily_best_scores", daily_scores)
	# Best scores — flatten the typed dictionary into a plain dict for
	# ConfigFile (Variant-friendly).
	var scores: Dictionary = {}
	for key in best_scores.keys():
		scores[key] = best_scores[key]
	cfg.set_value("game", "best_scores", scores)
	var times: Dictionary = {}
	for key in best_times.keys():
		times[key] = best_times[key]
	cfg.set_value("game", "best_times", times)
	cfg.set_value("game", "total_runs", total_runs)
	cfg.set_value("settings", "master_volume", setting_master_volume)
	cfg.set_value("settings", "sfx_volume", setting_sfx_volume)
	cfg.set_value("settings", "music_volume", setting_music_volume)
	cfg.set_value("loadout", "subweapon", equipped_subweapon)
	cfg.set_value("loadout", "skin_index", skin_index)
	var owned: Dictionary = {}
	for key in skin_owned.keys():
		owned[int(key)] = bool(skin_owned[key])
	cfg.set_value("loadout", "skin_owned", owned)
	# Achievements (v0.65) — flat dict mapping id → bool.
	var ach: Dictionary = {}
	for key in achievements.keys():
		ach[key] = bool(achievements[key])
	cfg.set_value("achievements", "unlocked", ach)
	cfg.set_value("game", "walls_broken", walls_broken)
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
	architect_cleared = cfg.get_value("game", "architect_cleared", false)
	labyrinth_cleared = cfg.get_value("game", "labyrinth_cleared", false)
	circuit_cleared = cfg.get_value("game", "circuit_cleared", false)
	faultline_cleared = cfg.get_value("game", "faultline_cleared", false)
	var loaded_daily: Dictionary = cfg.get_value("game", "daily_best_scores", {})
	daily_best_scores.clear()
	for key in loaded_daily.keys():
		daily_best_scores[String(key)] = int(loaded_daily[key])
	var loaded_scores: Dictionary = cfg.get_value("game", "best_scores", {})
	best_scores.clear()
	for key in loaded_scores.keys():
		best_scores[String(key)] = int(loaded_scores[key])
	var loaded_times: Dictionary = cfg.get_value("game", "best_times", {})
	best_times.clear()
	for key in loaded_times.keys():
		best_times[String(key)] = float(loaded_times[key])
	total_runs = int(cfg.get_value("game", "total_runs", 0))
	setting_master_volume = float(cfg.get_value("settings", "master_volume", 0.7))
	setting_sfx_volume    = float(cfg.get_value("settings", "sfx_volume", 1.0))
	setting_music_volume  = float(cfg.get_value("settings", "music_volume", 0.7))
	equipped_subweapon = String(cfg.get_value("loadout", "subweapon", SUBWEAPON_MISSILE))
	skin_index = int(cfg.get_value("loadout", "skin_index", 0))
	var loaded_owned: Dictionary = cfg.get_value("loadout", "skin_owned", {})
	skin_owned.clear()
	for key in loaded_owned.keys():
		skin_owned[int(key)] = bool(loaded_owned[key])
	var loaded_ach: Dictionary = cfg.get_value("achievements", "unlocked", {})
	achievements.clear()
	for key in loaded_ach.keys():
		achievements[String(key)] = bool(loaded_ach[key])
	walls_broken = int(cfg.get_value("game", "walls_broken", 0))
	apply_audio_settings()


## Pushes the three volume settings into AudioServer + the per-bus
## volume_scale fields on Sfx and Music. Called from load_from_file and
## from the pause menu after slider changes.
func apply_audio_settings() -> void:
	if test_mode:
		return
	var master_db: float = -80.0 if setting_master_volume <= 0.001 else linear_to_db(setting_master_volume)
	AudioServer.set_bus_volume_db(0, master_db)
	Sfx.volume_scale = setting_sfx_volume
	Music.volume_scale = setting_music_volume
	Music.apply_volume()

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
	"stage_6":   "res://scenes/levels/stage_6.tscn",
	"stage_7":   "res://scenes/levels/stage_7.tscn",
	"stage_8":   "res://scenes/levels/stage_8.tscn",
	"stage_9":   "res://scenes/levels/stage_9.tscn",
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


## Resolves a logical key to a scene path and triggers a deferred change.
## No-op for unknown keys (warning only) so a typo doesn't crash the game.
func goto_level(key: String) -> void:
	if not LEVEL_PATHS.has(key):
		push_warning("goto_level: unknown key '%s'" % key)
		return
	get_tree().change_scene_to_file(LEVEL_PATHS[key])


## Wipes per-run state. Called by stage scripts on respawn / by the title
## screen on restart. NOTE: coins, upgrades, and game_cleared persist
## across runs (they're saved to disk) — only per-session counters reset.
func reset_run() -> void:
	session_time = 0.0
	session_hits = 0
	session_kills = 0
	session_coins = 0
	last_clear_coin_bonus = 0
	total_runs += 1
	buffs.clear()
	check_passive_achievements()

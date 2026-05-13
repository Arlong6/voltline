## Voltline — "GRID-0" Architect boss for Stage 6.
##
## Inherits Boss directly. The post-rush nightmare encounter:
##   • 80 HP across three phases
##   • Phase 1 (>66%): tracked single bullet, 0.4s cadence
##   • Phase 2 (33-66%): adds a 5-bullet ±20° spread + summons one drone
##     on every other hop apex (cap 2 alive)
##   • Phase 3 (<33%): 11-bullet ±36° spread + 4-direction radial burst
##     on hop, summons one kamikaze instead of a drone
##
## Larger silhouette (64×64) with concentric "AI core" rings + a diamond
## scanning eye that shifts color per phase.
class_name GridZero
extends "res://scripts/boss.gd"

const _GZ_SIZE: Vector2 = Vector2(64.0, 64.0)
const _GZ_COLOR_BODY: Color = Color("#0E0814")
const _GZ_COLOR_BODY_HIT: Color = Color("#FFE0E0")
const _GZ_COLOR_OUTER: Color = Color("#3A1A30")
const _GZ_COLOR_INNER: Color = Color("#5A2A48")
const _GZ_COLOR_EYE_P1: Color = Color("#FFD24A")
const _GZ_COLOR_EYE_P2: Color = Color("#FF8030")
const _GZ_COLOR_EYE_P3: Color = Color("#FF3030")
const _GZ_COLOR_SIGIL: Color = Color("#A030C0")

const _GZ_SPREAD_DEG_P2: float = 20.0
const _GZ_SPREAD_DEG_P3: float = 36.0

const _GZ_PHASE_2_HP_PCT: float = 0.66
const _GZ_PHASE_3_HP_PCT: float = 0.33

const _GZ_RADIAL_DIRS: Array[Vector2] = [
	Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
]

const _DRONE_SCENE: PackedScene = preload("res://scenes/drone.tscn")
const _KAMIKAZE_SCENE: PackedScene = preload("res://scenes/kamikaze.tscn")

# Cap on how many minions GRID-0 can have alive at once. Avoids
# screen-clog if the player stalls for a long time mid-phase.
const _MAX_MINIONS: int = 2

# Tick counter for phase-2/3 minion summon cadence (every other hop).
var _hop_summon_toggle: bool = false

var _last_hop_timer: float = 0.0


func _ready() -> void:
	boss_name = "GRID-0"
	max_hp = 80
	shoot_interval = 0.4
	bullet_speed = 280.0
	bullet_initial_delay = 1.6
	hop_interval = 1.5
	hop_velocity = -300.0
	hp = max_hp
	_shoot_timer = bullet_initial_delay
	_hop_timer = hop_interval * 0.5
	_last_hop_timer = _hop_timer


func _physics_process(delta: float) -> void:
	if Game.test_mode or not is_alive:
		return
	var prev_hop: float = _last_hop_timer
	super._physics_process(delta)
	# Detect a hop reset (timer just got bigger) — fire phase-3 radial
	# burst + alternating minion summon.
	if _hop_timer > prev_hop:
		_on_hop_started()
	_last_hop_timer = _hop_timer


func _on_hop_started() -> void:
	var hp_pct: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	# Phase 3: every hop fires a 4-direction radial burst.
	if hp_pct < _GZ_PHASE_3_HP_PCT:
		for dir in _GZ_RADIAL_DIRS:
			_spawn_enemy_bullet(dir)
	# Phase 2+: every OTHER hop summons a minion (drone in P2, kamikaze in P3).
	if hp_pct < _GZ_PHASE_2_HP_PCT:
		_hop_summon_toggle = not _hop_summon_toggle
		if _hop_summon_toggle and _live_minion_count() < _MAX_MINIONS:
			_summon_minion(hp_pct < _GZ_PHASE_3_HP_PCT)


func _live_minion_count() -> int:
	var count: int = 0
	var parent: Node = get_parent()
	if parent == null:
		return 0
	for child in parent.get_children():
		if child is Drone or child is Kamikaze:
			if child.is_alive:
				count += 1
	return count


func _summon_minion(use_kamikaze: bool) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	if use_kamikaze:
		var kami: Kamikaze = _KAMIKAZE_SCENE.instantiate() as Kamikaze
		kami.global_position = global_position + Vector2(-12.0, -16.0)
		kami.hover_y = global_position.y - 60.0
		kami.patrol_min_x = global_position.x - 80.0
		kami.patrol_max_x = global_position.x + 80.0
		parent.add_child(kami)
	else:
		var drone: Drone = _DRONE_SCENE.instantiate() as Drone
		drone.global_position = global_position + Vector2(-12.0, -40.0)
		drone.hover_y = global_position.y - 80.0
		drone.patrol_min_x = global_position.x - 100.0
		drone.patrol_max_x = global_position.x + 100.0
		drone.max_hp = 3
		drone.walk_speed = 70.0
		parent.add_child(drone)


# v0.62 — phase-aware RANDOMIZED pattern picker. Each attack tick picks
# from a per-phase pool of distinct patterns (no longer fixed) and
# randomises the wait time so cadence breathes.
func _fire_at_player() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var direction: Vector2 = (player.global_position - global_position).normalized()
	var hp_pct: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0

	var pool: PackedStringArray
	if hp_pct < _GZ_PHASE_3_HP_PCT:
		# All 4 patterns + biased toward heavier ones.
		pool = PackedStringArray([
			"spread", "radial", "volley", "spread", "radial", "aimed",
		])
	elif hp_pct < _GZ_PHASE_2_HP_PCT:
		# Spread + volley + occasional single shot.
		pool = PackedStringArray(["spread", "volley", "aimed", "spread"])
	else:
		# Phase 1: still mostly aimed but throw in occasional volley to
		# stop the player from camping a single line.
		pool = PackedStringArray(["aimed", "aimed", "aimed", "volley"])

	var pattern: String = pool[randi() % pool.size()]
	match pattern:
		"aimed":  _attack_aimed_single(direction)
		"spread": _attack_spread_n(direction, 5, _GZ_SPREAD_DEG_P2)
		"radial": _attack_radial_8()
		"volley": _attack_volley_3(direction)

	# Cadence jitter — 0.3s..0.7s overrides the fixed shoot_interval set
	# by Boss._physics_process. Without this the player learns the rhythm
	# and trivialises positioning.
	_shoot_timer = randf_range(0.3, 0.7)

	if not Game.test_mode:
		Sfx.play("shoot_enemy")


# attack pattern helpers live in Boss base (_attack_*) — shared across
# all bosses since v0.63.


func _draw() -> void:
	var body_color: Color = _GZ_COLOR_BODY_HIT if _hit_flash_timer > 0.0 else _GZ_COLOR_BODY
	# Outer-most ring frame.
	draw_rect(Rect2(-_GZ_SIZE.x * 0.5, -_GZ_SIZE.y * 0.5, _GZ_SIZE.x, _GZ_SIZE.y), _GZ_COLOR_OUTER)
	# Mid ring.
	draw_rect(Rect2(-_GZ_SIZE.x * 0.4, -_GZ_SIZE.y * 0.4, _GZ_SIZE.x * 0.8, _GZ_SIZE.y * 0.8), _GZ_COLOR_INNER)
	# Core body.
	draw_rect(Rect2(-_GZ_SIZE.x * 0.3, -_GZ_SIZE.y * 0.3, _GZ_SIZE.x * 0.6, _GZ_SIZE.y * 0.6), body_color)
	# Diamond eye — color reads the phase.
	var hp_pct: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	var eye_color: Color = _GZ_COLOR_EYE_P1
	if hp_pct < _GZ_PHASE_3_HP_PCT:
		eye_color = _GZ_COLOR_EYE_P3
	elif hp_pct < _GZ_PHASE_2_HP_PCT:
		eye_color = _GZ_COLOR_EYE_P2
	var eye_pts: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -10.0), Vector2(10.0, 0.0), Vector2(0.0, 10.0), Vector2(-10.0, 0.0),
	])
	draw_polygon(eye_pts, PackedColorArray([eye_color]))
	# Sigil cross beneath the eye.
	draw_rect(Rect2(-1.0, 4.0, 2.0, 18.0), _GZ_COLOR_SIGIL)
	draw_rect(Rect2(-9.0, 12.0, 18.0, 2.0), _GZ_COLOR_SIGIL)

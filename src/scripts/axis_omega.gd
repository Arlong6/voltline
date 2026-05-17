## Voltline — AXIS-Ω final boss for Stage 10 // TERMINUS.
##
## Four-phase end boss that remixes R-08 hops, VEIN-K teleports, GRID-0
## summons, and a final invincible-shell eye window.
class_name AxisOmega
extends "res://scripts/boss.gd"

## Teleport points injected by Stage 10 at spawn time.
@export var teleport_anchors: Array[Vector2] = []

const MAX_HP: int = 160
const BOSS_LABEL: String = "AXIS-Ω"
const BODY_RADIUS: float = 26.0
const OUTER_RING_RADIUS: float = 36.0
const OUTER_RING_DOTS: int = 4
const OUTER_RING_DOT_RADIUS: float = 3.0
const OCTAGON_POINTS: int = 8
const EYE_RADIUS: float = 7.0
const EYE_RING_RADIUS: float = 12.0
const EYE_BAR_SIZE: Vector2 = Vector2(18.0, 5.0)
const RING_ROTATION_SPEED: float = 0.5
const GHOST_FADE_DURATION: float = 0.4
const GHOST_ALPHA_START: float = 0.55
const GHOST_ALPHA_END: float = 0.0
const COLLISION_DISABLED_LAYER: int = 0
const DEFAULT_COLLISION_LAYER: int = 4
const NO_ANCHOR_INDEX: int = -1
const FIRST_ANCHOR_INDEX: int = 0
const ANCHOR_STEP: int = 1

const PHASE_1_HP_MIN: float = 0.75
const PHASE_2_HP_MAX: float = 0.75
const PHASE_2_HP_MIN: float = 0.50
const PHASE_3_HP_MAX: float = 0.50
const PHASE_3_HP_MIN: float = 0.25
const PHASE_4_HP_MAX: float = 0.25

const PHASE_1_HOP_INTERVAL: float = 1.8
const PHASE_1_HOP_VELOCITY: float = -270.0
const PHASE_1_SHOOT_INTERVAL: float = 0.55
const PHASE_1_BULLET_SPEED: float = 220.0
const PHASE_2_TELEPORT_INTERVAL: float = 2.0
const PHASE_2_SHOOT_INTERVAL: float = 0.5
const PHASE_3_TELEPORT_INTERVAL: float = 1.6
const PHASE_3_SHOOT_INTERVAL: float = 0.45
const PHASE_3_SUMMON_INTERVAL: float = 3.0
const PHASE_3_MINION_CAP: int = 2
const PHASE_3_SWEEP_INTERVAL: float = 4.0
const SWEEP_LASER_SIZE: Vector2 = Vector2(180.0, 8.0)
const SWEEP_LASER_DURATION: float = 0.6
const BOSS_FEET_OFFSET: Vector2 = Vector2(0.0, 26.0)
const BREAKDOWN_ATTACK_INTERVAL: float = 2.5
const BREAKDOWN_VULNERABLE_DURATION: float = 1.5
const SPREAD_3_COUNT: int = 3
const SPREAD_5_COUNT: int = 5
const SPREAD_3_DEG: float = 15.0
const SPREAD_5_DEG: float = 28.0
const VOLLEY_COUNT: int = 3
const RADIAL_8_COUNT: int = 8
const DEATH_PARTICLE_COUNT: int = 40
const DEATH_PARTICLE_DURATION: float = 1.4
const DEATH_PARTICLE_SPEED_MAX: float = 220.0
const DEATH_HIT_STOP_DURATION: float = 0.35
const DEATH_HIT_STOP_SCALE: float = 0.0
const DEATH_SHAKE_STRENGTH: float = 10.0
const INITIAL_SHOOT_TIMER: float = 0.25

const COLOR_BODY: Color = Color("#050505")
const COLOR_BODY_HIT: Color = Color("#FFE0E0")
const COLOR_GOLD: Color = Color("#FFD24A")
const COLOR_EYE_P1: Color = Color("#F0F0F0")
const COLOR_EYE_P2: Color = Color("#5C9CFF")
const COLOR_EYE_P3: Color = Color("#FFA040")
const COLOR_EYE_P4: Color = Color("#FF3030")
const COLOR_CLOSED_EYE: Color = Color("#000000")
const COLOR_GHOST: Color = Color("#FFD24A")

const LASER_SCENE: PackedScene = preload("res://scenes/laser_beam.tscn")
const DRONE_SCENE: PackedScene = preload("res://scenes/drone.tscn")
const KAMIKAZE_SCENE: PackedScene = preload("res://scenes/kamikaze.tscn")

@export var _ring_angle: float = 0.0

var _teleport_timer: float = PHASE_2_TELEPORT_INTERVAL
var _summon_timer: float = PHASE_3_SUMMON_INTERVAL
var _sweep_timer: float = PHASE_3_SWEEP_INTERVAL
var _breakdown_attack_timer: float = BREAKDOWN_ATTACK_INTERVAL
var _anchor_index: int = NO_ANCHOR_INDEX
var _saved_collision_layer: int = DEFAULT_COLLISION_LAYER
var _uses_teleport: bool = false
var _vulnerable_until: float = -1.0


func _ready() -> void:
	boss_name = BOSS_LABEL
	max_hp = MAX_HP
	hp = max_hp
	bullet_speed = PHASE_1_BULLET_SPEED
	hop_interval = PHASE_1_HOP_INTERVAL
	hop_velocity = PHASE_1_HOP_VELOCITY
	shoot_interval = PHASE_1_SHOOT_INTERVAL
	_shoot_timer = INITIAL_SHOOT_TIMER
	_hop_timer = hop_interval * 0.5
	_anchor_index = _nearest_anchor_index()
	_saved_collision_layer = collision_layer


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	tick_phase_state()
	_ring_angle += delta * RING_ROTATION_SPEED
	if _is_phase_1():
		super._physics_process(delta)
		return
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	if _is_phase_2():
		tick_teleport(delta)
		_tick_shoot(delta)
	elif _is_phase_3():
		tick_teleport(delta)
		tick_summon(delta)
		tick_sweep_laser(delta)
		_tick_shoot(delta)
	else:
		tick_breakdown(delta)
	velocity = Vector2.ZERO
	queue_redraw()


## Refreshes phase booleans and cadence from the current HP threshold.
func tick_phase_state() -> void:
	_uses_teleport = _is_phase_2() or _is_phase_3()
	if _is_phase_2():
		shoot_interval = PHASE_2_SHOOT_INTERVAL
		_teleport_timer = minf(_teleport_timer, PHASE_2_TELEPORT_INTERVAL)
	elif _is_phase_3():
		shoot_interval = PHASE_3_SHOOT_INTERVAL
		_teleport_timer = minf(_teleport_timer, PHASE_3_TELEPORT_INTERVAL)
	elif _is_phase_1():
		shoot_interval = PHASE_1_SHOOT_INTERVAL


## Advances the AXIS-Ω teleport cadence and fires radial_8 on appear.
func tick_teleport(delta: float) -> void:
	tick_phase_state()
	if not _uses_teleport or teleport_anchors.is_empty():
		return
	_teleport_timer -= delta
	if _teleport_timer > 0.0:
		return
	_perform_teleport()
	_teleport_timer = PHASE_3_TELEPORT_INTERVAL if _is_phase_3() else PHASE_2_TELEPORT_INTERVAL


## Advances phase-3 summon cadence, respecting the simultaneous minion cap.
func tick_summon(delta: float) -> void:
	if not _is_phase_3():
		return
	_summon_timer -= delta
	if _summon_timer > 0.0:
		return
	_summon_timer = PHASE_3_SUMMON_INTERVAL
	if _minion_count() >= PHASE_3_MINION_CAP:
		return
	_spawn_minion()


## Advances phase-3 ground sweep laser cadence.
func tick_sweep_laser(delta: float) -> void:
	if not _is_phase_3():
		return
	_sweep_timer -= delta
	if _sweep_timer > 0.0:
		return
	_sweep_timer = PHASE_3_SWEEP_INTERVAL
	_spawn_sweep_laser()


## Advances the phase-4 attack rhythm and opens the eye window after each shot.
func tick_breakdown(delta: float) -> void:
	if not _is_phase_4():
		return
	_breakdown_attack_timer -= delta
	if _breakdown_attack_timer > 0.0:
		return
	var direction: Vector2 = _aim_direction()
	if randi() % 2 == 0:
		_attack_radial_8()
	else:
		_attack_spread_n(direction, SPREAD_5_COUNT, SPREAD_5_DEG)
	_breakdown_attack_timer = BREAKDOWN_ATTACK_INTERVAL
	_vulnerable_until = _now_seconds() + BREAKDOWN_VULNERABLE_DURATION
	if not Game.test_mode:
		Sfx.play("shoot_enemy")


func take_damage(amount: int, from_pos: Vector2 = Vector2.INF) -> void:
	if _is_phase_4() and _vulnerable_until <= _now_seconds():
		return
	super.take_damage(amount, from_pos)


func die() -> void:
	if not is_alive:
		return
	super.die()
	var parent: Node = get_parent()
	if parent != null and not Game.test_mode:
		var burst: ParticleBurst = ParticleBurst.new()
		burst.count = DEATH_PARTICLE_COUNT
		burst.duration = DEATH_PARTICLE_DURATION
		burst.speed_max = DEATH_PARTICLE_SPEED_MAX
		burst.color = COLOR_GOLD
		burst.global_position = global_position
		parent.add_child(burst)
	Game.hit_stop(DEATH_HIT_STOP_DURATION, DEATH_HIT_STOP_SCALE)
	Game.request_shake(DEATH_SHAKE_STRENGTH)


func _tick_shoot(delta: float) -> void:
	_shoot_timer -= delta
	if _shoot_timer > 0.0:
		return
	_shoot_timer = shoot_interval
	_fire_at_player()


func _fire_at_player() -> void:
	var direction: Vector2 = _aim_direction()
	var pool: PackedStringArray
	if _is_phase_1():
		pool = PackedStringArray(["aimed", "aimed", "volley", "spread3"])
	elif _is_phase_2():
		pool = PackedStringArray(["spread5", "volley", "aimed"])
	elif _is_phase_3():
		pool = PackedStringArray(["spread5", "radial8", "volley"])
	else:
		pool = PackedStringArray(["radial8", "spread5"])
	var pattern: String = pool[randi() % pool.size()]
	match pattern:
		"aimed":
			_attack_aimed_single(direction)
		"volley":
			_attack_volley_3(direction)
		"spread3":
			_attack_spread_n(direction, SPREAD_3_COUNT, SPREAD_3_DEG)
		"spread5":
			_attack_spread_n(direction, SPREAD_5_COUNT, SPREAD_5_DEG)
		"radial8":
			_attack_radial_8()
	if not Game.test_mode:
		Sfx.play("shoot_enemy")


func _aim_direction() -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return Vector2.LEFT
	return (player.global_position - global_position).normalized()


func _perform_teleport() -> void:
	var previous_position: Vector2 = global_position
	_spawn_ghost(previous_position)
	if _anchor_index == NO_ANCHOR_INDEX:
		_anchor_index = FIRST_ANCHOR_INDEX
	else:
		_anchor_index = (_anchor_index + ANCHOR_STEP) % teleport_anchors.size()
	collision_layer = COLLISION_DISABLED_LAYER
	global_position = teleport_anchors[_anchor_index]
	collision_layer = _saved_collision_layer
	Sfx.play("teleport")
	_attack_radial_8()


func _spawn_ghost(ghost_position: Vector2) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var ghost: AxisOmegaGhost = AxisOmegaGhost.new()
	ghost.global_position = ghost_position
	parent.add_child(ghost)


func _spawn_minion() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var minion: Enemy
	if randi() % 2 == 0:
		minion = DRONE_SCENE.instantiate() as Drone
		(minion as Drone).hover_y = global_position.y
	else:
		minion = KAMIKAZE_SCENE.instantiate() as Kamikaze
		(minion as Kamikaze).hover_y = global_position.y
	minion.global_position = global_position + Vector2(randf_range(-18.0, 18.0), -20.0)
	minion.patrol_min_x = global_position.x - OUTER_RING_RADIUS
	minion.patrol_max_x = global_position.x + OUTER_RING_RADIUS
	parent.add_child(minion)


func _spawn_sweep_laser() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var laser: LaserBeam = LASER_SCENE.instantiate() as LaserBeam
	laser.global_position = global_position + BOSS_FEET_OFFSET
	laser.size = SWEEP_LASER_SIZE
	laser.period = SWEEP_LASER_DURATION
	laser.on_duty = 1.0
	parent.add_child(laser)
	var timer: SceneTreeTimer = get_tree().create_timer(SWEEP_LASER_DURATION)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(laser):
			laser.queue_free()
	)


func _minion_count() -> int:
	var parent: Node = get_parent()
	if parent == null:
		return 0
	var count: int = 0
	for child in parent.get_children():
		if child is Drone or child is Kamikaze:
			count += 1
	return count


func _hp_pct() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)


func _is_phase_1() -> bool:
	return _hp_pct() > PHASE_1_HP_MIN


func _is_phase_2() -> bool:
	var pct: float = _hp_pct()
	return pct <= PHASE_2_HP_MAX and pct >= PHASE_2_HP_MIN


func _is_phase_3() -> bool:
	var pct: float = _hp_pct()
	return pct < PHASE_3_HP_MAX and pct >= PHASE_3_HP_MIN


func _is_phase_4() -> bool:
	return _hp_pct() < PHASE_4_HP_MAX


func _nearest_anchor_index() -> int:
	if teleport_anchors.is_empty():
		return NO_ANCHOR_INDEX
	var best_idx: int = FIRST_ANCHOR_INDEX
	var best_dist: float = global_position.distance_squared_to(teleport_anchors[FIRST_ANCHOR_INDEX])
	for i in teleport_anchors.size():
		var dist: float = global_position.distance_squared_to(teleport_anchors[i])
		if dist < best_dist:
			best_idx = i
			best_dist = dist
	return best_idx


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) * 0.001


func _draw() -> void:
	var body_color: Color = COLOR_BODY_HIT if _hit_flash_timer > 0.0 else COLOR_BODY
	var pts: PackedVector2Array = PackedVector2Array()
	for i in OCTAGON_POINTS:
		var angle: float = TAU * float(i) / float(OCTAGON_POINTS)
		pts.append(Vector2(cos(angle), sin(angle)) * BODY_RADIUS)
	draw_polygon(pts, PackedColorArray([body_color]))
	draw_arc(Vector2.ZERO, OUTER_RING_RADIUS, _ring_angle, _ring_angle + TAU, 32, COLOR_GOLD, 2.0)
	for i in OUTER_RING_DOTS:
		var dot_angle: float = _ring_angle + TAU * float(i) / float(OUTER_RING_DOTS)
		draw_circle(Vector2(cos(dot_angle), sin(dot_angle)) * OUTER_RING_RADIUS, OUTER_RING_DOT_RADIUS, COLOR_GOLD)
	if _is_phase_4():
		if _vulnerable_until > _now_seconds():
			draw_circle(Vector2.ZERO, EYE_RADIUS, COLOR_EYE_P4)
			var pulse: float = (sin(_now_seconds() * 40.0) + 1.0) * 0.5
			var ring_color: Color = COLOR_EYE_P4
			ring_color.a = 0.35 + pulse * 0.45
			draw_arc(Vector2.ZERO, EYE_RING_RADIUS, 0.0, TAU, 24, ring_color, 2.0)
		else:
			draw_rect(Rect2(-EYE_BAR_SIZE * 0.5, EYE_BAR_SIZE), COLOR_CLOSED_EYE)
		return
	var eye_color: Color = COLOR_EYE_P1
	if _is_phase_3():
		eye_color = COLOR_EYE_P3
	elif _is_phase_2():
		eye_color = COLOR_EYE_P2
	draw_circle(Vector2.ZERO, EYE_RADIUS, eye_color)


class AxisOmegaGhost:
	extends Node2D

	const BODY_RADIUS: float = 26.0
	const POINT_COUNT: int = 8
	const FADE_DURATION: float = 0.4
	const ALPHA_START: float = 0.55
	const ALPHA_END: float = 0.0
	const COLOR: Color = Color("#FFD24A")

	var _age: float = 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= FADE_DURATION:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t: float = clampf(_age / FADE_DURATION, 0.0, 1.0)
		var c: Color = COLOR
		c.a = lerpf(ALPHA_START, ALPHA_END, t)
		var pts: PackedVector2Array = PackedVector2Array()
		for i in POINT_COUNT:
			var angle: float = TAU * float(i) / float(POINT_COUNT)
			pts.append(Vector2(cos(angle), sin(angle)) * BODY_RADIUS)
		draw_polygon(pts, PackedColorArray([c]))

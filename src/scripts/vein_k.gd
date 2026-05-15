## Voltline — VEIN-K boss for Stage 9 // FAULTLINE.
##
## Teleporting diamond boss that replaces the inherited hop cadence with
## its own anchor-warp timer and phase-specific attack payloads.
class_name VeinK
extends "res://scripts/boss.gd"

## Teleport points injected by Stage 9 at spawn time.
@export var teleport_anchors: Array[Vector2] = []

const MAX_HP: int = 100
const BOSS_LABEL: String = "VEIN-K"
const BODY_RADIUS: float = 28.0
const HALF_BODY_RADIUS: float = 14.0
const GHOST_FADE_DURATION: float = 0.4
const PHASE_1_INTERVAL: float = 2.5
const PHASE_2_INTERVAL: float = 1.8
const PHASE_3_INTERVAL: float = 1.2
const PHASE_2_HP_PCT: float = 0.66
const PHASE_3_HP_PCT: float = 0.33
const BULLET_SPEED: float = 190.0
const INITIAL_TIMER_SCALE: float = 1.0
const COLLISION_DISABLED_LAYER: int = 0
const DEFAULT_COLLISION_LAYER: int = 4
const FIRST_ANCHOR_INDEX: int = 0
const ANCHOR_STEP: int = 1
const NO_ANCHOR_INDEX: int = -1
const EYE_WIDTH: float = 8.0
const EYE_HEIGHT: float = 5.0
const FISSURE_LINE_WIDTH: float = 2.0

const COLOR_BODY: Color = Color("#12051E")
const COLOR_BODY_HIT: Color = Color("#FFE0E0")
const COLOR_EDGE: Color = Color("#4A1A70")
const COLOR_FISSURE: Color = Color("#B040FF")
const COLOR_EYE_P1: Color = Color("#B65CFF")
const COLOR_EYE_P2: Color = Color("#D040FF")
const COLOR_EYE_P3: Color = Color("#FF3048")
const COLOR_GHOST: Color = Color("#A040FF")

const FISSURE_MINE_SCENE: GDScript = preload("res://scripts/fissure_mine.gd")

var _teleport_timer: float = PHASE_1_INTERVAL
var _anchor_index: int = NO_ANCHOR_INDEX
var _saved_collision_layer: int = DEFAULT_COLLISION_LAYER


func _ready() -> void:
	boss_name = BOSS_LABEL
	max_hp = MAX_HP
	bullet_speed = BULLET_SPEED
	hp = max_hp
	_teleport_timer = _current_interval() * INITIAL_TIMER_SCALE
	_anchor_index = _nearest_anchor_index()
	_saved_collision_layer = collision_layer


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	tick_teleport(delta)
	velocity = Vector2.ZERO
	queue_redraw()


## Advances VEIN-K's custom teleport cadence without invoking Boss hops.
func tick_teleport(delta: float) -> void:
	if teleport_anchors.is_empty():
		return
	_teleport_timer = minf(_teleport_timer, _current_interval())
	_teleport_timer -= delta
	if _teleport_timer > 0.0:
		return
	_perform_teleport()
	_teleport_timer = _current_interval()


func _perform_teleport() -> void:
	var previous_position: Vector2 = global_position
	_spawn_ghost(previous_position)
	if _anchor_index == NO_ANCHOR_INDEX:
		_anchor_index = FIRST_ANCHOR_INDEX
	else:
		_anchor_index = (_anchor_index + ANCHOR_STEP) % teleport_anchors.size()

	if _is_phase_3():
		_spawn_fissure_mine(previous_position)

	collision_layer = COLLISION_DISABLED_LAYER
	global_position = teleport_anchors[_anchor_index]
	collision_layer = _saved_collision_layer
	_attack_on_appear()


func _attack_on_appear() -> void:
	if _is_phase_3():
		_attack_radial_8()
	elif _is_phase_2():
		_attack_radial_8()
	else:
		_attack_volley_3(_aim_direction())


func _aim_direction() -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return Vector2.LEFT
	return (player.global_position - global_position).normalized()


func _current_interval() -> float:
	if _is_phase_3():
		return PHASE_3_INTERVAL
	if _is_phase_2():
		return PHASE_2_INTERVAL
	return PHASE_1_INTERVAL


func _hp_pct() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)


func _is_phase_2() -> bool:
	var pct: float = _hp_pct()
	return pct <= PHASE_2_HP_PCT and pct >= PHASE_3_HP_PCT


func _is_phase_3() -> bool:
	return _hp_pct() < PHASE_3_HP_PCT


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


func _spawn_fissure_mine(mine_position: Vector2) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var mine: FissureMine = FISSURE_MINE_SCENE.new() as FissureMine
	mine.global_position = mine_position
	parent.add_child(mine)


func _spawn_ghost(ghost_position: Vector2) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var ghost: VeinKGhost = VeinKGhost.new()
	ghost.global_position = ghost_position
	parent.add_child(ghost)


func _draw() -> void:
	var body_color: Color = COLOR_BODY_HIT if _hit_flash_timer > 0.0 else COLOR_BODY
	var diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -HALF_BODY_RADIUS),
		Vector2(HALF_BODY_RADIUS, 0.0),
		Vector2(0.0, HALF_BODY_RADIUS),
		Vector2(-HALF_BODY_RADIUS, 0.0),
	])
	draw_polygon(diamond, PackedColorArray([COLOR_EDGE]))
	var inner: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -HALF_BODY_RADIUS + 4.0),
		Vector2(HALF_BODY_RADIUS - 4.0, 0.0),
		Vector2(0.0, HALF_BODY_RADIUS - 4.0),
		Vector2(-HALF_BODY_RADIUS + 4.0, 0.0),
	])
	draw_polygon(inner, PackedColorArray([body_color]))
	draw_polyline(PackedVector2Array([Vector2(-18.0, -8.0), Vector2(-28.0, -18.0), Vector2(-36.0, -18.0)]), COLOR_FISSURE, FISSURE_LINE_WIDTH)
	draw_polyline(PackedVector2Array([Vector2(16.0, -2.0), Vector2(28.0, -8.0), Vector2(36.0, -4.0)]), COLOR_FISSURE, FISSURE_LINE_WIDTH)
	draw_polyline(PackedVector2Array([Vector2(-4.0, 14.0), Vector2(-10.0, 28.0), Vector2(-22.0, 34.0)]), COLOR_FISSURE, FISSURE_LINE_WIDTH)
	var eye_color: Color = COLOR_EYE_P1
	if _is_phase_3():
		eye_color = COLOR_EYE_P3
	elif _is_phase_2():
		eye_color = COLOR_EYE_P2
	draw_rect(Rect2(-EYE_WIDTH * 0.5, -EYE_HEIGHT * 0.5, EYE_WIDTH, EYE_HEIGHT), eye_color)


class VeinKGhost:
	extends Node2D

	const FADE_DURATION: float = 0.4
	const BODY_RADIUS: float = 14.0
	const COLOR: Color = Color("#A040FF")
	const ALPHA_START: float = 0.55
	const ALPHA_END: float = 0.0

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
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(0.0, -BODY_RADIUS),
			Vector2(BODY_RADIUS, 0.0),
			Vector2(0.0, BODY_RADIUS),
			Vector2(-BODY_RADIUS, 0.0),
		])
		draw_polygon(pts, PackedColorArray([c]))

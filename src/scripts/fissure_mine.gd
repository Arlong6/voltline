## Voltline — VEIN-K fissure mine.
##
## Short-lived countdown marker used by Stage 9's boss. After its fuse it
## explodes into four cardinal EnemyBullet shots.
class_name FissureMine
extends Node2D

## Seconds before the mine bursts.
@export var fuse_duration: float = FUSE_DURATION

## EnemyBullet velocity magnitude (px/s).
@export var bullet_speed: float = BULLET_SPEED

const FUSE_DURATION: float = 0.6
const BULLET_SPEED: float = 170.0
const MARKER_RADIUS: float = 7.0
const MARKER_INNER_RADIUS: float = 3.0
const BLINK_SPEED: float = 24.0
const BLINK_ALPHA_MIN: float = 0.25
const BLINK_ALPHA_MAX: float = 0.95
const HALF: float = 0.5

const COLOR_MARKER: Color = Color("#9A40FF")
const COLOR_CORE: Color = Color("#F040FF")
const BULLET_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT,
]
const BULLET_SCENE: PackedScene = preload("res://scenes/enemy_bullet.tscn")

var _timer: float = FUSE_DURATION
var _elapsed: float = 0.0
var _exploded: bool = false


func _ready() -> void:
	_timer = fuse_duration


func _process(delta: float) -> void:
	tick(delta)


## Advances the fuse by `delta` seconds and explodes when it reaches zero.
func tick(delta: float) -> void:
	if _exploded:
		return
	_timer -= delta
	_elapsed += delta
	if _timer <= 0.0:
		_explode()
	queue_redraw()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	Sfx.play("fissure_explode")
	_attack_radial_4()
	queue_free()


func _attack_radial_4() -> void:
	var parent: Node = get_parent()
	if parent != null:
		for direction in BULLET_DIRECTIONS:
			var bullet: EnemyBullet = BULLET_SCENE.instantiate() as EnemyBullet
			bullet.velocity = direction * bullet_speed
			bullet.global_position = global_position
			parent.add_child(bullet)


func _draw() -> void:
	var pulse: float = (sin(_elapsed * BLINK_SPEED) + 1.0) * HALF
	var marker: Color = COLOR_MARKER
	marker.a = lerpf(BLINK_ALPHA_MIN, BLINK_ALPHA_MAX, pulse)
	draw_circle(Vector2.ZERO, MARKER_RADIUS, marker)
	draw_circle(Vector2.ZERO, MARKER_INNER_RADIUS, COLOR_CORE)

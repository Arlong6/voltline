## Voltline — timed power-up pickup (v0.64).
##
## Area2D drop that bobs in place; on player contact activates one of
## four timed buffs via Game.activate_buff() and queue_free's. Dropped
## by Enemy.die at a small probability (5% from grunts, 15% from bosses).
##
## Visual is keyed by `buff_type` so the player learns the color
## association — yellow = damage up, cyan = invincibility, magenta =
## rapid fire, gold-orange = coin magnet.
class_name PowerUp
extends Area2D

const _COLORS: Dictionary = {
	"invincible": Color("#7AC8FF"),
	"damage_up":  Color("#FFD24A"),
	"rapid_fire": Color("#FF60D0"),
	"magnet":     Color("#FF9030"),
}

const _COLORS_DIM: Dictionary = {
	"invincible": Color("#2A6890"),
	"damage_up":  Color("#A07020"),
	"rapid_fire": Color("#80306A"),
	"magnet":     Color("#804818"),
}

## Which buff this pickup grants. Set by the enemy/boss drop logic
## before adding to the tree.
@export var buff_type: String = "invincible"

const _SIZE: Vector2 = Vector2(10.0, 10.0)

var _t: float = 0.0
var _spawn_y: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_spawn_y = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	position.y = _spawn_y + sin(_t * 3.0) * 1.6
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode or _collected:
		return
	if body is Player:
		_collected = true
		Game.activate_buff(buff_type)
		Sfx.play("coin_pickup")
		queue_free()


func _draw() -> void:
	var color: Color = _COLORS.get(buff_type, Color.WHITE)
	var dim: Color = _COLORS_DIM.get(buff_type, Color.GRAY)
	# Outer frame.
	draw_rect(Rect2(-_SIZE * 0.5, _SIZE), dim)
	# Inner diamond.
	var pulse: float = (sin(_t * 6.0) + 1.0) * 0.5
	var inner_scale: float = 0.55 + pulse * 0.15
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -_SIZE.y * 0.5 * inner_scale),
		Vector2(_SIZE.x * 0.5 * inner_scale, 0.0),
		Vector2(0.0, _SIZE.y * 0.5 * inner_scale),
		Vector2(-_SIZE.x * 0.5 * inner_scale, 0.0),
	])
	draw_polygon(pts, PackedColorArray([color]))

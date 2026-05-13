## Voltline — boss HP bar (v0.66).
##
## Wide screen-anchored bar drawn near the bottom of the viewport while a
## boss is alive. Reads `boss.hp` / `boss.max_hp` every frame and shows the
## boss's name above the bar. Self-destructs (along with its host
## CanvasLayer) once the boss is gone or dead — the Boss base class spawns
## one of these in `_enter_tree` so every boss-bearing stage gets it for
## free with no per-stage wiring.
class_name BossHpBar
extends Control

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216

const _BAR_W: float = 280.0
const _BAR_H: float = 10.0
const _BAR_Y: float = 196.0

const _COLOR_BG: Color = Color("#0A0710")
const _COLOR_BORDER: Color = Color("#FF8080")
const _COLOR_FILL: Color = Color("#E2403A")
const _COLOR_FILL_LOW: Color = Color("#FFC040")
const _COLOR_FLASH: Color = Color("#FFFFFF")
const _COLOR_TEXT: Color = Color("#FFD0C8")

## The boss whose HP we mirror. Set by Boss._spawn_hp_bar before this
## widget enters the tree. Must expose `hp`, `max_hp`, `is_alive`.
var boss: Node = null

## Display name shown above the bar.
var boss_name: String = "BOSS"

# Brief white flash when hp drops, so taking a hit reads on the bar too.
var _flash_timer: float = 0.0
var _last_hp: int = -1
const _FLASH_DURATION: float = 0.10


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if boss != null and is_instance_valid(boss):
		_last_hp = int(boss.hp)


func _process(delta: float) -> void:
	# Tear down with the boss — drop our whole CanvasLayer host.
	if boss == null or not is_instance_valid(boss) or not bool(boss.is_alive):
		var host: Node = get_parent()
		if host is CanvasLayer:
			host.queue_free()
		else:
			queue_free()
		return
	var cur: int = int(boss.hp)
	if _last_hp >= 0 and cur < _last_hp:
		_flash_timer = _FLASH_DURATION
	_last_hp = cur
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var max_hp: int = maxi(int(boss.max_hp), 1)
	var pct: float = clampf(float(boss.hp) / float(max_hp), 0.0, 1.0)
	var x: float = (float(VIEWPORT_W) - _BAR_W) * 0.5
	# Name above the bar.
	var font: Font = ThemeDB.fallback_font
	var name_w: float = font.get_string_size(
		boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10
	).x
	draw_string(font, Vector2((float(VIEWPORT_W) - name_w) * 0.5, _BAR_Y - 4.0),
		boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _COLOR_TEXT)
	# Backing.
	draw_rect(Rect2(x, _BAR_Y, _BAR_W, _BAR_H), _COLOR_BG)
	# Fill — white during a hit flash, orange under 25%, red otherwise.
	var fill_color: Color
	if _flash_timer > 0.0:
		fill_color = _COLOR_FLASH
	elif pct < 0.25:
		fill_color = _COLOR_FILL_LOW
	else:
		fill_color = _COLOR_FILL
	draw_rect(Rect2(x + 2.0, _BAR_Y + 2.0, (_BAR_W - 4.0) * pct, _BAR_H - 4.0),
		fill_color)
	# Border.
	draw_rect(Rect2(x, _BAR_Y, _BAR_W, _BAR_H), _COLOR_BORDER, false)

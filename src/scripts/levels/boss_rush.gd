## Voltline — Boss Rush mode (post-true-clear unlock).
##
## Single fixed arena. Spawns the four bosses sequentially: R-08 →
## OMEGA-X → TYRANT-Z → TYRANT-Z². Each boss's `died` signal triggers a
## brief intermission (heal + intro banner) before the next boss appears.
## Beating TYRANT-Z² sets `Game.boss_rush_cleared` and persists.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const ARENA_WIDTH: int = 384

const FLOOR_Y: int = 180
const FLOOR_HEIGHT: int = 36

const COLOR_BG: Color = Color("#000000")
const COLOR_GROUND: Color = Color("#1A1A22")
const COLOR_GRID: Color = Color("#1F2A3A")
const COLOR_GOAL: Color = Color("#FFD24A")
const COLOR_TEXT: Color = Color("#FFE090")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/boss.tscn")
const FINAL_BOSS_SCENE: PackedScene = preload("res://scenes/final_boss.tscn")
const TYRANT_SCENE: PackedScene = preload("res://scenes/tyrant_z.tscn")
const TYRANT2_SCENE: PackedScene = preload("res://scenes/tyrant_z2.tscn")

const PLAYER_SPAWN: Vector2 = Vector2(80.0, 160.0)
const BOSS_SPAWN: Vector2 = Vector2(304.0, 152.0)

const STAGE_NAME: String = "BOSS RUSH // 4 ROUNDS"
const STAGE_INTRO_DURATION: float = 2.4
const ROUND_BANNER_DURATION: float = 1.6
const GOAL_DELAY: float = 3.0

const FADE_IN_DURATION: float = 0.5
const FADE_OUT_DURATION: float = 1.2

# Order matters — index 0 spawns first.
const ROUNDS: Array = [
	{"name": "ROUND 1 — R-08", "scene": BOSS_SCENE},
	{"name": "ROUND 2 — OMEGA-X", "scene": FINAL_BOSS_SCENE},
	{"name": "ROUND 3 — TYRANT-Z", "scene": TYRANT_SCENE},
	{"name": "ROUND 4 — TYRANT-Z²", "scene": TYRANT2_SCENE},
]

var _round_index: int = 0
var _goal_reached: bool = false
var _transitioning: bool = false
var _hud_layer: CanvasLayer
var _stage_clear_label: Label
var _stage_intro_label: Label
var _round_banner: Label
var _fade_rect: ColorRect
var _hp_bar: HpBar
var _player: Player
var _current_boss: Node


func _ready() -> void:
	Game.current_area = "boss_rush"
	Music.play("boss")
	_build_static_block(Rect2(0.0, FLOOR_Y, ARENA_WIDTH, FLOOR_HEIGHT), &"Floor")
	# Side bounds keep the player from jumping into oblivion.
	_build_static_block(Rect2(-16.0, 0.0, 16.0, 216.0), &"BoundLeft")
	_build_static_block(Rect2(float(ARENA_WIDTH), 0.0, 16.0, 216.0), &"BoundRight")
	# A pair of low platforms for verticality.
	_build_static_block(Rect2(60.0, 130.0, 56.0, 8.0), &"Plat0")
	_build_static_block(Rect2(268.0, 130.0, 56.0, 8.0), &"Plat1")
	_spawn_player_with_camera()
	_build_hud()
	_show_stage_intro()
	# Spawn the first round on a short delay so the intro banner reads.
	var timer: SceneTreeTimer = get_tree().create_timer(STAGE_INTRO_DURATION)
	timer.timeout.connect(_start_next_round)


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_transitioning = true
		var tween: Tween = create_tween()
		tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
		tween.tween_callback(func() -> void:
			if is_inside_tree():
				Game.goto_level("title")
		)


func _draw() -> void:
	draw_rect(Rect2(0, 0, ARENA_WIDTH, VIEWPORT_H), COLOR_BG)
	# Faint grid lines for the void-arena feel.
	for x in range(0, ARENA_WIDTH, 16):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), float(FLOOR_Y)), COLOR_GRID, 1.0)
	draw_rect(Rect2(0, FLOOR_Y, ARENA_WIDTH, FLOOR_HEIGHT), COLOR_GROUND)


# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

func _build_static_block(rect: Rect2, body_name: StringName) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position = rect.position + rect.size * 0.5
	body.add_child(collider)


func _spawn_player_with_camera() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_SPAWN
	Game.apply_upgrades_to(_player)
	add_child(_player)

	var camera: Camera2D = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = ARENA_WIDTH
	camera.limit_top = 0
	camera.limit_bottom = VIEWPORT_H
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_player.add_child(camera)
	camera.make_current()


func _start_next_round() -> void:
	if not is_inside_tree():
		return
	if _round_index >= ROUNDS.size():
		_on_rush_cleared()
		return
	# Heal player to full between rounds — boss rush is about boss skill,
	# not attrition.
	_player.hp = _player.max_hp
	var data: Dictionary = ROUNDS[_round_index]
	_round_banner.text = data["name"]
	_round_banner.visible = true
	var scene: PackedScene = data["scene"]
	_current_boss = scene.instantiate()
	_current_boss.position = BOSS_SPAWN
	add_child(_current_boss)
	_current_boss.died.connect(_on_round_cleared)
	# Hide the round banner after a beat.
	var timer: SceneTreeTimer = get_tree().create_timer(ROUND_BANNER_DURATION)
	timer.timeout.connect(_hide_round_banner)


func _hide_round_banner() -> void:
	if not is_inside_tree() or _round_banner == null:
		return
	_round_banner.visible = false


func _on_round_cleared() -> void:
	_round_index += 1
	# Brief intermission before the next round.
	var timer: SceneTreeTimer = get_tree().create_timer(1.4)
	timer.timeout.connect(_start_next_round)


func _on_rush_cleared() -> void:
	if _goal_reached:
		return
	_goal_reached = true
	_transitioning = true
	Game.boss_rush_cleared = true
	var is_new_best: bool = Game.register_clear("boss_rush")
	_stage_clear_label.text = "%s\n%s" % [
		_stage_clear_label.text,
		Game.format_score_summary(is_new_best)
	]
	_stage_clear_label.visible = true
	Sfx.play("goal")
	var timer: SceneTreeTimer = get_tree().create_timer(GOAL_DELAY)
	timer.timeout.connect(_fade_out_to_title)


func _fade_out_to_title() -> void:
	if not is_inside_tree():
		return
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(_return_to_title)


func _return_to_title() -> void:
	if not is_inside_tree():
		return
	Game.goto_level("title")


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_stage_clear_label = Label.new()
	_stage_clear_label.text = "RUSH CLEAR!"
	_stage_clear_label.add_theme_font_size_override("font_size", 36)
	_stage_clear_label.add_theme_color_override("font_color", COLOR_GOAL)
	_stage_clear_label.position = Vector2(0.0, float(VIEWPORT_H - 48) * 0.5)
	_stage_clear_label.size = Vector2(VIEWPORT_W, 48)
	_stage_clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_clear_label.visible = false
	_hud_layer.add_child(_stage_clear_label)

	_stage_intro_label = Label.new()
	_stage_intro_label.text = STAGE_NAME
	_stage_intro_label.add_theme_font_size_override("font_size", 14)
	_stage_intro_label.add_theme_color_override("font_color", COLOR_TEXT)
	_stage_intro_label.position = Vector2(0.0, 30.0)
	_stage_intro_label.size = Vector2(VIEWPORT_W, 24)
	_stage_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_stage_intro_label)

	_round_banner = Label.new()
	_round_banner.text = ""
	_round_banner.add_theme_font_size_override("font_size", 16)
	_round_banner.add_theme_color_override("font_color", COLOR_GOAL)
	_round_banner.position = Vector2(0.0, 60.0)
	_round_banner.size = Vector2(VIEWPORT_W, 24)
	_round_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round_banner.visible = false
	_hud_layer.add_child(_round_banner)

	_hp_bar = HpBar.new()
	_hp_bar.player = _player
	_hp_bar.position = Vector2(8.0, 8.0)
	_hp_bar.size = Vector2(140.0, 12.0)
	_hud_layer.add_child(_hp_bar)

	var coins: CoinCounter = CoinCounter.new()
	coins.position = Vector2(VIEWPORT_W - 64.0, 8.0)
	coins.size = Vector2(60.0, 12.0)
	_hud_layer.add_child(coins)

	# Active buff strip (v0.64).
	var buff_hud: BuffHud = BuffHud.new()
	buff_hud.position = Vector2(8.0, 24.0)
	buff_hud.size = Vector2(300.0, 14.0)
	_hud_layer.add_child(buff_hud)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_fade_rect)
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_DURATION)


func _show_stage_intro() -> void:
	# Stage intro stays visible across the first round-banner gap; we
	# only hide it when the rush starts.
	pass

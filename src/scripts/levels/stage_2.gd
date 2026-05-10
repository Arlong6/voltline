## Voltline — Stage 2 (V-008 build).
##
## 768-px-wide stage = 2 viewport widths. Tighter than stage_1: a single
## floor with a wall-jump shaft early, two patrolling enemies on
## staggered platforms, and the final goal flag.
##
## Visual theme: dark green / sublevel — distinguishes it from stage_1's
## purple at a glance so the scene change reads as "new place".
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const STAGE_WIDTH: int = 768

const FLOOR_Y: int = 180
const FLOOR_HEIGHT: int = 36

const COLOR_BG: Color = Color("#0E1F18")
const COLOR_GROUND: Color = Color("#244530")
const COLOR_PLATFORM: Color = Color("#3F6D52")
const COLOR_WALL: Color = Color("#2C5040")
const COLOR_GOAL: Color = Color("#FFD24A")
const COLOR_GOAL_POLE: Color = Color("#A0A0A0")
const COLOR_TEXT: Color = Color("#9CE0B8")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/boss.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/spike.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/checkpoint.tscn")
const HEAL_STATION_SCENE: PackedScene = preload("res://scenes/heal_station.tscn")
const HEAL_STATION_POS: Vector2 = Vector2(440.0, 168.0)
const CHECKPOINT_POS: Vector2 = Vector2(420.0, 180.0)

# Spike strip positions (centre x, centre y). Player walking over these
# is instant respawn — adds a "watch your step" obstacle.
const SPIKE_POSITIONS: Array[Vector2] = [
	Vector2(380.0, 176.0),
]
const PLAYER_SPAWN: Vector2 = Vector2(40.0, 160.0)
const BOSS_SPAWN: Vector2 = Vector2(720.0, 156.0)

const PLATFORMS: Array[Rect2] = [
	# Wall-jump shaft top (lowered from y=92 to y=116 to match shorter walls).
	Rect2(160.0, 116.0, 96.0, 8.0),
	# Mid-stage stepping stones.
	Rect2(360.0, 152.0, 56.0, 8.0),
	Rect2(480.0, 124.0, 56.0, 8.0),
	Rect2(600.0, 100.0, 56.0, 8.0),
]

const WALLS: Array[Rect2] = [
	# Wall-jump shaft uprights — 64 px gap, 56 tall (matches stage_1 fix).
	Rect2(160.0, 124.0, 16.0, 56.0),
	Rect2(240.0, 124.0, 16.0, 56.0),
]

const BOUNDS: Array[Rect2] = [
	Rect2(-16.0, 0.0, 16.0, 216.0),
	Rect2(float(STAGE_WIDTH), 0.0, 16.0, 216.0),
]

const ENEMY_PATROLS: Array = [
	# On the floor before the wall-jump shaft.
	[110.0, 80.0, 150.0],
	# Mid-stage between platforms.
	[420.0, 360.0, 540.0],
	# Just before the boss arena.
	[610.0, 560.0, 680.0],
]
const ENEMY_FLOOR_Y: float = 168.0

const GOAL_POS: Vector2 = Vector2(720.0, 84.0)
const GOAL_SIZE: Vector2 = Vector2(8.0, 16.0)
const GOAL_POLE_SIZE: Vector2 = Vector2(2.0, 48.0)
const GOAL_TRIGGER_SIZE: Vector2 = Vector2(32.0, 48.0)
const GOAL_DELAY: float = 2.5

const STAGE_NAME: String = "SECTOR 2 // SUBLEVEL"
const STAGE_INTRO_DURATION: float = 2.0

# Stage-2 enemies — bumped to 6 HP / 80 speed in v0.53. Charged buster
# is borderline mandatory now.
const ENEMY_HP: int = 6
const ENEMY_SPEED: float = 80.0
# R-08 mid-boss — 30 HP, 0.75s shoot cadence, 200 px/s bullets.
const BOSS_HP: int = 30
const BOSS_SHOOT_INTERVAL: float = 0.75
const BOSS_BULLET_SPEED: float = 200.0

const FADE_IN_DURATION: float = 0.5
const FADE_OUT_DURATION: float = 1.0

var _goal_reached: bool = false
var _transitioning: bool = false
var _hud_layer: CanvasLayer
var _stage_clear_label: Label
var _stage_intro_label: Label
var _fade_rect: ColorRect
var _hp_bar: HpBar
var _player: Player
var _boss: Boss


func _ready() -> void:
	Game.current_area = "stage_2"
	Music.play("boss")
	_build_static_block(Rect2(0.0, FLOOR_Y, STAGE_WIDTH, FLOOR_HEIGHT), &"Floor")
	for i in PLATFORMS.size():
		_build_static_block(PLATFORMS[i], &"Platform_%d" % i)
	for i in WALLS.size():
		_build_static_block(WALLS[i], &"Wall_%d" % i)
	for i in BOUNDS.size():
		_build_static_block(BOUNDS[i], &"Bound_%d" % i)
	_spawn_player_with_camera()
	_spawn_enemies()
	_spawn_spikes()
	_spawn_checkpoint()
	_spawn_heal_station()
	_spawn_boss()
	_build_hud()
	_show_stage_intro()


func _spawn_checkpoint() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.position = CHECKPOINT_POS
	add_child(checkpoint)


func _spawn_heal_station() -> void:
	var station: HealStation = HEAL_STATION_SCENE.instantiate() as HealStation
	station.position = HEAL_STATION_POS
	add_child(station)


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
	draw_rect(Rect2(0, 0, STAGE_WIDTH, VIEWPORT_H), COLOR_BG)
	draw_rect(Rect2(0, FLOOR_Y, STAGE_WIDTH, FLOOR_HEIGHT), COLOR_GROUND)
	for platform in PLATFORMS:
		draw_rect(platform, COLOR_PLATFORM)
	for wall in WALLS:
		draw_rect(wall, COLOR_WALL)
	# Boss callout above the spawn area — names the foe so the encounter
	# reads like a proper bossfight rather than a wandering enemy.
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font, Vector2(BOSS_SPAWN.x - 36.0, BOSS_SPAWN.y - 36.0),
		"R-08  SWEEPER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GOAL
	)


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


func _spawn_spikes() -> void:
	for pos in SPIKE_POSITIONS:
		var spike: Spike = SPIKE_SCENE.instantiate() as Spike
		spike.position = pos
		add_child(spike)


func _spawn_enemies() -> void:
	for entry in ENEMY_PATROLS:
		var spawn_x: float = entry[0]
		var min_x: float = entry[1]
		var max_x: float = entry[2]
		var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
		enemy.position = Vector2(spawn_x, ENEMY_FLOOR_Y)
		enemy.patrol_min_x = min_x
		enemy.patrol_max_x = max_x
		enemy.max_hp = ENEMY_HP
		enemy.walk_speed = ENEMY_SPEED
		add_child(enemy)


func _spawn_player_with_camera() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_SPAWN
	Game.apply_upgrades_to(_player)
	add_child(_player)

	var camera: Camera2D = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = STAGE_WIDTH
	camera.limit_top = 0
	camera.limit_bottom = VIEWPORT_H
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_player.add_child(camera)
	camera.make_current()


# Spawns the stage's miniboss in place of the old goal flag. boss.died
# fires when the boss's hp hits zero and routes through the same clear
# flow (banner + fade + return-to-title) the goal flag used.
func _spawn_boss() -> void:
	_boss = BOSS_SCENE.instantiate() as Boss
	_boss.max_hp = BOSS_HP
	_boss.shoot_interval = BOSS_SHOOT_INTERVAL
	_boss.bullet_speed = BOSS_BULLET_SPEED
	_boss.position = BOSS_SPAWN
	add_child(_boss)
	_boss.died.connect(_on_boss_defeated)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_stage_clear_label = Label.new()
	_stage_clear_label.text = "ALL CLEAR!"
	_stage_clear_label.add_theme_font_size_override("font_size", 32)
	_stage_clear_label.add_theme_color_override("font_color", COLOR_GOAL)
	_stage_clear_label.position = Vector2(0.0, float(VIEWPORT_H - 48) * 0.5)
	_stage_clear_label.size = Vector2(VIEWPORT_W, 48)
	_stage_clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_clear_label.visible = false
	_hud_layer.add_child(_stage_clear_label)

	_stage_intro_label = Label.new()
	_stage_intro_label.text = STAGE_NAME
	_stage_intro_label.add_theme_font_size_override("font_size", 16)
	_stage_intro_label.add_theme_color_override("font_color", COLOR_TEXT)
	_stage_intro_label.position = Vector2(0.0, 30.0)
	_stage_intro_label.size = Vector2(VIEWPORT_W, 24)
	_stage_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_stage_intro_label)

	# HP bar — anchored to top-left, reads from _player every frame.
	_hp_bar = HpBar.new()
	_hp_bar.player = _player
	_hp_bar.position = Vector2(8.0, 8.0)
	_hp_bar.size = Vector2(140.0, 12.0)
	_hud_layer.add_child(_hp_bar)

	# Coin counter — top-right.
	var coins: CoinCounter = CoinCounter.new()
	coins.position = Vector2(VIEWPORT_W - 64.0, 8.0)
	coins.size = Vector2(60.0, 12.0)
	_hud_layer.add_child(coins)

	# Fade overlay — last child so it covers every other HUD element.
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_fade_rect)
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_DURATION)


func _show_stage_intro() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(STAGE_INTRO_DURATION)
	timer.timeout.connect(_hide_stage_intro)


func _hide_stage_intro() -> void:
	if not is_inside_tree() or _stage_intro_label == null:
		return
	_stage_intro_label.visible = false


func _on_boss_defeated() -> void:
	if _goal_reached:
		return
	_goal_reached = true
	_transitioning = true
	_stage_clear_label.visible = true
	Sfx.play("goal")
	# Boss is the mid-game climax; player still has stage_3 to escape through.
	var timer: SceneTreeTimer = get_tree().create_timer(GOAL_DELAY)
	timer.timeout.connect(_fade_out_to_stage_3)


func _fade_out_to_stage_3() -> void:
	if not is_inside_tree():
		return
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(_advance_to_stage_3)


func _advance_to_stage_3() -> void:
	if not is_inside_tree():
		return
	Game.play_cutscene(
		"// R-08 OFFLINE",
		PackedStringArray([
			"SENTINEL R-08 — FRAGMENTED.",
			"SUBLEVEL ACCESS GRANTED.",
			"OMEGA-X PATROLS THE SKYBRIDGE ARC.",
			"PUSH UPWARD. THE LIGHT IS THIN HERE.",
		]),
		"stage_3"
	)

## Voltline — Stage 3 (skybridge gauntlet).
##
## After the player downs R-08 in stage_2, they fight their way across
## a 1024-px dawn-blue skybridge into OMEGA-X. Defeating OMEGA-X
## advances to stage_4 (the CORE) for the true final encounter.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const STAGE_WIDTH: int = 1024

const FLOOR_Y: int = 180
const FLOOR_HEIGHT: int = 36

const COLOR_BG: Color = Color("#0F1A2E")
const COLOR_GROUND: Color = Color("#1F3050")
const COLOR_PLATFORM: Color = Color("#3F5A88")
const COLOR_WALL: Color = Color("#2A4068")
const COLOR_GOAL: Color = Color("#FFD24A")
const COLOR_GOAL_POLE: Color = Color("#A0A0A0")
const COLOR_TEXT: Color = Color("#A8D8FF")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const TURRET_SCENE: PackedScene = preload("res://scenes/turret.tscn")
const DRONE_SCENE: PackedScene = preload("res://scenes/drone.tscn")
const KAMIKAZE_SCENE: PackedScene = preload("res://scenes/kamikaze.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/spike.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/checkpoint.tscn")
const HEAL_STATION_SCENE: PackedScene = preload("res://scenes/heal_station.tscn")
const HEAL_STATION_POS: Vector2 = Vector2(560.0, 168.0)
const KAMIKAZE_POS: Vector2 = Vector2(700.0, 80.0)
const DESTRUCTIBLE_WALL_SCENE: PackedScene = preload("res://scenes/destructible_wall.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const FINAL_BOSS_SCENE: PackedScene = preload("res://scenes/final_boss.tscn")
const PLAYER_SPAWN: Vector2 = Vector2(40.0, 160.0)
const CHECKPOINT_POS: Vector2 = Vector2(540.0, 180.0)
const FINAL_BOSS_SPAWN: Vector2 = Vector2(960.0, 156.0)

# Turret positions (centre). All standing on existing platform tops.
const TURRET_POSITIONS: Array[Vector2] = [
	Vector2(380.0, 102.0),  # on top of the upper opening platform
	Vector2(770.0, 110.0),  # on top of the wall-jump shaft cap
]

# Spike strip positions on the floor — punish careless dashing.
const SPIKE_POSITIONS: Array[Vector2] = [
	Vector2(450.0, 176.0),
	Vector2(900.0, 176.0),
]

const PLATFORMS: Array[Rect2] = [
	# Opening jumps — staircase up.
	Rect2(140.0, 156.0, 56.0, 8.0),
	Rect2(240.0, 132.0, 56.0, 8.0),
	Rect2(340.0, 108.0, 80.0, 8.0),
	# Mid-stage gauntlet platforms — wider gaps demand dash-jumps.
	Rect2(500.0, 124.0, 48.0, 8.0),
	Rect2(620.0, 100.0, 48.0, 8.0),
	# Top of the second wall-jump shaft.
	Rect2(720.0, 116.0, 96.0, 8.0),
	# Final descent — three steps to the goal.
	Rect2(880.0, 140.0, 56.0, 8.0),
	Rect2(960.0, 164.0, 56.0, 8.0),
]

const WALLS: Array[Rect2] = [
	# Final wall-jump shaft (left + right uprights, 56 tall).
	Rect2(720.0, 124.0, 16.0, 56.0),
	Rect2(800.0, 124.0, 16.0, 56.0),
]

const BOUNDS: Array[Rect2] = [
	Rect2(-16.0, 0.0, 16.0, 216.0),
	Rect2(float(STAGE_WIDTH), 0.0, 16.0, 216.0),
]

const ENEMY_PATROLS: Array = [
	[200.0, 140.0, 280.0],
	[440.0, 380.0, 480.0],
	[680.0, 600.0, 700.0],
	[940.0, 880.0, 1010.0],
]
const ENEMY_FLOOR_Y: float = 168.0
const ENEMY_HP: int = 5
const ENEMY_SPEED: float = 75.0

# Drones added v0.54 — patrol over the mid-stage gauntlet, force the
# player to keep moving instead of camping under platforms.
# Format: [spawn_x, hover_y, min_x, max_x]
const DRONE_PATROLS: Array = [
	[480.0, 60.0, 420.0, 580.0],
	[820.0, 70.0, 760.0, 880.0],
]
const DRONE_HP: int = 3
const DRONE_SPEED: float = 55.0

const GOAL_DELAY: float = 2.5

const STAGE_NAME: String = "SECTOR 3 // SKYBRIDGE"
const STAGE_INTRO_DURATION: float = 2.0

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
var _final_boss: FinalBoss


func _ready() -> void:
	Game.current_area = "stage_3"
	Music.play("stage")
	_build_static_block(Rect2(0.0, FLOOR_Y, STAGE_WIDTH, FLOOR_HEIGHT), &"Floor")
	for i in PLATFORMS.size():
		_build_static_block(PLATFORMS[i], &"Platform_%d" % i)
	for i in WALLS.size():
		_build_static_block(WALLS[i], &"Wall_%d" % i)
	for i in BOUNDS.size():
		_build_static_block(BOUNDS[i], &"Bound_%d" % i)
	_spawn_player_with_camera()
	_spawn_enemies()
	_spawn_drones()
	_spawn_kamikaze()
	_spawn_turrets()
	_spawn_spikes()
	_spawn_checkpoint()
	_spawn_heal_station()
	_spawn_hidden_room(220.0, 8)
	_spawn_final_boss()
	_build_hud()
	_show_stage_intro()


func _spawn_checkpoint() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.position = CHECKPOINT_POS
	add_child(checkpoint)


func _spawn_final_boss() -> void:
	_final_boss = FINAL_BOSS_SCENE.instantiate() as FinalBoss
	_final_boss.position = FINAL_BOSS_SPAWN
	add_child(_final_boss)
	_final_boss.died.connect(_on_final_boss_defeated)


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
	# Final-boss callout above the spawn area.
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font, Vector2(FINAL_BOSS_SPAWN.x - 30.0, FINAL_BOSS_SPAWN.y - 48.0),
		"OMEGA-X", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GOAL
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


func _spawn_turrets() -> void:
	for pos in TURRET_POSITIONS:
		var turret: Turret = TURRET_SCENE.instantiate() as Turret
		turret.position = pos
		add_child(turret)


func _spawn_drones() -> void:
	for entry in DRONE_PATROLS:
		var spawn_x: float = entry[0]
		var hover_y: float = entry[1]
		var min_x: float = entry[2]
		var max_x: float = entry[3]
		var drone: Drone = DRONE_SCENE.instantiate() as Drone
		drone.position = Vector2(spawn_x, hover_y)
		drone.hover_y = hover_y
		drone.patrol_min_x = min_x
		drone.patrol_max_x = max_x
		drone.max_hp = DRONE_HP
		drone.walk_speed = DRONE_SPEED
		add_child(drone)


func _spawn_kamikaze() -> void:
	var kami: Kamikaze = KAMIKAZE_SCENE.instantiate() as Kamikaze
	kami.position = KAMIKAZE_POS
	kami.hover_y = KAMIKAZE_POS.y
	kami.patrol_min_x = KAMIKAZE_POS.x - 60.0
	kami.patrol_max_x = KAMIKAZE_POS.x + 60.0
	add_child(kami)


func _spawn_heal_station() -> void:
	var station: HealStation = HEAL_STATION_SCENE.instantiate() as HealStation
	station.position = HEAL_STATION_POS
	add_child(station)


# v0.60 hidden room — Lv2 super-charge breaks the wall, ceiling caps the
# alcove so double-jump can't skip the puzzle. See stage_2 for shape.
func _spawn_hidden_room(wall_x: float, coin_count: int) -> void:
	var room_w: float = 16.0 + float(coin_count) * 8.0
	_build_static_block(Rect2(wall_x, 148.0, room_w, 4.0), &"HiddenCeiling")
	var wall: DestructibleWall = DESTRUCTIBLE_WALL_SCENE.instantiate() as DestructibleWall
	wall.size = Vector2(8.0, 32.0)
	wall.position = Vector2(wall_x + 4.0, 164.0)
	add_child(wall)
	for i in coin_count:
		var coin: Coin = COIN_SCENE.instantiate() as Coin
		coin.position = Vector2(wall_x + 16.0 + float(i) * 8.0, 168.0)
		add_child(coin)


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


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_stage_clear_label = Label.new()
	_stage_clear_label.text = "OMEGA-X DOWN"
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

	_hp_bar = HpBar.new()
	_hp_bar.player = _player
	_hp_bar.position = Vector2(8.0, 8.0)
	_hp_bar.size = Vector2(140.0, 12.0)
	_hud_layer.add_child(_hp_bar)

	var coins: CoinCounter = CoinCounter.new()
	coins.position = Vector2(VIEWPORT_W - 64.0, 8.0)
	coins.size = Vector2(60.0, 12.0)
	_hud_layer.add_child(coins)

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


func _on_final_boss_defeated() -> void:
	if _goal_reached:
		return
	_goal_reached = true
	_transitioning = true
	var is_new_best: bool = Game.register_clear("stage_3")
	_stage_clear_label.text = "%s\n%s" % [
		_stage_clear_label.text,
		Game.format_score_summary(is_new_best)
	]
	_stage_clear_label.visible = true
	# Penultimate boss down — advance to stage_4 (CORE) for the true
	# final encounter against TYRANT-Z. The final game-clear flag is
	# set there.
	Sfx.play("goal")
	var timer: SceneTreeTimer = get_tree().create_timer(GOAL_DELAY)
	timer.timeout.connect(_fade_out_to_stage_4)


func _fade_out_to_stage_4() -> void:
	if not is_inside_tree():
		return
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(_advance_to_stage_4)


func _advance_to_stage_4() -> void:
	if not is_inside_tree():
		return
	Game.play_cutscene(
		"// OMEGA-X SILENCED",
		PackedStringArray([
			"SKYBRIDGE BURNING. OMEGA-X SCATTERED.",
			"BELOW US: THE CORE. ALL SIGNALS DARK.",
			"TYRANT-Z RULES THE LIGHT IN THERE.",
			"DESCEND. END THIS.",
		]),
		"stage_4"
	)

## Voltline — Stage 4 (true final, V-016).
##
## After OMEGA-X, the player descends into the central core to face
## TYRANT-Z. 1024 px wide, dark red lab theme, denser hazards: 3
## walking enemies, 3 turrets across multiple platforms, 3 spike strips,
## and the TYRANT-Z arena at the far right.
##
## TYRANT-Z's death is the true GAME CLEAR — sets Game.game_cleared
## and persists it before the fade-to-title.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const STAGE_WIDTH: int = 1024

const FLOOR_Y: int = 180
const FLOOR_HEIGHT: int = 36

const COLOR_BG: Color = Color("#1A0A14")
const COLOR_GROUND: Color = Color("#3A1A20")
const COLOR_PLATFORM: Color = Color("#6A2C32")
const COLOR_WALL: Color = Color("#5A2028")
const COLOR_GOAL: Color = Color("#FFD24A")
const COLOR_TEXT: Color = Color("#FF9890")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const DRONE_SCENE: PackedScene = preload("res://scenes/drone.tscn")
const BRUTE_SCENE: PackedScene = preload("res://scenes/brute.tscn")
const KAMIKAZE_SCENE: PackedScene = preload("res://scenes/kamikaze.tscn")
const TURRET_SCENE: PackedScene = preload("res://scenes/turret.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/spike.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/checkpoint.tscn")
const HEAL_STATION_SCENE: PackedScene = preload("res://scenes/heal_station.tscn")
const HEAL_STATION_POS: Vector2 = Vector2(620.0, 168.0)
const DESTRUCTIBLE_WALL_SCENE: PackedScene = preload("res://scenes/destructible_wall.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const BRUTE_SPAWN: Vector2 = Vector2(720.0, 160.0)
const BRUTE_MIN_X: float = 660.0
const BRUTE_MAX_X: float = 800.0
const KAMIKAZE_POS: Vector2 = Vector2(840.0, 80.0)
const TYRANT_SCENE: PackedScene = preload("res://scenes/tyrant_z.tscn")
const PLAYER_SPAWN: Vector2 = Vector2(40.0, 160.0)
const CHECKPOINT_POS: Vector2 = Vector2(540.0, 180.0)
const TYRANT_SPAWN: Vector2 = Vector2(940.0, 152.0)

# Step-up step-down platforming. Small windows mean dash + wall-jump
# usage is mandatory to clear cleanly.
const PLATFORMS: Array[Rect2] = [
	Rect2(140.0, 152.0, 56.0, 8.0),
	Rect2(260.0, 124.0, 56.0, 8.0),
	Rect2(380.0, 100.0, 80.0, 8.0),
	Rect2(540.0, 124.0, 56.0, 8.0),
	# Wall-jump cap.
	Rect2(640.0, 116.0, 96.0, 8.0),
	Rect2(800.0, 140.0, 64.0, 8.0),
]

const WALLS: Array[Rect2] = [
	# Wall-jump shaft uprights.
	Rect2(640.0, 124.0, 16.0, 56.0),
	Rect2(720.0, 124.0, 16.0, 56.0),
]

const BOUNDS: Array[Rect2] = [
	Rect2(-16.0, 0.0, 16.0, 216.0),
	Rect2(float(STAGE_WIDTH), 0.0, 16.0, 216.0),
]

const ENEMY_PATROLS: Array = [
	[200.0, 140.0, 280.0],
	[440.0, 380.0, 480.0],
	[860.0, 800.0, 900.0],
]
const ENEMY_FLOOR_Y: float = 168.0
const ENEMY_HP: int = 6
const ENEMY_SPEED: float = 80.0

# Drones added v0.54 — patrol the gauntlet's vertical airspace.
# Format: [spawn_x, hover_y, min_x, max_x]
const DRONE_PATROLS: Array = [
	[400.0, 56.0, 340.0, 460.0],
	[700.0, 64.0, 640.0, 760.0],
]
const DRONE_HP: int = 4
const DRONE_SPEED: float = 60.0

# Three turrets: opening platform, mid-stage, atop wall-jump shaft.
const TURRET_POSITIONS: Array[Vector2] = [
	Vector2(290.0, 118.0),  # on platform y=124 top
	Vector2(420.0, 94.0),   # on platform y=100 top
	Vector2(680.0, 110.0),  # on wall-jump cap y=116 top
]

const SPIKE_POSITIONS: Array[Vector2] = [
	Vector2(330.0, 176.0),
	Vector2(500.0, 176.0),
	Vector2(750.0, 176.0),
]

const STAGE_NAME: String = "SECTOR 4 // CORE"
const STAGE_INTRO_DURATION: float = 2.0
const GOAL_DELAY: float = 2.5

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
var _tyrant: TyrantZ


func _ready() -> void:
	Game.current_area = "stage_4"
	Music.play("boss")  # reuse the dark boss track for the final fight
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
	_spawn_brute()
	_spawn_kamikaze()
	_spawn_turrets()
	_spawn_spikes()
	_spawn_checkpoint()
	_spawn_heal_station()
	_spawn_hidden_room(220.0, 10)
	_spawn_tyrant()
	_build_hud()
	_show_stage_intro()


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
	# TYRANT-Z callout above the spawn area.
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font, Vector2(TYRANT_SPAWN.x - 36.0, TYRANT_SPAWN.y - 56.0),
		"TYRANT-Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GOAL
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


func _spawn_brute() -> void:
	var brute: Brute = BRUTE_SCENE.instantiate() as Brute
	brute.position = BRUTE_SPAWN
	brute.patrol_min_x = BRUTE_MIN_X
	brute.patrol_max_x = BRUTE_MAX_X
	add_child(brute)


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


# v0.60 hidden room — see stage_2 for layout shape.
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


func _spawn_checkpoint() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.position = CHECKPOINT_POS
	add_child(checkpoint)


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


func _spawn_tyrant() -> void:
	_tyrant = TYRANT_SCENE.instantiate() as TyrantZ
	_tyrant.position = TYRANT_SPAWN
	add_child(_tyrant)
	_tyrant.died.connect(_on_tyrant_defeated)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_stage_clear_label = Label.new()
	_stage_clear_label.text = "GAME CLEAR!"
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

	# v0.68 — speedrun timer (current time vs PB) tucked under the coin counter.
	var spd_timer: SpeedrunTimer = SpeedrunTimer.new()
	spd_timer.position = Vector2(VIEWPORT_W - 64.0, 18.0)
	spd_timer.size = Vector2(60.0, 24.0)
	_hud_layer.add_child(spd_timer)

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
	var timer: SceneTreeTimer = get_tree().create_timer(STAGE_INTRO_DURATION)
	timer.timeout.connect(_hide_stage_intro)


func _hide_stage_intro() -> void:
	if not is_inside_tree() or _stage_intro_label == null:
		return
	_stage_intro_label.visible = false


func _on_tyrant_defeated() -> void:
	if _goal_reached:
		return
	_goal_reached = true
	_transitioning = true
	# Game-clear flag set BEFORE register_clear so the score persistence
	# also stamps the milestone in the same save_to_file() round-trip.
	Game.game_cleared = true
	var is_new_best: bool = Game.register_clear("stage_4")
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
	Game.return_to_base_or_title("stage_4", true)

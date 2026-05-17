## Voltline — Stage 6 (post-rush nightmare unlock).
##
## Unlocks after Boss Rush is cleared. 1024-px crimson-on-black arena
## leading into the GRID-0 fight: walls of brutes, kamikaze patrols,
## drone overwatch, and a checkpoint right before the boss room. Beating
## GRID-0 swaps the title prompt to "ARCHITECT FELL" and persists.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const STAGE_WIDTH: int = 1024

const FLOOR_Y: int = 180
const FLOOR_HEIGHT: int = 36

const COLOR_BG: Color = Color("#0A0006")
const COLOR_GROUND: Color = Color("#22080E")
const COLOR_PLATFORM: Color = Color("#5A1024")
const COLOR_WALL: Color = Color("#48081A")
const COLOR_GOAL: Color = Color("#FFD24A")
const COLOR_TEXT: Color = Color("#FF6080")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const BRUTE_SCENE: PackedScene = preload("res://scenes/brute.tscn")
const KAMIKAZE_SCENE: PackedScene = preload("res://scenes/kamikaze.tscn")
const DRONE_SCENE: PackedScene = preload("res://scenes/drone.tscn")
const TURRET_SCENE: PackedScene = preload("res://scenes/turret.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/spike.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/checkpoint.tscn")
const HEAL_STATION_SCENE: PackedScene = preload("res://scenes/heal_station.tscn")
const MOVING_PLATFORM_SCENE: PackedScene = preload("res://scenes/moving_platform.tscn")
const LASER_BEAM_SCENE: PackedScene = preload("res://scenes/laser_beam.tscn")
const CRUSHER_SCENE: PackedScene = preload("res://scenes/crusher.tscn")
const DESTRUCTIBLE_WALL_SCENE: PackedScene = preload("res://scenes/destructible_wall.tscn")
const SWITCH_PANEL_SCENE: PackedScene = preload("res://scenes/switch_panel.tscn")
const DOOR_GATE_SCENE: PackedScene = preload("res://scenes/door_gate.tscn")
const CONVEYOR_SCENE: PackedScene = preload("res://scenes/conveyor_belt.tscn")
const CRUMBLING_SCENE: PackedScene = preload("res://scenes/crumbling_platform.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const GRID_ZERO_SCENE: PackedScene = preload("res://scenes/grid_zero.tscn")

const PLAYER_SPAWN: Vector2 = Vector2(40.0, 160.0)
const HEAL_STATION_POS: Vector2 = Vector2(560.0, 168.0)
const CHECKPOINT_POS: Vector2 = Vector2(700.0, 180.0)
const GRID_ZERO_SPAWN: Vector2 = Vector2(900.0, 142.0)

const PLATFORMS: Array[Rect2] = [
	# Opening climb.
	Rect2(140.0, 152.0, 56.0, 8.0),
	Rect2(260.0, 124.0, 56.0, 8.0),
	Rect2(380.0, 100.0, 80.0, 8.0),
	# Wall-jump shaft cap.
	Rect2(540.0, 116.0, 96.0, 8.0),
	# Bridge platforms toward the boss arena.
	Rect2(700.0, 132.0, 56.0, 8.0),
	Rect2(820.0, 144.0, 64.0, 8.0),
]

const WALLS: Array[Rect2] = [
	Rect2(540.0, 124.0, 16.0, 56.0),
	Rect2(620.0, 124.0, 16.0, 56.0),
]

const BOUNDS: Array[Rect2] = [
	Rect2(-16.0, 0.0, 16.0, 216.0),
	Rect2(float(STAGE_WIDTH), 0.0, 16.0, 216.0),
]

# Two brutes in the early gauntlet.
const BRUTE_SPAWNS: Array = [
	# [spawn_x, min_x, max_x]
	[230.0, 180.0, 320.0],
	[460.0, 420.0, 520.0],
]

# Kamikaze patrols above the bridge.
const KAMIKAZE_POSITIONS: Array[Vector2] = [
	Vector2(360.0, 60.0),
	Vector2(680.0, 70.0),
]

# Drones overwatching.
const DRONE_PATROLS: Array = [
	# [spawn_x, hover_y, min_x, max_x]
	[480.0, 56.0, 420.0, 540.0],
	[820.0, 64.0, 760.0, 880.0],
]

const TURRET_POSITIONS: Array[Vector2] = [
	Vector2(290.0, 118.0),
	Vector2(420.0, 94.0),
	Vector2(640.0, 110.0),
]

const SPIKE_POSITIONS: Array[Vector2] = [
	Vector2(330.0, 176.0),
	Vector2(500.0, 176.0),
	Vector2(770.0, 176.0),
]

const STAGE_NAME: String = "SECTOR T // THE ARCHITECT"
const STAGE_INTRO_DURATION: float = 2.4
const GOAL_DELAY: float = 3.0

const FADE_IN_DURATION: float = 0.5
const FADE_OUT_DURATION: float = 1.2

var _goal_reached: bool = false
var _transitioning: bool = false
var _hud_layer: CanvasLayer
var _stage_clear_label: Label
var _stage_intro_label: Label
var _fade_rect: ColorRect
var _hp_bar: HpBar
var _player: Player
var _grid_zero: GridZero


func _ready() -> void:
	Game.current_area = "stage_6"
	Music.play("boss")
	_build_static_block(Rect2(0.0, FLOOR_Y, STAGE_WIDTH, FLOOR_HEIGHT), &"Floor")
	for i in PLATFORMS.size():
		_build_static_block(PLATFORMS[i], &"Platform_%d" % i)
	for i in WALLS.size():
		_build_static_block(WALLS[i], &"Wall_%d" % i)
	for i in BOUNDS.size():
		_build_static_block(BOUNDS[i], &"Bound_%d" % i)
	_spawn_player_with_camera()
	_spawn_brutes()
	_spawn_kamikazes()
	_spawn_drones()
	_spawn_turrets()
	_spawn_spikes()
	_spawn_hazards()
	_spawn_heal_station()
	_spawn_hidden_room(80.0, 15)
	_spawn_mechanism_room()
	_spawn_checkpoint()
	_spawn_grid_zero()
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
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font, Vector2(GRID_ZERO_SPAWN.x - 32.0, GRID_ZERO_SPAWN.y - 64.0),
		"GRID-0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GOAL
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


func _spawn_brutes() -> void:
	for entry in BRUTE_SPAWNS:
		var spawn_x: float = entry[0]
		var min_x: float = entry[1]
		var max_x: float = entry[2]
		var brute: Brute = BRUTE_SCENE.instantiate() as Brute
		brute.position = Vector2(spawn_x, 160.0)
		brute.patrol_min_x = min_x
		brute.patrol_max_x = max_x
		Game.apply_difficulty_to_enemy(brute)
		add_child(brute)


func _spawn_kamikazes() -> void:
	for pos in KAMIKAZE_POSITIONS:
		var kami: Kamikaze = KAMIKAZE_SCENE.instantiate() as Kamikaze
		kami.position = pos
		kami.hover_y = pos.y
		kami.patrol_min_x = pos.x - 60.0
		kami.patrol_max_x = pos.x + 60.0
		Game.apply_difficulty_to_enemy(kami)
		add_child(kami)


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
		drone.max_hp = 4
		drone.walk_speed = 70.0
		Game.apply_difficulty_to_enemy(drone)
		add_child(drone)


func _spawn_turrets() -> void:
	for pos in TURRET_POSITIONS:
		var turret: Turret = TURRET_SCENE.instantiate() as Turret
		turret.position = pos
		Game.apply_difficulty_to_enemy(turret)
		add_child(turret)


func _spawn_spikes() -> void:
	for pos in SPIKE_POSITIONS:
		var spike: Spike = SPIKE_SCENE.instantiate() as Spike
		spike.position = pos
		add_child(spike)


func _spawn_heal_station() -> void:
	var station: HealStation = HEAL_STATION_SCENE.instantiate() as HealStation
	station.position = HEAL_STATION_POS
	add_child(station)


# v0.60 hidden room — see stage_2 for the layout shape. Stage 6 hides
# the biggest stash (15 coins) right after the spawn so well-prepared
# players who carry over coins from prior runs get a head-start payoff.
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


# v0.62 — "mechanism room" packs all 4 new elements into the mid-stage
# corridor: a switch+door puzzle, a conveyor belt the player has to fight
# against, a chain of crumbling platforms, and a coin reward beyond the door.
func _spawn_mechanism_room() -> void:
	# --- Switch + Door pair ---
	# Switch sits up on a turret-friendly ledge at (380, 84). Player has
	# to shoot it from the platform at y=100. The door blocks horizontal
	# travel at x=470 (just past the existing turret).
	var switch_panel: SwitchPanel = SWITCH_PANEL_SCENE.instantiate() as SwitchPanel
	switch_panel.position = Vector2(380.0, 84.0)
	add_child(switch_panel)
	var door: DoorGate = DOOR_GATE_SCENE.instantiate() as DoorGate
	door.position = Vector2(470.0, 160.0)
	door.size = Vector2(8.0, 40.0)
	door.open_drop = 40.0
	add_child(door)
	switch_panel.triggered.connect(door.open)

	# --- Conveyor belt — pushes RIGHT to help the player reach the door,
	# placed atop the door's "before" ledge so they don't get pushed past it.
	var conveyor: ConveyorBelt = CONVEYOR_SCENE.instantiate() as ConveyorBelt
	conveyor.position = Vector2(440.0, 152.0)
	conveyor.size = Vector2(48.0, 6.0)
	conveyor.belt_speed = 80.0
	add_child(conveyor)

	# --- Crumbling platform chain — three stepping stones past the door
	# at y=140; each shakes for 0.5s after the player lands, then drops.
	for i in 3:
		var crumb: CrumblingPlatform = CRUMBLING_SCENE.instantiate() as CrumblingPlatform
		crumb.position = Vector2(530.0 + float(i) * 56.0, 140.0)
		crumb.size = Vector2(48.0, 8.0)
		crumb.step_delay = 0.45
		crumb.shake_duration = 0.3
		add_child(crumb)

	# Reward — 6 coins lined up just past the crumbling chain.
	for i in 6:
		var coin: Coin = COIN_SCENE.instantiate() as Coin
		coin.position = Vector2(720.0 + float(i) * 8.0, 100.0)
		add_child(coin)


# v0.59 hazards — one of each new type so the player meets them all
# before the GRID-0 fight.
func _spawn_hazards() -> void:
	# Vertical mover bridging the gap above the wall-jump shaft.
	var mover: MovingPlatform = MOVING_PLATFORM_SCENE.instantiate() as MovingPlatform
	mover.position = Vector2(580.0, 80.0)
	mover.travel = Vector2(0.0, 64.0)
	mover.period = 3.6
	add_child(mover)
	# Pulsing laser blocking the corridor leading to the boss arena.
	var laser: LaserBeam = LASER_BEAM_SCENE.instantiate() as LaserBeam
	laser.position = Vector2(750.0, 144.0)
	laser.size = Vector2(8.0, 64.0)
	laser.period = 2.2
	laser.on_duty = 0.32
	add_child(laser)
	# Crusher over the spike strip near (770, 176) — landing under it
	# during the slam is instant pain.
	var crusher: Crusher = CRUSHER_SCENE.instantiate() as Crusher
	crusher.position = Vector2(680.0, 36.0)
	crusher.slam_distance = 120.0
	crusher.idle_time = 1.6
	add_child(crusher)


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


func _spawn_grid_zero() -> void:
	_grid_zero = GRID_ZERO_SCENE.instantiate() as GridZero
	_grid_zero.position = GRID_ZERO_SPAWN
	Game.apply_difficulty_to_boss(_grid_zero)
	add_child(_grid_zero)
	_grid_zero.died.connect(_on_grid_zero_defeated)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_stage_clear_label = Label.new()
	_stage_clear_label.text = "ARCHITECT FELL"
	_stage_clear_label.add_theme_font_size_override("font_size", 24)
	_stage_clear_label.add_theme_color_override("font_color", COLOR_GOAL)
	_stage_clear_label.position = Vector2(0.0, float(VIEWPORT_H - 56) * 0.5)
	_stage_clear_label.size = Vector2(VIEWPORT_W, 56)
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
	Game.add_hard_mode_hud_label(_hud_layer)

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


func _on_grid_zero_defeated() -> void:
	if _goal_reached:
		return
	_goal_reached = true
	_transitioning = true
	Game.architect_cleared = true
	var is_new_best: bool = Game.register_clear("stage_6")
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
	Game.return_to_base_or_title("stage_6", true)

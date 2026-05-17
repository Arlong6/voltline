## Voltline — Stage 9 // FAULTLINE.
##
## Post-Circuit multi-room stage built around purple-black rift geometry,
## staggered laser pressure, and the teleporting VEIN-K boss.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const STAGE_WIDTH: int = 1280

const FLOOR_Y: int = 180
const FLOOR_HEIGHT: int = 36

const COLOR_BG: Color = Color("#050214")
const COLOR_GROUND: Color = Color("#14081E")
const COLOR_PLATFORM: Color = Color("#4A2A6A")
const COLOR_WALL: Color = Color("#1F0A2E")
const COLOR_SEPARATOR: Color = Color("#7A3AC0")
const COLOR_GOAL: Color = Color("#F040FF")
const COLOR_TEXT: Color = Color("#D080FF")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const LANCER_SCENE: PackedScene = preload("res://scenes/lancer.tscn")
const STALKER_SCENE: PackedScene = preload("res://scenes/stalker.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/checkpoint.tscn")
const LASER_SCENE: PackedScene = preload("res://scenes/laser_beam.tscn")
const CRUMBLING_PLATFORM_SCENE: PackedScene = preload("res://scenes/crumbling_platform.tscn")
const SWITCH_SCENE: PackedScene = preload("res://scenes/switch_panel.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/door_gate.tscn")
const VEIN_K_SCENE: PackedScene = preload("res://scenes/vein_k.tscn")

const PLAYER_SPAWN: Vector2 = Vector2(40.0, 160.0)
const CHECKPOINT_POS: Vector2 = Vector2(720.0, 180.0)
const BOSS_SPAWN: Vector2 = Vector2(1090.0, 156.0)
const BOSS_AREA: Array[Vector2] = [
	Vector2(1000.0, 156.0),
	Vector2(1180.0, 156.0),
	Vector2(1090.0, 100.0),
]

const ROOM_A_LOW_CEILING: Rect2 = Rect2(200.0, 138.0, 130.0, 8.0)
const ROOM_A_LANCERS: Array[Vector4] = [
	Vector4(150.0, 168.0, 90.0, 250.0),
	Vector4(360.0, 168.0, 280.0, 430.0),
]
const ROOM_A_SWITCH_POS: Vector2 = Vector2(420.0, 104.0)
const ROOM_A_DOOR_POS: Vector2 = Vector2(450.0, 160.0)
const SEPARATOR_AB: Rect2 = Rect2(442.0, 16.0, 16.0, 144.0)

const ROOM_B_STALKER_A_POS: Vector2 = Vector2(560.0, 78.0)
const ROOM_B_STALKER_B_POS: Vector2 = Vector2(740.0, 86.0)
const ROOM_B_STALKER_A_HOVER: float = -58.0
const ROOM_B_STALKER_B_HOVER: float = -64.0
const ROOM_B_LASER_A_POS: Vector2 = Vector2(600.0, 144.0)
const ROOM_B_LASER_B_POS: Vector2 = Vector2(690.0, 144.0)
const ROOM_B_LASER_SIZE: Vector2 = Vector2(8.0, 72.0)
const ROOM_B_LASER_PERIOD: float = 2.0
const ROOM_B_LASER_DUTY: float = 0.35
const ROOM_B_LASER_PHASE: float = 1.0
const ROOM_B_CRUMBLE_POS: Vector2 = Vector2(805.0, 126.0)
const ROOM_B_CRUMBLE_SIZE: Vector2 = Vector2(54.0, 8.0)
const ROOM_B_SWITCH_POS: Vector2 = Vector2(850.0, 94.0)
const ROOM_B_DOOR_POS: Vector2 = Vector2(890.0, 160.0)
const SEPARATOR_BC: Rect2 = Rect2(882.0, 16.0, 16.0, 144.0)

const BOUNDS: Array[Rect2] = [
	Rect2(-16.0, 0.0, 16.0, 216.0),
	Rect2(float(STAGE_WIDTH), 0.0, 16.0, 216.0),
]

const STAGE_NAME: String = "SECTOR 9 // FAULTLINE"
const STAGE_CLEAR_TEXT: String = "FAULTLINE SEALED"
const BOSS_NAME_TEXT: String = "VEIN-K"
const ROOM_A_LABEL: String = "A · RIFT"
const ROOM_B_LABEL: String = "B · STATIC"
const ROOM_C_LABEL: String = "C · FAULT"
const CURRENT_AREA: String = "stage_9"
const TITLE_LEVEL: String = "title"
const STAGE_KEY: String = "stage_9"
const BOSS_MUSIC: String = "boss"
const GOAL_SFX: String = "goal"

const STAGE_INTRO_DURATION: float = 2.4
const GOAL_DELAY: float = 3.0
const FADE_IN_DURATION: float = 0.5
const FADE_OUT_DURATION: float = 1.2
const CAMERA_SMOOTH_SPEED: float = 8.0
const HUD_LAYER: int = 10
const CLEAR_FONT_SIZE: int = 24
const INTRO_FONT_SIZE: int = 14
const LABEL_FONT_SIZE: int = 10
const BOSS_FONT_SIZE: int = 12
const HP_BAR_WIDTH: float = 140.0
const HP_BAR_HEIGHT: float = 12.0
const HUD_MARGIN: float = 8.0
const COIN_X: float = 320.0
const COIN_WIDTH: float = 60.0
const SPEEDRUN_Y: float = 18.0
const SPEEDRUN_HEIGHT: float = 24.0
const BUFF_Y: float = 24.0
const BUFF_WIDTH: float = 300.0
const BUFF_HEIGHT: float = 14.0
const CLEAR_LABEL_Y: float = 80.0
const CLEAR_LABEL_HEIGHT: float = 56.0
const INTRO_Y: float = 30.0
const INTRO_HEIGHT: float = 24.0
const ROOM_LABEL_Y: float = 28.0
const ROOM_A_LABEL_X: float = 120.0
const ROOM_B_LABEL_X: float = 620.0
const ROOM_C_LABEL_X: float = 1020.0
const ROOM_LABEL_OFFSET_X: float = 30.0
const BOSS_LABEL_OFFSET: Vector2 = Vector2(-30.0, -56.0)
const DOOR_SIZE: Vector2 = Vector2(8.0, 40.0)
const DOOR_OPEN_DROP: float = 40.0

var _goal_reached: bool = false
var _transitioning: bool = false
var _hud_layer: CanvasLayer
var _stage_clear_label: Label
var _stage_intro_label: Label
var _fade_rect: ColorRect
var _hp_bar: HpBar
var _player: Player
var _boss: VeinK


func _ready() -> void:
	Game.current_area = CURRENT_AREA
	Music.play(BOSS_MUSIC)
	_build_static_block(Rect2(0.0, float(FLOOR_Y), float(STAGE_WIDTH), float(FLOOR_HEIGHT)), &"Floor")
	for i in BOUNDS.size():
		_build_static_block(BOUNDS[i], &"Bound_%d" % i)
	_build_separator(SEPARATOR_AB, &"SeparatorAB")
	_build_separator(SEPARATOR_BC, &"SeparatorBC")
	_build_static_block(ROOM_A_LOW_CEILING, &"RoomA_LowCeiling")
	_spawn_player_with_camera()
	_spawn_room_a()
	_spawn_room_b()
	_spawn_checkpoint()
	_spawn_boss()
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
				Game.goto_level(TITLE_LEVEL)
		)


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, float(STAGE_WIDTH), float(VIEWPORT_H)), COLOR_BG)
	draw_rect(Rect2(0.0, float(FLOOR_Y), float(STAGE_WIDTH), float(FLOOR_HEIGHT)), COLOR_GROUND)
	draw_rect(ROOM_A_LOW_CEILING, COLOR_PLATFORM)
	draw_rect(SEPARATOR_AB, COLOR_SEPARATOR)
	draw_rect(SEPARATOR_BC, COLOR_SEPARATOR)
	var font: Font = ThemeDB.fallback_font
	_label(ROOM_A_LABEL, ROOM_A_LABEL_X, font)
	_label(ROOM_B_LABEL, ROOM_B_LABEL_X, font)
	_label(ROOM_C_LABEL, ROOM_C_LABEL_X, font)
	draw_string(
		font, BOSS_SPAWN + BOSS_LABEL_OFFSET,
		BOSS_NAME_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, BOSS_FONT_SIZE, COLOR_GOAL
	)


func _label(text: String, x_centre: float, font: Font) -> void:
	draw_string(font, Vector2(x_centre - ROOM_LABEL_OFFSET_X, ROOM_LABEL_Y),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, COLOR_TEXT)


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


func _build_separator(rect: Rect2, body_name: StringName) -> void:
	_build_static_block(rect, body_name)


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
	camera.position_smoothing_speed = CAMERA_SMOOTH_SPEED
	_player.add_child(camera)
	camera.make_current()


func _spawn_room_a() -> void:
	for entry in ROOM_A_LANCERS:
		var lancer: Lancer = LANCER_SCENE.instantiate() as Lancer
		lancer.position = Vector2(entry.x, entry.y)
		lancer.patrol_min_x = entry.z
		lancer.patrol_max_x = entry.w
		add_child(lancer)
	var switch_panel: SwitchPanel = SWITCH_SCENE.instantiate() as SwitchPanel
	switch_panel.position = ROOM_A_SWITCH_POS
	add_child(switch_panel)
	var door: DoorGate = DOOR_SCENE.instantiate() as DoorGate
	door.position = ROOM_A_DOOR_POS
	door.size = DOOR_SIZE
	door.open_drop = DOOR_OPEN_DROP
	add_child(door)
	switch_panel.triggered.connect(door.open)


func _spawn_room_b() -> void:
	var stalker_a: Stalker = STALKER_SCENE.instantiate() as Stalker
	stalker_a.position = ROOM_B_STALKER_A_POS
	stalker_a.hover_offset_y = ROOM_B_STALKER_A_HOVER
	add_child(stalker_a)
	var stalker_b: Stalker = STALKER_SCENE.instantiate() as Stalker
	stalker_b.position = ROOM_B_STALKER_B_POS
	stalker_b.hover_offset_y = ROOM_B_STALKER_B_HOVER
	add_child(stalker_b)

	var laser_a: LaserBeam = LASER_SCENE.instantiate() as LaserBeam
	laser_a.position = ROOM_B_LASER_A_POS
	laser_a.size = ROOM_B_LASER_SIZE
	laser_a.period = ROOM_B_LASER_PERIOD
	laser_a.on_duty = ROOM_B_LASER_DUTY
	add_child(laser_a)
	var laser_b: LaserBeam = LASER_SCENE.instantiate() as LaserBeam
	laser_b.position = ROOM_B_LASER_B_POS
	laser_b.size = ROOM_B_LASER_SIZE
	laser_b.period = ROOM_B_LASER_PERIOD
	laser_b.on_duty = ROOM_B_LASER_DUTY
	laser_b.phase = ROOM_B_LASER_PHASE
	add_child(laser_b)

	var crumble: CrumblingPlatform = CRUMBLING_PLATFORM_SCENE.instantiate() as CrumblingPlatform
	crumble.position = ROOM_B_CRUMBLE_POS
	crumble.size = ROOM_B_CRUMBLE_SIZE
	crumble.color = COLOR_PLATFORM
	add_child(crumble)

	var switch_panel: SwitchPanel = SWITCH_SCENE.instantiate() as SwitchPanel
	switch_panel.position = ROOM_B_SWITCH_POS
	add_child(switch_panel)
	var door: DoorGate = DOOR_SCENE.instantiate() as DoorGate
	door.position = ROOM_B_DOOR_POS
	door.size = DOOR_SIZE
	door.open_drop = DOOR_OPEN_DROP
	add_child(door)
	switch_panel.triggered.connect(door.open)


func _spawn_checkpoint() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.position = CHECKPOINT_POS
	add_child(checkpoint)


func _spawn_boss() -> void:
	_boss = VEIN_K_SCENE.instantiate() as VeinK
	_boss.position = BOSS_SPAWN
	_boss.teleport_anchors = BOSS_AREA
	add_child(_boss)
	_boss.died.connect(_on_boss_defeated)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = HUD_LAYER
	add_child(_hud_layer)

	_stage_clear_label = Label.new()
	_stage_clear_label.text = STAGE_CLEAR_TEXT
	_stage_clear_label.add_theme_font_size_override("font_size", CLEAR_FONT_SIZE)
	_stage_clear_label.add_theme_color_override("font_color", COLOR_GOAL)
	_stage_clear_label.position = Vector2(0.0, CLEAR_LABEL_Y)
	_stage_clear_label.size = Vector2(float(VIEWPORT_W), CLEAR_LABEL_HEIGHT)
	_stage_clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_clear_label.visible = false
	_hud_layer.add_child(_stage_clear_label)

	_stage_intro_label = Label.new()
	_stage_intro_label.text = STAGE_NAME
	_stage_intro_label.add_theme_font_size_override("font_size", INTRO_FONT_SIZE)
	_stage_intro_label.add_theme_color_override("font_color", COLOR_TEXT)
	_stage_intro_label.position = Vector2(0.0, INTRO_Y)
	_stage_intro_label.size = Vector2(float(VIEWPORT_W), INTRO_HEIGHT)
	_stage_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_stage_intro_label)

	_hp_bar = HpBar.new()
	_hp_bar.player = _player
	_hp_bar.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	_hp_bar.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hud_layer.add_child(_hp_bar)

	var coins: CoinCounter = CoinCounter.new()
	coins.position = Vector2(COIN_X, HUD_MARGIN)
	coins.size = Vector2(COIN_WIDTH, HP_BAR_HEIGHT)
	_hud_layer.add_child(coins)

	var spd_timer: SpeedrunTimer = SpeedrunTimer.new()
	spd_timer.position = Vector2(COIN_X, SPEEDRUN_Y)
	spd_timer.size = Vector2(COIN_WIDTH, SPEEDRUN_HEIGHT)
	_hud_layer.add_child(spd_timer)

	var buff_hud: BuffHud = BuffHud.new()
	buff_hud.position = Vector2(HUD_MARGIN, BUFF_Y)
	buff_hud.size = Vector2(BUFF_WIDTH, BUFF_HEIGHT)
	_hud_layer.add_child(buff_hud)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = Vector2(float(VIEWPORT_W), float(VIEWPORT_H))
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
	Game.faultline_cleared = true
	var is_new_best: bool = Game.register_clear(STAGE_KEY)
	_stage_clear_label.text = "%s\n%s" % [
		_stage_clear_label.text,
		Game.format_score_summary(is_new_best)
	]
	_stage_clear_label.visible = true
	Sfx.play(GOAL_SFX)
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
	Game.return_to_base_or_title(STAGE_KEY, true)

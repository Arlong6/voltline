## v0.69 — VEIN-K teleport and fissure mine tests.
extends GutTest

const VEIN_K_SCRIPT: GDScript = preload("res://scripts/vein_k.gd")
const FISSURE_MINE_SCRIPT: GDScript = preload("res://scripts/fissure_mine.gd")

const ANCHOR_A: Vector2 = Vector2(100.0, 100.0)
const ANCHOR_B: Vector2 = Vector2(200.0, 100.0)
const ANCHOR_C: Vector2 = Vector2(150.0, 50.0)
const ANCHORS: Array[Vector2] = [ANCHOR_A, ANCHOR_B, ANCHOR_C]
const PHASE_1_DRIVE_TIME: float = 2.6
const PHASE_2_DRIVE_TIME: float = 1.85
const PHASE_3_DRIVE_TIME: float = 1.25
const MINE_WAIT_TIME: float = 0.65
const PHASE_2_HP: int = 50
const PHASE_3_HP: int = 20
const RADIAL_8_COUNT: int = 8
const RADIAL_4_COUNT: int = 4
const VELOCITY_EPSILON: float = 0.001

var container: Node2D
var boss: VeinK


# Container isolation — Boss / FissureMine call `get_parent().add_child(bullet)`
# when they fire, so bullets end up as siblings of the boss. If the test root
# (self) is that parent, those bullets persist across tests because
# add_child_autofree only registers the boss, not its spawned bullets. Each
# test gets a fresh Node2D container instead; autofreeing the container frees
# every bullet / mine / ghost it ever spawned.
func before_each() -> void:
	Game.test_mode = true
	container = Node2D.new()
	add_child_autofree(container)
	boss = VEIN_K_SCRIPT.new() as VeinK
	boss.teleport_anchors = ANCHORS
	boss.global_position = ANCHOR_A
	container.add_child(boss)


func after_each() -> void:
	Game.test_mode = false


func test_teleport_advances_anchor_on_interval() -> void:
	boss.tick_teleport(PHASE_1_DRIVE_TIME)
	assert_eq(boss.global_position, ANCHOR_B,
		"after the phase-1 interval VEIN-K should warp to the next anchor")


func test_phase_2_radial_burst_on_appear() -> void:
	boss.hp = PHASE_2_HP
	boss.tick_teleport(PHASE_2_DRIVE_TIME)
	assert_eq(_enemy_bullet_count(container), RADIAL_8_COUNT,
		"phase 2 should fire an 8-way radial burst on appear")


func test_phase_3_drops_fissure_mine_on_leave() -> void:
	boss.hp = PHASE_3_HP
	boss.tick_teleport(PHASE_3_DRIVE_TIME)
	var mine: FissureMine = _first_mine(container)
	assert_not_null(mine,
		"phase 3 should leave a fissure mine at the anchor VEIN-K just left")
	if mine != null:
		assert_eq(mine.global_position, ANCHOR_A)


func test_fissure_mine_explodes_into_four_directions() -> void:
	# Free the before_each boss so its idle _physics_process doesn't tick
	# the teleport timer during this test's wait — we only want the mine
	# to spawn bullets into the container.
	boss.queue_free()
	await get_tree().process_frame
	var mine: FissureMine = FISSURE_MINE_SCRIPT.new() as FissureMine
	mine.global_position = ANCHOR_C
	container.add_child(mine)
	await get_tree().create_timer(MINE_WAIT_TIME).timeout
	assert_eq(_enemy_bullet_count(container), RADIAL_4_COUNT,
		"fissure mine should spawn four cardinal bullets")
	assert_true(_has_bullet_direction(Vector2.UP))
	assert_true(_has_bullet_direction(Vector2.DOWN))
	assert_true(_has_bullet_direction(Vector2.LEFT))
	assert_true(_has_bullet_direction(Vector2.RIGHT))


func _enemy_bullet_count(parent: Node) -> int:
	var count: int = 0
	for child in parent.get_children():
		if child is EnemyBullet:
			count += 1
	return count


func _first_mine(parent: Node) -> FissureMine:
	for child in parent.get_children():
		if child is FissureMine:
			return child
	return null


func _has_bullet_direction(direction: Vector2) -> bool:
	for child in container.get_children():
		if child is EnemyBullet:
			var bullet: EnemyBullet = child as EnemyBullet
			var actual: Vector2 = bullet.velocity.normalized()
			if actual.distance_to(direction) <= VELOCITY_EPSILON:
				return true
	return false

## v0.62 — CrumblingPlatform 5-phase state machine.
##
## Drives tick(delta, player_on) directly with synthesized inputs so the
## state transitions can be observed without a Player in the scene.
extends GutTest

const CRUMB_SCRIPT: GDScript = preload("res://scripts/crumbling_platform.gd")
const FRAME: float = 0.016

var crumb: CrumblingPlatform


func before_each() -> void:
	Game.test_mode = true
	crumb = CRUMB_SCRIPT.new()
	add_child_autofree(crumb)


func after_each() -> void:
	Game.test_mode = false


func test_starts_in_stable_phase() -> void:
	assert_eq(crumb._phase, CrumblingPlatform.Phase.STABLE,
		"crumbling platform starts STABLE")


func test_player_landing_arms_the_platform() -> void:
	crumb.tick(FRAME, true)
	assert_eq(crumb._phase, CrumblingPlatform.Phase.ARMED,
		"player_on=true on a STABLE platform should advance to ARMED")


func test_armed_to_shaking_after_step_delay() -> void:
	crumb.step_delay = 0.2
	crumb.tick(FRAME, true)  # → ARMED
	var elapsed: float = 0.0
	while elapsed < crumb.step_delay + FRAME:
		crumb.tick(FRAME, true)
		elapsed += FRAME
	assert_eq(crumb._phase, CrumblingPlatform.Phase.SHAKING,
		"after step_delay elapsed, ARMED should advance to SHAKING")


func test_shaking_to_falling_after_shake_duration() -> void:
	crumb.step_delay = 0.0
	crumb.shake_duration = 0.1
	crumb.tick(FRAME, true)  # STABLE → ARMED
	# Burn through ARMED (step_delay=0 means single tick).
	crumb.tick(FRAME, true)  # ARMED → SHAKING
	var elapsed: float = 0.0
	while elapsed < crumb.shake_duration + FRAME:
		crumb.tick(FRAME, true)
		elapsed += FRAME
	assert_eq(crumb._phase, CrumblingPlatform.Phase.FALLING,
		"after shake_duration elapsed, SHAKING should advance to FALLING")


func test_falling_drops_collision_layer() -> void:
	crumb.step_delay = 0.0
	crumb.shake_duration = 0.0
	crumb.tick(FRAME, true)  # STABLE → ARMED
	crumb.tick(FRAME, true)  # ARMED → SHAKING (transition at end of tick)
	crumb.tick(FRAME, true)  # SHAKING → FALLING (transition at end of tick)
	crumb.tick(FRAME, true)  # FALLING branch runs → collision_layer cleared
	assert_eq(crumb.collision_layer, 0,
		"falling platform should drop collision_layer to 0 (player can't land)")

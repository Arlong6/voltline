# Voltline — Story Index

Weekend-scale MVP. One character, one stage, one boss. ColorRect art.

| ID | Title | Type | Tests | Status |
|---|---|---|---|---|
| **V-001** | Project skeleton (autoload, title, stage stub) | Setup | smoke | ✅ shipped (v0.1) |
| V-002 | Player controller — walk + jump + gravity + ground collision | Logic | unit BLOCKING | TODO |
| V-003 | Buster shot — single-fire X-bullet, despawn off-screen | Logic | unit BLOCKING | TODO |
| V-004 | Dash — tap C, ~14 frames of horizontal burst, no air-dash | Logic | unit BLOCKING | TODO |
| V-005 | Wall slide + wall jump — touch wall while falling, jump kicks off | Logic | unit BLOCKING | TODO |
| V-006 | Charge shot — hold X, release for bigger bullet | Logic | unit | TODO |
| V-007 | First stage layout — platforms, gaps, wall-jump section | Integration | walkthrough | TODO |
| V-008 | Basic enemy — patrolling sweeper with 1-hit kill on contact | Logic | unit BLOCKING | TODO |
| V-009 | Player HP + respawn — 16 HP, hit knockback, respawn at checkpoint | Logic | unit BLOCKING | TODO |
| V-010 | Boss room — gate triggers, boss intro, health bars | Integration | walkthrough | TODO |
| V-011 | Boss pattern — jumps + bullet spread + dash attack | Logic | unit | TODO |
| V-012 | Stage clear — boss explosion, victory screen, return to title | UI | walkthrough | TODO |

Total: ~14 hours across V-002 → V-012. Realistic 2-3 day weekend.

## Out-of-Scope for v1.0 (defer to later)

- Multiple characters (Zero, Axl)
- Special weapons learned from bosses
- Stage-select screen (always boots straight into stage_1)
- Real sprite art / animations beyond 2-frame walk cycle
- Audio (SFX + music)
- Ride armor, navigator, save points

# Implementation plan

**Baseline (merged in PR #1):**
- A garage where you build vehicles from parts like Lego.
- One-body vehicle physics: raycast wheels, propellers, buoyancy.
- A test map.
- One delivery mission with medals and saved best times.

This plan compares that baseline with `spec/architecture.md` and `spec/game-mechanics.md`, and orders the remaining work so the game stays playable after every step.

**Agent labels on issues:**
- `vision-required`: checking the work means looking at rendered output. Use a vision-capable agent and the screenshot tooling from #4.
- `no-vision`: verifiable from test numbers and logs.

## Where the baseline stands against the spec

| Spec / architecture piece | Status | Issues |
|---|---|---|
| Part Catalog (data-driven) | Done: `data/parts.json` | thin parts #10, fuel #7, wing #8, spring #9 |
| Blueprints (save, load, share) | Save and load done | sharing codes #29 |
| Garage editor | Place, remove, rotate, undo, stats | mirror #5, gamepad #11, centre-of-mass/thrust visualisation #12, shop #22 |
| Input Mapper (accessory buttons) | Not started | #9 |
| Vehicle Graph / Assembly Compiler | Implicit: one body per vehicle | explicit graph and islands #13 |
| Force Model | Wheels, propellers (weak in air), water | power budget #6, wings #8 |
| Damage & Repair | Not started | #14, wrench #25 |
| Joints (only where things move) | Not started | hinge and detacher #15 |
| Rust core (gdext) | Deliberately deferred | measure first #16 |
| Challenge Director and rulesets | One delivery mission | framework #17, race #18, sports #19, UX #20 |
| Reward Tiers | Done (gold, silver, bronze, best time) | payouts #21 |
| Progression & Economy | Not started | #21, #22 |
| Hub & Worlds, acts | Test map only | hub #23, first world #24 |
| On-foot character | Not started | #25 |
| Multiplayer | Later | design spike #30 |
| Agent and CI tooling | Manual test scripts | #2, #3, #4 |

## Phases

Each phase leaves the game playable. Within a phase, issues are mostly independent unless a dependency is noted.

### Phase 0: Foundations for agents (do first)
| # | Issue | Vision? |
|---|---|---|
| #2 | Tests fail loudly: assertions, exit codes, `run_all.sh` | no |
| #3 | CI on every PR (needs #2) | no |
| #4 | Screenshot tool with camera presets for visual review | **yes** |

### Phase 1: Deeper building (more ways to solve things)
| # | Issue | Vision? |
|---|---|---|
| #5 | Garage mirror mode | no |
| #6 | Engine power budget shared by wheels and propellers | no |
| #7 | Fuel tank and fuel use (done; fuel scales with throttle until #6) | no |
| #8 | Wing part: lift and drag, first flights | no |
| #9 | Accessory buttons (Input Mapper) and Spring part | **yes** |
| #10 | Thin parts: plate, wall, tray (carry cargo) | no |
| #11 | Garage gamepad support | **yes** |
| #12 | Garage centre-of-mass marker, thrust arrows, hover highlight, part info | **yes** |

### Phase 2: Vehicle core (architecture)
| # | Issue | Vision? |
|---|---|---|
| #13 | Split into VehicleGraph, AssemblyCompiler, ForceModel (no behaviour change) | no |
| #14 | Damage and repair: break edges, split islands (needs #13) | no |
| #15 | Hinge and Detacher joints (needs #13) | no |
| #16 | Spike: Rust/gdext or stay in GDScript? Measure (needs #13) | no |

### Phase 3: Challenges
| # | Issue | Vision? |
|---|---|---|
| #17 | Challenge Director base class, rulesets, part budget | no |
| #18 | Racing: checkpoints and laps (needs #17) | **yes** |
| #19 | Sports: ball into goal (needs #17) | **yes** |
| #20 | Mission briefing, results and retry UX | **yes** |

### Phase 4: Progression and world
| # | Issue | Vision? |
|---|---|---|
| #21 | Currency from medals, part unlocks, save v2 | no |
| #22 | Garage shop UI (needs #21) | **yes** |
| #23 | Hub world with a designated hub vehicle (needs #17, #21) | **yes** |
| #24 | First real world with acts (needs #17, #23) | **yes** |

### Phase 5: Character and polish
| # | Issue | Vision? |
|---|---|---|
| #25 | On-foot character and repair wrench | **yes** |
| #26 | Visual polish: water, materials, effects | **yes** |
| #27 | Audio | no (judged by ear on real hardware) |
| #28 | Chase camera: avoid walls, orbit, look back | **yes** |
| #29 | Blueprint sharing codes | no |

### Later
| # | Issue | Vision? |
|---|---|---|
| #30 | Multiplayer design spike (server-authoritative) | no |

## Suggested order for a weekend hackathon

1. **#2 → #3.** Then every later change gets a safety net.
2. **#5, #6, #8.** Mirror mode, a fair power budget and wings are the most fun for the least work. Planes!
3. **#13 → #14.** Smashing vehicles apart is the next big "wow".
4. **#17 → #18.** A second challenge type, so the build → test → reward loop has variety.
5. Then pick from Phase 4 or 5 depending on what the young playtester asks for.

`vision-required` issues pair well with a human. The developers have real hardware, and the container's renderer makes everything look flatter.

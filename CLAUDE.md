# ZERO PRESSURE — project execution instructions (user-approved)

The owner has explicitly ordered the next development batch to be executed **strictly in P0 → P1 → P2 → P3 sequence**, not merely reviewed or written up.

**Before starting new code work, read and execute:**

- `design/78_用户最终执行顺序_P0-P3_2026-10-26.md` — authoritative, detailed current work order with implementation and verification requirements.
- `design/TODO.md` — associated task checklist and known bugs.
- `design/船型差异化_七种拆解体验与核心资产_2026-10-26_待评审.md` and `design/用户追加决策_船型核心资产材料系统与范围磁力钩爪_2026-10-26.md` — approved mechanics, materials, visual-physics and multi-grapple requirements.

Current first task **P0-1**: diagnose and fix M-14, RO-128, SV-122, SA-200 salvage-bot timeouts, SA-200 >100% valuation, and drones routing oversized pieces to undersized recovery mouths. Small-mouth routing is a hypothesis for the value bug, not proven causation. **P0-2**: make ARK-01 player-only/manual salvage, disallow automation in code and tests. Subsequent steps are detailed in the work order. Do not switch to G7 production until this batch is completed.

G6.3 and G6.4 major features, 45 regression tests, and their EXE have already been built on 2026-10-26. Do not redo them unless fixing verified defects. **Ship design changes now require actual implementation rather than another review-only response.** Continue independently through ordinary implementation decisions, report verifiable tests, screenshots, files changed and blockers at each milestone. Keep the owner's 2D minimalist black-and-white industrial style. Narrative and character dialogue are authored by the owner; preserve placeholders rather than inventing official text.


## 2026-10-27 14:10 User override: 60 FPS is a RELEASE BLOCKER
The owner explicitly requires stable 60+ FPS in this minimalist 2D game, *not* 30 FPS during ordinary heavy dismantling. Current 87-7 `perf_stress_check.gd` permits under 40 ms and reports 16.9 ms berth idle, 26.5 ms for 250 pieces, 33.7 ms for group grapple + 30 ropes, ~20 ms ARK-01: NOT PASSING. Do not mark 87-7 or release as finished based on existing PASS logs. Read the new exact requirements appended at the end of `design/TODO.md`: measure actual on-screen presented frames on 550w (Ryzen 7 5800X/GTX1080) at real 1080p, P95/P99, 1% low, scene transition frame stutters, input latency, realistic stress; optimize collision/rope/draw/load to preserve actual physics, benchmark again; visually polish industrial depth and effects while staying minimalist; fix separately reported tow-bay-to-salvage-bay clipping through station and legacy test failures. This overrides weaker 87-7 acceptance and the mere existence of an EXE. Do not claim success until proven with objective evidence; log blockers and questions for owner.

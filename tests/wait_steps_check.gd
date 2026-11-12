extends SceneTree
# 等待步骤 (2026-11-11, user on MF-126: "这个引导，他要我干啥呀？为什么一直要我下去，一直要我标中间那个东西
# 啊？然后呢，给我一个提示啊！"): a step that is only waiting (the core cooling, a flywheel spinning down, a
# capacitor bleeding…) says so plainly with the time left, the mark goes to something that can be done
# meanwhile, and the TASK card carries the words. MF-126 first: while the core cools the next step is not the
# core, the card has text, and at 150 °C the step is the core again ("可以取炉芯了"). Then a look at the
# other waiting ships. Shots before/after in tests/out/wait_steps/.
#   tools/run_test.sh tests/wait_steps_check.gd --fixed-fps 60   (-- --before: NextStep.WAIT_ON off)

const CoreAsset = preload("res://scripts/core_asset.gd")
var fails := 0
var checks := 0
var before := false


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Txt.hint_tier = "standard"
	SaveGame.path = "user://zp_test_wait_steps_save.json"
	SaveGame.allow_test = true
	before = OS.get_cmdline_user_args().has("--before")
	if before:
		NextStep.WAIT_ON = false
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _start(ship: String) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	SaveGame.load_requested = false
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	return g


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out/wait_steps"))
	img.save_png("res://tests/out/wait_steps/%s%s.png" % [name, "_before" if before else ""])


# the steps followed the way a hand would (tests/batch2_check.gd), the old pace, until one is only a wait
func _to_wait(g) -> Dictionary:
	NextStep.WAIT_ON = false
	NextStep.PACE_ON = false
	var out := {}
	for i in 60:
		var st := NextStep.of(g)
		if st.is_empty():
			break
		if st.get("wait", false):
			out = st
			break
		var id := ""
		for c in g.world.ctrls:
			if str(st.t).find(str(c)) >= 0 and str(c).length() > id.length():
				id = str(c)
		if id == "":
			break
		var c = g.world.ctrls[id]
		if str(st.t).find("拔掉") >= 0:
			g.sys.hoses.erase(id)
		elif c.kind == "port":
			var tg := str(c.target)
			if g.sys.vols.has(tg):
				g.sys.vols[tg].n = 0.0
			if g.sys.fvol.has(tg):
				g.sys.hoses[id] = {"mode": "recover", "t": 0.0}
				await _frames(120)
		else:
			g._operate(c, g.world.ctrl_world(c))
		await _frames(110 if c.kind in ["door", "hatch"] else 8)
	NextStep.PACE_ON = true
	NextStep.WAIT_ON = not before
	await _frames(200)    # the wait's figure has moved: its time can be told
	return out


func _run() -> void:
	var g := _start("mf126")
	await _frames(40)
	var fu = g.furnace
	var core: String = str(fu.cfg.get("core", ""))
	var core_at: Vector2 = NextStep._tag_at(g, core)
	var st := NextStep.of(g)
	print("  mf126 %.0f °C · has %s · board %s · step %s | %s | wait %s | bg %s" % [fu.core_temp(), CoreAsset.has(g), not CoreAsset.board(g).is_empty(), st.get("t", ""), st.get("how", ""), st.get("wait", false), str(st.get("bg", []))])
	g.drone.global_position = core_at + Vector2(0, -8.0) * Geom.M
	await _frames(30)
	await _shot("mf126_cooling")
	var hud = g.hud
	check(not CoreAsset.board(g).is_empty(), "mf126: the TASK card has its board (the next step's words on it)")
	check(str(st.get("t", "")) != "", "mf126: the step has words (%s)" % st.get("t", ""))
	if not before:
		check(not st.get("wait", false) and (st.at as Vector2).distance_to(core_at) > 1.0 * Geom.M, "mf126 cooling: the mark is on something to do meanwhile, not the core (%s)" % st.get("t", ""))
		var bg: Array = st.get("bg", [])
		check(bg.any(func(b): return str(b.t).find("冷却") >= 0 and str(b.t).find("预计") >= 0), "mf126 cooling: the core's countdown in the background (%s)" % str(bg))
	# the blueprint open (the user's shot): the panels slide away, the step stays in the TASK frame
	g.blueprint.toggle()
	await _frames(50)
	await _shot("mf126_blueprint")
	g.blueprint.toggle()
	await _frames(30)
	# cooled: the core again
	fu.T = float(fu.cfg.get("safe", 150.0)) - 1.0
	await _frames(4)
	var st2 := NextStep.of(g)
	print("  mf126 cooled: %s | %s" % [st2.get("t", ""), st2.get("how", "")])
	await _frames(20)
	await _shot("mf126_cooled")
	if not before:
		check(str(st2.get("t", "")).find("炉芯") >= 0, "mf126 cooled: back to the core (%s)" % st2.get("t", ""))
	g.queue_free()
	await _frames(4)
	# the other waiting ships: each one's wait, if it comes up in the first steps, says so and points elsewhere
	for ship in ["fx70", "md160", "ev55", "tb180", "nr95"]:
		var g2 := _start(ship)
		await _frames(40)
		var raw := await _to_wait(g2)
		if raw.is_empty():
			print("  %s: no wait in its first steps" % ship)
		else:
			NextStep.WAIT_ON = not before
			var now := NextStep.of(g2)
			print("  %s wait: %s | now: %s | %s | bg %s" % [ship, raw.t, now.get("t", ""), now.get("how", ""), str(now.get("bg", []))])
			await _shot(ship + "_wait")
			check(str(now.get("t", "")) != "", "%s: the step has words while it waits" % ship)
			if not before:
				var moved: bool = not now.get("wait", false) and (now.get("bg", []) as Array).any(func(b): return b.kind == "wait")
				var said: bool = now.get("wait", false) and str(now.get("how", "")).find("可以先处理其他工作") >= 0
				check(moved or said, "%s: something to do meanwhile (the wait in the background), or plainly only a wait" % ship)
		g2.queue_free()
		await _frames(4)
	print("WAIT STEPS %s (%d checks, %d failed)%s" % ["PASS" if fails == 0 else "FAIL", checks, fails, " [before]" if before else ""])
	quit()

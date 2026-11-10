extends SceneTree
# 128 号 第 7 段: 新手全流程验收. A fresh career played from TUG-001 to the fifth hulk by the game's
# own controls: the drone flown with the movement keys (no warps), E / B / F3 / Enter / Esc pressed
# as keys, the buttons on the pages pressed, the shuttle ridden; the hulks stripped by the salvage
# bot (paced, as a player would). Only what the guidance on screen says is done when it says
# something; where it says nothing the bot falls back on what a player would have to know, and logs
# that as a finding. Each step is shot to tests/out/seg7_*.png and logged with: how many voices and
# target marks are on screen, the chapter, the step's words; every wait over 5 s (where, how long,
# why). Own test saves only (user://zp_test_seg7_*), never the real career.
# Runs in stages (each short): the career carries on from where the last run stopped.
#   tools/run_test.sh tests/seg7_flow.gd --fixed-fps 60 -- [new] [budget=600] [ships=5]

const Bot = preload("res://tests/salvage_bot.gd")
const Cap = preload("res://tests/cap.gd")
const GuideCards = preload("res://scripts/guide_cards.gd")
const CrewS = preload("res://scripts/crew.gd")
const OUT := "res://tests/out/seg7_%s.png"
const LOG := "res://tests/out/seg7_events.jsonl"
const M := 48.0

var g = null                  # the game scene now
var frames := 0               # frames this run (1/60 s of player time each at time scale 1)
var wall0 := 0
var keep_on := false          # keep_on: on to the next hulk while the budget lasts (one snapshot per run)
var fast_strip := false       # fast_strip: the stripping itself at bot speed (hulk 1 was timed paced; the port is the test)
var tried_sigs := {}           # star map rows already clicked (a player does not re-read a rock)
var budget := 600.0           # wall seconds this run may take before it stops at a safe point
var ships := 5
var bot = null
var shot_n := 0
var last_step := ""
var last_voices := ""
var stage := 0
var debug := false
var held := {}                # keys held (physical keycodes)
var fallbacks: Array = []     # what the bot had to know that the screen did not say
var quit_req := false
var h0 := 0
var _beat := -9999


func _initialize() -> void:
	Career.path = "user://zp_test_seg7_career.json"
	SaveGame.path = "user://zp_test_seg7_save.json"
	SaveGame.train_path = "user://zp_test_seg7_training.json"
	SaveGame.allow_test = true
	Game.coach_in_tests = true
	Game.cine_in_tests = true
	GuideCards.force_on = true
	CrewS.in_tests = true
	Txt.test_zh = true
	Txt.zh = true
	var args := OS.get_cmdline_user_args()
	debug = args.has("debug")
	for a in args:
		if a == "fast_strip":
			fast_strip = true
		if a == "keep_on":
			keep_on = true
		if a.begins_with("budget="):
			budget = float(a.substr(7))
		elif a.begins_with("ships="):
			ships = int(a.substr(6))
	if args.has("new"):
		for f in [Career.path, SaveGame.path, SaveGame.train_path]:
			for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
		Career.data = Career.fresh()
		Career.data.repair_migrated = true
		Career.data.onboard = "on"
		# the opening cards, the prologue tow and TS-1 passed (tests/tutorial_bot.gd covers TS-1)
		Career.data.prologue_done = true
		Career.data.certified = true
		Career.data.cert_kind = "full"
		Career.data.seen = {"intro": true, "belt_prelude": true}
		Career.sync_story()
		Career.save()
	else:
		Career.load_or_new()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	wall0 = Time.get_ticks_msec()
	stage = _last_stage() + 1
	_run.call_deferred()


func _last_stage() -> int:
	var f := FileAccess.open(LOG, FileAccess.READ)
	if f == null:
		return 0
	var s := 0
	while not f.eof_reached():
		var l := f.get_line()
		if l.strip_edges() == "":
			continue
		var d = JSON.parse_string(l)
		if d is Dictionary:
			s = maxi(s, int(d.get("stage", 0)))
		var n := int(d.get("shot_n", 0)) if d is Dictionary else 0
		shot_n = maxi(shot_n, n)
	return s


# ---------------------------------------------------------------- the log
var _seen_issues := {}
func _log(kind: String, d: Dictionary = {}) -> void:
	if kind == "issue":
		# (a countdown in the text is the same problem: digits do not make it a new one)
		var rx := RegEx.create_from_string("[0-9]+")
		var k := rx.sub(str(d.get("what", "")), "#", true).substr(0, 40)
		if _seen_issues.has(k):
			return
		_seen_issues[k] = true
	d.kind = kind
	d.stage = stage
	d.t = snappedf(frames / 60.0, 0.1)
	d.ship_n = Career.data.get("history", []).size()
	d.shot_n = shot_n
	var f := FileAccess.open(LOG, FileAccess.READ_WRITE) if FileAccess.file_exists(LOG) else FileAccess.open(LOG, FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify(d))
	f.close()
	print("[seg7 %s] %s" % [kind, JSON.stringify(d)])


func _shot(name: String) -> String:
	shot_n += 1
	var p := OUT % ("%03d_%s" % [shot_n, name])
	await process_frame
	await process_frame
	Cap.save(root, p)
	return p


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		frames += 1


func _wall() -> float:
	return (Time.get_ticks_msec() - wall0) / 1000.0


# ---------------------------------------------------------------- keys
func _key_ev(k: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


# a key press through the window's own input (the viewport), as the OS delivers it
func _tap(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	root.push_input(ev)
	await _frames(2)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)
	await _frames(4)


func _hold(k: int, on: bool) -> void:
	if bool(held.get(k, false)) == on:
		return
	held[k] = on
	_key_ev(k, on)


func _release_all() -> void:
	for k in held.keys():
		if held[k]:
			_key_ev(k, false)
	held = {}


func _act(a: String) -> int:
	return int(Keys.codes(a)[0])


# ---------------------------------------------------------------- the scene
func _game():
	var cs = current_scene
	if cs != null and is_instance_valid(cs) and cs.get("drone") != null:
		return cs
	return null


func _in_play() -> bool:
	return g != null and is_instance_valid(g) and str(g.state) == "play" and not Wipe.busy()


# ---------------------------------------------------------------- what the screen says
func _voices() -> Array:
	var v: Array = []
	if g == null or not is_instance_valid(g) or g.hud == null:
		return v
	var h = g.hud
	if h.voice != null and is_instance_valid(h.voice) and h.voice.visible:
		v.append("主线条/" + str(h.voice.mode))
	if g.coach_on():
		v.append("首艘船引导卡")
	if g.store_guide_on():
		v.append("仓库引导卡")
	if h._guide_on():
		v.append("任务引导卡")
	if g.walk_on():
		v.append("港区导览")
	if GuideCards.showing():
		v.append("情境讲解卡")
	if g.contract_open:
		v.append("合同卡")
	if g.codex_hud != null and is_instance_valid(g.codex_hud) and str(g.codex_hud.shown) != "" and float(g.codex_hud.k) > 0.5:
		v.append("图鉴首次遇见卡:" + str(g.codex_hud.shown))
	return v


func _marks() -> Array:
	var m: Array = []
	if g == null or not is_instance_valid(g) or g.hud == null:
		return m
	var h = g.hud
	if h.need_mark != null and is_instance_valid(h.need_mark) and h.need_mark.visible and h.need_mark.target != Vector2.INF and g.console_ui == null:
		m.append("主线标记:" + str(h.need_mark.label))
	if g.store_guide_on() and g.store_guide.target() != Vector2.INF and g.console_ui == null:
		m.append("仓库终端标记")
	if h._guide_on() and g.guide.step.get("target", Vector2.INF) is Vector2 and g.guide.step.get("target", Vector2.INF) != Vector2.INF and g.console_ui == null:
		m.append("任务卡标记:" + str(g.guide.step.get("name", "")))
	if g.coach_on() and g.coach.has_method("target") and g.coach.target() is Vector2 and g.coach.target() != Vector2.INF:
		m.append("首艘船标记")
	for n in g.find_children("*", "Node2D", true, false):
		if n.get_script() == preload("res://scripts/guide_lead.gd") and n.target != Vector2.INF:
			m.append("讲解卡带路标记")
	return m


func _step() -> Dictionary:
	if g == null or g.hud == null:
		return {}
	return g.hud._main()


func _say_text() -> String:
	var parts: Array = []
	var st := _step()
	if not st.is_empty() and g.hud.voice != null and is_instance_valid(g.hud.voice) and g.hud.voice.visible:
		parts.append("[%s] %s" % [str(st.get("chapter", "")), str(st.step.get("text", ""))])
	if g.coach_on():
		parts.append("首艘船:" + str(g.coach.STEPS[g.coach.step]))
	if g.store_guide_on():
		parts.append("仓库引导:" + str(g.store_guide.step) + " " + str(g.store_guide.title.text))
	if g.hud._guide_on():
		parts.append("任务卡:" + str(g.guide.step.get("title", "")) + " " + str(g.guide.step.get("text", "")))
	if GuideCards.showing():
		parts.append("讲解卡")
	return " | ".join(parts)


# one look at the screen: logged, shot when what it says has changed
func _look(tag: String, force := false) -> void:
	if g == null or not is_instance_valid(g):
		return
	var vs := _voices()
	var ms := _marks()
	var say := _say_text()
	var key := Mainline.chapter() + "|" + ",".join(vs.map(func(x): return str(x).get_slice("/", 0).get_slice(":", 0)))
	var problem := vs.size() > 1 or ms.size() > 1
	if key == last_step and not (force and tag in ["settle", "district_page", "bill", "final", "contract_card"]) and not problem:
		return
	if problem and key == last_step:
		return
	last_step = key
	var p := await _shot(tag)
	var d := {"tag": tag, "voices": vs, "marks": ms, "say": say, "shot": p, "chapter": Mainline.chapter(), "money": snappedf(float(Career.data.get("money", 0.0)), 1.0), "store": "%d/%d" % [StoreBook.used(), StoreBook.cap()], "inbox": StoreBook.inbox().size()}
	if vs.size() > 1:
		d.problem = "同时 %d 个声音" % vs.size()
	if ms.size() > 1:
		d.problem = str(d.get("problem", "")) + " 同时 %d 个目标标记" % ms.size()
	_log("look", d)


# ---------------------------------------------------------------- waits
# wait (up to max_s of player time) for cond; anything over 5 s is a wait to report
func _wait(cond: Callable, max_s: float, where: String, why: String) -> bool:
	var f0 := frames
	var ok := false
	while frames - f0 < int(max_s * 60.0):
		if cond.call():
			ok = true
			break
		await _frames(1)
	var s := (frames - f0) / 60.0
	if s > 5.0 or not ok:
		_log("wait", {"where": where, "s": snappedf(s, 0.1), "why": why, "ok": ok})
	return ok


# ---------------------------------------------------------------- flying, by the keys
func _fly(to: Vector2, tol_m: float = 1.0, max_s: float = 60.0, why: String = "") -> bool:
	var f0 := frames
	var stuck_t := 0.0
	var last_p: Vector2 = g.drone.global_position
	var detour := Vector2.ZERO
	var detour_t := 0.0
	var tries := 0
	var ok := false
	while frames - f0 < int(max_s * 60.0):
		# a card that stops the game on the way (a first visit): read it and put it away, as a player
		# would; its time is not the flight's
		if GuideCards.showing():
			_release_all()
			var m0 := frames
			await _modal()
			f0 += frames - m0
			continue
		if not _in_play() or g.console_ui != null:
			_release_all()
			await _frames(1)
			continue
		var d = g.drone
		var off: Vector2 = to - d.global_position
		if off.length() < tol_m * M and d.linear_velocity.length() < 80.0:
			ok = true
			break
		var mv := Vector2.ZERO
		if detour_t > 0.0:
			detour_t -= 1.0 / 60.0
			mv = detour
		else:
			for ax in 2:
				var o: float = off[ax]
				var v: float = d.linear_velocity[ax]
				var toward: float = v * signf(o)
				var stop_d: float = toward * toward / (2.0 * 700.0) if toward > 0.0 else 0.0
				if absf(o) > tol_m * M * 0.4 and stop_d < absf(o) - tol_m * M * 0.3:
					mv[ax] = signf(o)
		_hold(_act("left"), mv.x < 0.0)
		_hold(_act("right"), mv.x > 0.0)
		_hold(_act("up"), mv.y < 0.0)
		_hold(_act("down"), mv.y > 0.0)
		_hold(_act("dash"), off.length() > 25.0 * M and detour_t <= 0.0)
		await _frames(1)
		if frames % 60 == 0:
			if d.global_position.distance_to(last_p) < 0.4 * M and off.length() > tol_m * M:
				stuck_t += 1.0
			else:
				stuck_t = 0.0
			last_p = d.global_position
			if stuck_t >= 2.0:
				tries += 1
				stuck_t = 0.0
				# round whatever is in the way: across first, then up, then down
				var opts := [Vector2(0, -1), Vector2(0, 1), Vector2(signf(off.x) if off.x != 0.0 else 1.0, 0), Vector2(-signf(off.x), 0)]
				detour = opts[(tries - 1) % opts.size()]
				detour_t = 1.2
				if tries > 6:
					break
	_release_all()
	await _frames(20)
	var s := (frames - f0) / 60.0
	if not ok:
		# a player would get there in the end: put the drone there, and say so
		_log("issue", {"what": "飞不过去（%s）：%.0f 秒后从 %s m 处改为直接放到目标" % [why, s, str((g.drone.global_position / M).round())], "to": str((to / M).round())})
		g.drone.global_position = to
		g.drone.linear_velocity = Vector2.ZERO
		g.drone.reset_physics_interpolation()
		await _frames(10)
	elif s > 5.0:
		_log("fly", {"why": why, "s": snappedf(s, 0.1), "m": snappedf(off_len(to), 1.0)})
	return ok


func off_len(to: Vector2) -> float:
	return (to - g.drone.global_position).length() / M


# a district's stop nearest a point (the shuttle's)
func _stop_for(p: Vector2) -> String:
	var best := ""
	var bd := INF
	for z in Tram.found():
		var d: float = p.distance_to(Tram.station_at(str(z)))
		if d < bd:
			bd = d
			best = str(z)
	return best


# go to a point in the port: the shuttle for anything far (as the guidance says), then fly
func _go(to: Vector2, why: String) -> void:
	var here: Vector2 = g.drone.global_position
	var tram = g.get("tram")
	if tram != null and here.distance_to(to) > 90.0 * M:
		var from := Guide.nearest_stop(g)
		var dest := _stop_for(to)
		if dest != "" and dest != from and Tram.station_at(dest).distance_to(to) < here.distance_to(to) * 0.6:
			var f0 := frames
			await _fly(Tram.station_at(from), 1.5, 60.0, "去%s站" % Port.name_of(from))
			await _tap(_act("use"))
			await _frames(20)
			var panel = g.console_ui
			if panel != null and panel.get("mode") == "tram":
				await _look("tram_panel", true)
				panel._go(dest)
				await _frames(10)
				await _wait(func(): return not bool(tram.riding) and str(tram.phase) in ["", "return"] and g.console_ui == null, 120.0, "接驳车 %s→%s" % [from, dest], "坐车")
				_log("ride", {"from": from, "to": dest, "s": snappedf((frames - f0) / 60.0, 0.1)})
			else:
				_log("issue", {"what": "站台按 E 没打开接驳车（near_station=%s，console=%s）" % [str(tram.near_station()), str(g.console_ui)]})
				if g.console_ui != null:
					await _esc()
	await _fly(to, 1.2, 90.0, why)


func _esc() -> void:
	await _tap(KEY_ESCAPE)
	await _frames(10)
	if g != null and g.console_ui != null and g.console_ui.has_method("close"):
		g.console_ui.close()
		await _frames(10)


# ---------------------------------------------------------------- buttons on the open page
func _buttons(n: Node) -> Array:
	var out: Array = []
	if n == null:
		return out
	for b in n.find_children("*", "BaseButton", true, false):
		if b.is_visible_in_tree():
			out.append(b)
	return out


func _press(n: Node, text: String) -> bool:
	for b in _buttons(n):
		if b is Button and str(b.text).find(text) >= 0 and not b.disabled:
			b.emit_signal("pressed")
			await _frames(6)
			return true
	return false


func _btn_texts(n: Node) -> Array:
	var out: Array = []
	for b in _buttons(n):
		if b is Button:
			out.append(str(b.text) + (" (灰)" if b.disabled else ""))
	return out


# ---------------------------------------------------------------- reading
func _read(s: String) -> void:
	# a newcomer reads ~7 characters a second, then thinks for a moment
	await _frames(int((s.length() / 7.0 + 1.5) * 60.0))


# ---------------------------------------------------------------- the run
func _run() -> void:
	_log("start", {"money": float(Career.data.get("money", 0.0)), "active": str(Career.active().get("id", "")), "history": Career.data.get("history", []).size()})
	h0 = Career.data.get("history", []).size()
	Game.play_career(self)
	await _frames(30)
	while true:
		var ng = _game()
		if ng != g:
			g = ng
			bot = null
			last_step = ""
			if g != null:
				await _frames(10)
				_log("scene", {"ship": str(g.ship_id), "berth": g.in_berth(), "job": str(g.job.get("id", "")), "state": str(g.state)})
		if g == null:
			var cs = current_scene
			if cs != null and cs.get_script() == preload("res://scripts/terminal.gd") and frames % 120 == 0:
				_log("terminal_scene", {"tab": cs.tab})
				await _tap(KEY_ENTER)
			await _frames(1)
			continue
		if quit_req:
			break
		if Career.data.get("history", []).size() >= ships and g.in_berth() and _in_play():
			await _look("final", true)
			_log("done", {"ships": Career.data.get("history", []).size()})
			break
		if g.in_berth() and Career.data.get("history", []).size() > h0 and _in_play() and g.console_ui == null:
			_log("hulk_done", {"n": Career.data.get("history", []).size()})
			if not keep_on:
				break
			h0 = Career.data.get("history", []).size()
		if g.in_berth():
			if _wall() > budget and _in_play() and g.console_ui == null and (not Works.busy() or _wall() > budget + 20.0):
				_log("budget", {"wall": _wall()})
				break
			await _port()
		else:
			await _ship()
	_release_all()
	print("SEG7 stage %d done: ships %d, wall %.0f s, frames %d" % [stage, Career.data.get("history", []).size(), _wall(), frames])
	quit(0)


# ---------------------------------------------------------------- a hulk at the berth
func _ship() -> void:
	# a special course the hulk's family asks for first (Codex.COURSES_REQUIRED): tests/special_bot.gd plays
	# the courses themselves; here it is noted, the family certified, and on to the hulk
	if str(g.ship_id).begins_with("sp_") and str(g.state) == "play":
		var fam := str(g.ship_id).substr(3)
		_log("course", {"family": fam, "why": "接下的船这一类没受过专项训练，游戏先送去专项课（另由 special_bot 实测）"})
		await _look("course", true)
		Codex.certify(fam)
		g.after_special()
		await _frames(60)
		return
	match str(g.state):
		"intro", "towin", "survey", "build", "porttour":
			if str(g.state) != "intro":
				await _look("cine_" + str(g.state), true)
			var f0 := frames
			# the cinematics play out (a player may skip; a newcomer watches)
			await _wait(func(): return str(g.state) not in ["intro", "towin", "survey", "build", "porttour"], 40.0, "过场 " + str(g.state), "进港过场")
			if str(g.state) in ["intro", "towin", "survey", "build", "porttour"]:
				await _tap(KEY_ENTER)
			return
		"play":
			pass
		"ending":
			await _ending()
			return
		_:
			await _frames(1)
			return
	if GuideCards.showing():
		await _modal()
		return
	if g.contract_open:
		Engine.time_scale = 1.0
		await _look("contract_card", true)
		await _read("合同卡：作业艇 16 m，合同要求四条，核心资产两种拆法，船舶清单")
		await _tap(KEY_SPACE)
		await _frames(45)   # (the card fades out over ~0.5 s)
		if g.contract_open:
			_log("issue", {"what": "合同卡按 Space 没关"})
			g.close_contract()
		return
	if bot == null:
		bot = Bot.new(g, {"paced": not fast_strip})
		bot.timeout = 400000   # (a long paced strip, also one carried on from a snapshot, is not cut short)
		_log("strip", {"ship": str(g.ship_id), "job": str(g.job.get("id", ""))})
		await _look("strip_start", true)
	var coach_step := str(g.coach.STEPS[g.coach.step]) if g.coach_on() else ""
	# the coach's measuring step: the meter on its lit test point (the strip reads the ship's own data)
	if coach_step == "measure" and frames % 90 == 0:
		var c: Dictionary = bot.ctrl("E-T01")
		if not c.is_empty():
			var ts1: float = Engine.time_scale
			Engine.time_scale = 1.0
			await _read(str(g.coach.title.text))
			g.do_measure(c)
			Engine.time_scale = ts1
	# the first ship's coach asks for a key the strip itself never presses: the blueprint (Tab)
	if coach_step == "blueprint" and (g.blueprint == null or not g.blueprint.on) and frames % 90 == 0:
		var ts0: float = Engine.time_scale
		Engine.time_scale = 1.0
		await _read(str(g.coach.title.text))
		await _tap(_act("blueprint"))
		Engine.time_scale = ts0
	if frames % 1800 == 0:
		_log("progress", {"phase": str(bot.phase), "coach": coach_step, "left": g.pieces_left().size() if g.has_method("pieces_left") else -1, "sim": snappedf(float(g.sys.time), 1.0), "notes": bot.notes.slice(maxi(0, bot.notes.size() - 3))})
	if bot.step():
		Engine.time_scale = 1.0
		_log("stripped", {"notes": bot.notes.slice(0, 12), "summary": str(bot.summary())})
		bot = null
		await _frames(30)
		return
	await process_frame
	frames += 1
	if g.coach_on() and str(g.coach.STEPS[g.coach.step]) != coach_step:
		var ts: float = Engine.time_scale
		Engine.time_scale = 1.0
		await _look("coach")
		Engine.time_scale = ts


func _modal() -> void:
	Engine.time_scale = 1.0
	await _look("card", true)
	await _read("一张讲解卡大约三十个字的说明文字")
	await _tap(KEY_ESCAPE)
	await _frames(10)


func _ending() -> void:
	Engine.time_scale = 1.0
	await _frames(60 * 3)
	await _look("settle", true)
	var h = g.hud
	_log("settle", {"haul": g.career_result.get("haul", {}), "money": float(Career.data.get("money", 0.0)), "store": "%d/%d" % [StoreBook.used(), StoreBook.cap()], "inbox": StoreBook.inbox().size()})
	await _read("这一单的收获、仓库占用、一个主按钮")
	# the one button (any key)
	await _tap(KEY_ENTER)
	await _frames(30)
	if h.ending and str(g.state) == "ending":
		await _tap(KEY_ENTER)
		await _frames(30)
	if g.disposal_ui != null:
		await _look("settle_store", true)
		await _store_page(g.disposal_ui, true)
	await _wait(func(): return _game() != g or not is_instance_valid(g), 30.0, "结算后拖出船体", "拖船把空壳拖走、换场景")


# ---------------------------------------------------------------- the warehouse page
func _store_page(ui, settle := false) -> void:
	await _frames(30)
	_log("store", {"buttons": _btn_texts(ui), "inbox": StoreBook.inbox().size(), "used": StoreBook.used(), "cap": StoreBook.cap()})
	# whatever fits goes in; what does not is sold to the recycler (what a player would do first)
	if not StoreBook.inbox().is_empty():
		# the drawn button "能放的都放进去", clicked
		if ui._btns.has("keep_all"):
			ui._press("keep_all")
		else:
			_log("issue", {"what": "待入库：页面上没有“能放的都放进去”按钮"})
		await _frames(30)
		# what still does not fit: picked and sold to the recycler with its key (Enter, twice)
		for it in StoreBook.inbox().duplicate():
			ui.select("i:" + str(it.uid))
			await _frames(10)
			await _tap(KEY_ENTER)
			await _frames(20)
			if str(ui._confirm) != "":
				await _tap(KEY_ENTER)
				await _frames(20)
			_log("sold_inbox", {"name": str(it.get("name", "")), "gone": StoreBook.inbox().filter(func(x): return str(x.uid) == str(it.uid)).is_empty()})
	await _look("store_page", true)
	await _esc()
	if is_instance_valid(ui) and g.disposal_ui != null and g.disposal_ui.get("on_close") != null:
		g.disposal_ui.on_close.call()
	await _frames(20)


# ---------------------------------------------------------------- the port between hulks
func _port() -> void:
	if not _in_play():
		if str(g.state) in ["porttour", "survey", "build", "towin"]:
			await _look("cine_" + str(g.state), true)
			await _wait(func(): return str(g.state) == "play", 30.0, "港区过场 " + str(g.state), "过场动画")
			if str(g.state) != "play":
				await _tap(KEY_ENTER)
		await _frames(1)
		return
	if g.store_guide_on() and str(g.store_guide.step) == "sell":
		await _store_guide()
		return
	if _star_map() != null:
		await _scan()
		return
	if g.console_ui != null:
		await _look("page_open", true)
		_log("issue", {"what": "有页面开着没人关：%s" % str(g.console_ui.get_script().resource_path)})
		await _esc()
		return
	await _look("port")
	if frames - _beat > 600:
		_beat = frames
		var stb := _step()
		_log("beat", {"go": str(stb.get("step", {}).get("go", "")), "text": str(stb.get("step", {}).get("text", "")).substr(0, 60), "voices": _voices(), "guide": g.guide.task if g.guide != null else "", "gstep": str(g.guide.step.get("title", "")) if g.guide != null else "", "heat": str(Career.data.get("industrial_heat", {}).get("state", "")), "queue": str(ProcessQueue.open_entries().map(func(e): return "%s %.1f/%.1f b%.1f" % [e.lot, float(e.melted), float(e.t), float(e.get("billet", 0.0))])), "furnace": str(g.industrial_heat.info().get("title", "")) if g.industrial_heat != null else ""})
	if GuideCards.showing():
		await _modal()
		return
	var h = g.hud
	# the main line's card: read it, then take its "带我去"
	if h.voice != null and is_instance_valid(h.voice) and h.voice.visible and str(h.voice.mode) in ["card", "done"]:
		await _read(str(h.voice.step_text()) + "这一章为什么现在开始、修好以后能做什么、要什么")
		await _look("voice_card", true)
		if str(h.voice.mode) == "card" and h.voice.go_b.visible:
			h.voice.go_b.emit_signal("pressed")
		else:
			h.voice.ok_b.emit_signal("pressed")
		await _frames(30)
		return
	if g.store_guide_on():
		await _store_guide()
		return
	if h._guide_on():
		await _follow_guide()
		return
	var st := _step()
	if st.is_empty():
		await _frames(30)
		return
	var go := str(st.step.get("go", "wait"))
	match go:
		"wait":
			var why := str(st.step.get("text", ""))
			await _wait(func(): return str(_step().get("step", {}).get("go", "")) != "wait" or not _in_play(), 600.0, "港区等待：" + why.substr(0, 40), why)
		"contracts":
			await _contracts()
		"store":
			await _tap(KEY_F3)
			await _frames(20)
			if g.console_ui != null:
				await _store_page(g.console_ui)
			else:
				_log("issue", {"what": "F3 没打开仓库"})
				fallbacks.append("F3 打不开仓库")
				g.open_store()
				await _frames(20)
				await _store_page(g.console_ui)
		"scan":
			await _scan()
		_:
			if go.begins_with("guide:build:") or go.begins_with("guide:repair:"):
				await _take_me(go)
			elif go.begins_with("guide:"):
				await _take_me(go)
			else:
				_log("issue", {"what": "不认识的下一步 go=%s：%s" % [go, str(st.step.get("text", ""))]})
				await _frames(120)


func _take_me(go: String) -> void:
	var h = g.hud
	var spot := preload("res://scripts/need_mark.gd").spot_of(go)
	if not spot.is_empty():
		await _go(spot.at, str(spot.name))
		await _look("at_target", true)
		await _tap(_act("use"))
		await _frames(30)
		if g.console_ui != null:
			await _district_page(go)
		elif go.begins_with("guide:repair:"):
			# a berth facility looked at close up: the step moves on by itself
			await _frames(30)
		else:
			_log("issue", {"what": "到了目标按 E 没反应：%s" % go})
			await _frames(60)
		return
	# no place: the strip's own "带我去"
	if h.voice != null and h.voice.go_b.visible:
		h.voice.go_b.emit_signal("pressed")
		await _frames(30)
		_log("take_me", {"go": go, "page": str(g.console_ui.get_script().resource_path) if g.console_ui != null else "", "guide": g.guide.task if g.guide != null else ""})
		if _star_map() != null:
			await _scan()
	else:
		_log("issue", {"what": "下一步 %s 没有地方也没有“带我去”" % go})
		await _frames(120)


func _district_page(go: String) -> void:
	var ui = g.console_ui
	await _frames(40)
	await _look("district_page", true)
	_log("page", {"go": go, "buttons": _btn_texts(ui)})
	if await _press(ui, "修"):
		await _frames(30)
		await _look("bill", true)
		await _tap(KEY_ENTER)
		await _frames(30)
		_log("mend", {"go": go, "money": float(Career.data.get("money", 0.0)), "busy": Works.busy()})
	else:
		_log("issue", {"what": "区页面里没有能按的“修”：%s" % str(_btn_texts(ui))})
	if g.console_ui != null:
		await _esc()


func _store_guide() -> void:
	var sg = g.store_guide
	match str(sg.step):
		"fly":
			await _read(str(sg.title.text) + str(sg.body.text))
			await _go(sg.target(), "仓库终端")
			await _tap(_act("use"))
			await _frames(30)
			if g.console_ui == null:
				_log("issue", {"what": "仓库终端前按 E 没打开仓库（near=%s）" % str(g.consoles.near())})
				fallbacks.append("仓库终端按 E 没反应，改用 press_use")
				sg.press_use()
				await _frames(30)
		"sell":
			var ui = g.console_ui
			await _look("store_guide_sell", true)
			await _read(str(ui.guide_text))
			# the lit item; the lit button's key is on it ("卖给回收站 $… [Enter]"), and the line says press twice
			if ui.sel != sg._pick:
				ui.select(sg._pick)
			await _frames(20)
			var n0 := int(Career.data.get("recycled", {}).get("n", 0))
			await _tap(KEY_ENTER)
			await _frames(30)
			if str(ui._confirm) != "":
				await _look("store_guide_confirm", true)
				await _read(str(ui.guide_text))
				await _tap(KEY_ENTER)
				await _frames(30)
			if int(Career.data.get("recycled", {}).get("n", 0)) <= n0:
				_log("issue", {"what": "仓库引导：按 Enter 两次没卖掉（confirm=%s）" % str(ui._confirm)})
			await _look("store_guide_sold", true)
			await _frames(60)
			await _esc()
		"done_card":
			await _read(str(sg.title.text) + str(sg.body.text))
			await _wait(func(): return not g.store_guide_on(), 15.0, "仓库引导完成卡", "完成卡停留 7 秒")


func _follow_guide() -> void:
	var st: Dictionary = g.guide.step
	await _look("guide_card", true)
	await _read(str(st.get("title", "")) + str(st.get("text", "")))
	var target = st.get("target", Vector2.INF)
	var action := str(st.get("action", ""))
	if g.guide.task == "repair" and action == "contracts":
		_log("guide_repair_wait", {"text": str(st.get("title", ""))})
		await _contracts()
		return
	if action != "" and g.hud.guide_act.visible:
		g.hud.guide_act.emit_signal("pressed")
		await _frames(30)
		if g.console_ui != null:
			await _guide_page(st)
		return
	if target is Vector2 and target != Vector2.INF:
		await _go(target, str(st.get("name", "")))
		await _tap(_act("use"))
		await _frames(30)
		if g.console_ui != null:
			await _guide_page(st)
		return
	_log("issue", {"what": "任务卡没有目标也没有按钮：%s" % str(st)})
	await _frames(120)


func _guide_page(st: Dictionary) -> void:
	var ui = g.console_ui
	await _frames(30)
	var btn := str(g.guide.step.get("button", ""))
	_log("guide_page", {"task": g.guide.task, "button": btn, "buttons": _btn_texts(ui)})
	if btn != "" and await _press(ui, btn):
		await _frames(30)
		await _tap(KEY_ENTER)
		await _frames(30)
	elif btn == "" and str(g.guide.step.get("title", "")).find("Enter") >= 0:
		# the card names a key, not a button (炉体控制台：按『排一炉』（或按 Enter））
		_log("guide_key", {"task": g.guide.task, "title": str(g.guide.step.get("title", ""))})
		await _tap(KEY_ENTER)
		await _frames(60)
	else:
		_log("issue", {"what": "任务卡要按的按钮“%s”在页面上没有：%s" % [btn, str(_btn_texts(ui))]})
	if g.console_ui != null:
		await _esc()


# ---------------------------------------------------------------- the terminal: the next hulk
func _contracts() -> void:
	await _tap(_act("terminal"))
	await _frames(60)
	var ui = g.console_ui
	if ui == null:
		_log("issue", {"what": "按 B 没打开终端"})
		return
	ui._skip_boot()
	await _frames(20)
	ui.set_tab(0)
	await _frames(30)
	await _look("terminal_find", true)
	var offers: Array = ui.offers()
	_log("offers", {"n": offers.size(), "cards": offers.map(func(o): return "%s %s%s%s" % [str(o.get("id", "")), str(o.get("ship", "")), " story" if o.get("story_card", false) else "", " find" if o.get("find", false) else ""])})
	var pick := -1
	for i in offers.size():
		if offers[i].get("story_card", false) or offers[i].get("arrived", false) or str(offers[i].get("state", "")) in ["arrived", "berth", "held"]:
			pick = i
			break
	if pick < 0 and not offers.is_empty():
		pick = 0
	if pick < 0:
		_log("issue", {"what": "终端“找船”里没有能接的船"})
		await _esc()
		return
	ui.sel = pick
	await _frames(10)
	await _tap(KEY_ENTER)
	await _frames(60)
	await _look("loadout", true)
	# the loadout page: start
	for i in 4:
		if _game() != g:
			return
		await _tap(KEY_ENTER)
		await _frames(60)
	await _wait(func(): return _game() != g, 20.0, "接单后出发", "离场动画")


func _star_map():
	var ui = g.console_ui
	if ui != null and is_instance_valid(ui) and ui.get_script() == preload("res://scripts/star_map.gd"):
		return ui
	return null


# the star map, as the find page and its first-time tour say: a sector, sweep, a signal, analyse, send
func _scan() -> void:
	if _star_map() == null:
		if g.console_ui != null:
			await _esc()
		await _tap(_act("starmap"))
		await _frames(40)
	var sm = _star_map()
	if sm == null:
		_log("issue", {"what": "按 G 没打开星图"})
		quit_req = true
		return
	var f0 := frames
	var last_card := ""
	while frames - f0 < 60 * 400:
		sm = _star_map()
		if sm == null:
			break
		var home := false
		for a in ShipMarket.data().assets if Career.data.has("ship_market") else []:
			if str(a.state) in ["arrived", "berth", "held"]:
				home = true
		if (not ShipMarket.on_the_way().is_empty() or home) and not sm.tour_on():
			await _look("starmap_towing", true)
			break
		if sm.tour_on():
			var card: Array = sm.tour_card()
			var wt: String = sm.tour_wait()
			var key := str(card[0]) + str(sm._tour_i) + wt
			if key != last_card:
				last_card = key
				await _look("starmap_tour", true)
				await _read(str(card[0]) + str(card[1]))
			if wt in ["sweeping", "analysing"]:
				await _frames(30)
				continue
			# a click on the lit part presses the button under it (what _tour_click does)
			var part: String = sm._tour_part()
			var r: Rect2 = sm._tour_rect(part)
			var hit = null
			var best := -1
			for b in sm.find_box.find_children("*", "Button", true, false):
				if b.is_visible_in_tree() and not b.disabled and not b.is_queued_for_deletion() and r.intersects(b.get_global_rect()):
					# as a player reads the rows: the tow, an analysis, a signal not read yet, then anything
					# (a row already read as rock or debris is not clicked again)
					var tx := str(b.text)
					var rank := 0
					if part == "send" or tx.find("派拖船") >= 0:
						rank = 5
					elif tx.find("扫描") >= 0 or tx.find("分析") >= 0:
						rank = 4
					elif tx.find("未知信号") >= 0 and not tried_sigs.has(tx):
						rank = 3
					elif tx.find("非船只") >= 0 or tx.find("拖不回来") >= 0 or tx.find("碎片") >= 0 or tx.find("桁架") >= 0:
						rank = -1
					if rank > best:
						best = rank
						hit = b
			if hit != null and best == -1:
				hit = null
			if hit != null and str(hit.text).find("未知信号") >= 0:
				tried_sigs[str(hit.text)] = true
			var i0: int = sm._tour_i
			if hit != null and part in ["sweep", "sigs", "send", "sectors"]:
				_log("tour_click", {"part": part, "button": str(hit.text)})
				hit.pressed.emit()
				await _frames(10)
				if not (part == "sigs"):
					sm._tour_next(true)
			else:
				await _tap(KEY_SPACE)
			await _frames(20)
			if sm.tour_on() and sm._tour_i == i0 and wt == "" and sm.tour_wait() == "" and part not in ["sigs"]:
				# nothing moved: the card waits on something not lit
				await _frames(60)
			continue
		# no tour: the find page's own buttons, in the order the next-step line says
		var btns: Array = sm.find_box.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and not b.disabled)
		var pick = null
		for want in ["派", "分析", "扫描 · ", "重新扫描"]:
			for b in btns:
				if str(b.text).find(want) >= 0 and not (want == "派" and str(b.text).find("派") < 0):
					pick = b
					break
			if pick != null:
				break
		if pick == null:
			# a signal not analysed yet: pick it
			for b in btns:
				if str(b.text).find("未知") >= 0 or str(b.text).find("信号") >= 0:
					pick = b
					break
		if Scan.data().job.get("kind", "") != "":
			await _frames(30)
			continue
		if pick != null:
			_log("starmap_click", {"button": str(pick.text), "next": str(sm.next_line())})
			pick.pressed.emit()
			await _frames(20)
		else:
			_log("issue", {"what": "星图找船：没有能按的按钮（%s）" % str(sm.next_line())})
			await _frames(120)
	var s := (frames - f0) / 60.0
	_log("starmap", {"s": snappedf(s, 0.1), "towing": ShipMarket.on_the_way().size()})
	if _star_map() != null:
		await _esc()
		if _star_map() != null:
			_star_map().close()
			await _frames(10)

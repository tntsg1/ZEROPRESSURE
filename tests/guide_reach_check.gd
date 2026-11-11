extends "res://tests/seg4_sketch.gd"
# 引导可达性 (2026-11-10, user: "这个引导是要我飞过去吗？我飞不过去啊……要我 touch 一下？但是我实际上离得远呢"):
# every port walk — the core walk and each district's — played through with the player's own keys only,
# each step starting where the last one ended: W/A/S/D held (Input.parse_input_event, the same key state
# Keys.down reads), E, Space, Enter, Esc and B pressed, the transit page's district clicked. The drone
# steers along the very way the guide draws (GuideWay.route), so a drawn way through a wall shows here as
# a drone stuck against it. Per step: done, no wall passed (no jump of the drone between two frames, its
# collision on all the way), in a reasonable time. And the look-only steps ("往下看") pass with the target
# on screen, the drone never flown down to it. Own test saves only.
#   tools/run_test.sh tests/guide_reach_check.gd --fixed-fps 60
#   ... -- --before   (the old judgements: PortWalk.LOOK_ON / GuideWay.INSIDE_ON off — the before picture)

const PW = preload("res://scripts/port_walk.gd")
const GuideWay = preload("res://scripts/guide_way.gd")
const Gal = preload("res://scripts/process_gallery.gd")
const MillLine = preload("res://scripts/mill_line.gd")
const CargoFloor = preload("res://scripts/cargo_floor.gd")

var clock := 0.0
var jumps := 0                 # frames the drone moved more than a jump could (a teleport)
var coll_off := 0              # frames its collision was off while flying
var held := {}                 # the movement keys held now
var log_rows: Array = []       # [walk, step, kind, zone, seconds, ok, note]
var before := false


func _initialize() -> void:
	Career.path = "user://zp_test_reach_career.json"
	SaveGame.path = "user://zp_test_reach_save.json"
	SaveGame.allow_test = true
	before = OS.get_cmdline_user_args().has("--before")
	if before:
		PW.LOOK_ON = false
		GuideWay.INSIDE_ON = false
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# ---------------------------------------------------------------- the keys

func _key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _tap(code: int) -> void:
	_key(code, true)
	await _tick()
	_key(code, false)
	for i in 5:
		await _tick()


func _hold_dir(mv: Vector2) -> void:
	var want := {KEY_A: mv.x < 0.0, KEY_D: mv.x > 0.0, KEY_W: mv.y < 0.0, KEY_S: mv.y > 0.0}
	for k in want:
		if bool(want[k]) != bool(held.get(k, false)):
			_key(k, want[k])
			held[k] = want[k]


func _release() -> void:
	_hold_dir(Vector2.ZERO)


var _last := Vector2.INF


func _tick() -> void:
	await _frames(1)
	clock += 1.0 / 60.0
	if g == null or g.drone == null:
		return
	var p: Vector2 = g.drone.global_position
	# the shuttle carries the drone (it rides inside the car, hidden): not flying
	var riding: bool = g.tram != null and (g.tram.riding or g.tram.phase != "")
	if _last != Vector2.INF and not riding and g.drone.visible and p.distance_to(_last) > 2.5 * Geom.M:
		jumps += 1
		print("  JUMP %.1f m at %s" % [p.distance_to(_last) / Geom.M, str(p / Geom.M)])
	if not riding and g.drone.visible and g.console_ui == null and (g.drone.collision_layer == 0 or g.drone.collision_mask == 0):
		coll_off += 1
	_last = p


# ---------------------------------------------------------------- flying by the drawn way

# steer along GuideWay.route to `to` with the movement keys until `done` holds; false when stuck
# (no progress along the way for 8 s) or out of time. The keys are eight-way, as a keyboard's.
func _fly(to: Vector2, done: Callable, max_s: float) -> bool:
	var best := INF
	var since := 0.0
	for f in int(max_s * 60.0):
		if done.call():
			_release()
			return true
		var p: Vector2 = g.drone.global_position
		var v: Vector2 = g.drone.linear_velocity
		var path: PackedVector2Array = GuideWay.route(g, p, to)
		var i := 1
		while i < path.size() - 1 and p.distance_to(path[i]) < 1.6 * Geom.M:
			i += 1
		var wp: Vector2 = path[i] if path.size() > 1 else to
		var left := GuideWay._len(path) / Geom.M
		if left < best - 0.3:
			best = left
			since = 0.0
		else:
			since += 1.0 / 60.0
		if since > 8.0:
			print("  STUCK at %s (box-local %s), %.1f m of the way left, next point %s" % [str(p / Geom.M), _local(p), left, str(wp / Geom.M)])
			_release()
			return false
		# brake ahead (aim where it would come to rest), eight ways with a dead band, as fingers on keys
		var last := i == path.size() - 1
		var aim: Vector2 = (wp - p) - v * (0.55 if last else 0.35)
		var dead := 0.25 * Geom.M
		_hold_dir(Vector2(0.0 if absf(aim.x) < dead else signf(aim.x), 0.0 if absf(aim.y) < dead else signf(aim.y)))
		if since > 3.0 and f % 30 == 0 and OS.get_cmdline_user_args().has("--trace"):
			print("    at %s v %s held %s W %s input %s ctrl %s state %s" % [_local(p), str(v / Geom.M), str(held), Input.is_physical_key_pressed(KEY_W), str(g.drone.input.move), str(g.console_ui), g.state])
		await _tick()
	_release()
	print("  OUT OF TIME at %s" % str(g.drone.global_position / Geom.M))
	return false


# fly until within r m of `to` and nearly still
func _arrive(to: Vector2, r: float, max_s: float, extra := Callable()) -> bool:
	return await _fly(to, func(): return (extra.is_valid() and extra.call()) or (g.drone.global_position.distance_to(to) < r * Geom.M and g.drone.linear_velocity.length() < 1.2 * Geom.M), max_s)


func _local(p: Vector2) -> String:
	var z := PortStructure.zone_at(p)
	if z == "":
		return "-"
	var l := (p - PortStructure.box(z).position) / PortStructure.M()
	return "%s (%.1f, %.1f)" % [z, l.x, l.y]


# ---------------------------------------------------------------- one step

func _advanced(pw, s0: Array) -> bool:
	return pw.done or pw.step != int(s0[0]) or pw.back.size() != int(s0[1])


func _wait_until(cond: Callable, max_s: float) -> bool:
	for f in int(max_s * 60.0):
		if cond.call():
			return true
		await _tick()
	return cond.call()


# the page on screen: every callout with Space, then Esc (or the page's own button)
func _page_through(pw) -> void:
	for n in 20:
		if pw.page_open() and not pw.callouts_done():
			await _tap(KEY_SPACE)
		else:
			break


func _close_page() -> void:
	var ui = g.console_ui
	if ui == null:
		return
	await _tap(KEY_ESCAPE)
	await _wait_until(func(): return g.console_ui == null, 1.0)
	if g.console_ui != null and g.console_ui.has_method("close"):
		print("  (Esc did not close %s: closed by its button)" % str(g.console_ui.get_script().resource_path.get_file()))
		g.console_ui.close()
		await _wait_until(func(): return g.console_ui == null, 1.0)


func _e_works(pw, near: Callable, to: Vector2, max_s: float) -> bool:
	# fly in to where E answers, E, the page up
	var ok := await _arrive(to, 0.9, max_s, func(): return near.call() and g.drone.linear_velocity.length() < 1.2 * Geom.M and g.drone.global_position.distance_to(to) < 1.2 * Geom.M)
	if not ok:
		return false
	await _tap(KEY_E)
	return await _wait_until(func(): return g.console_ui != null, 1.5)


func _step(walk: String, pw) -> Dictionary:
	var k: String = pw.kind()
	var z: String = pw.zone()
	var s0 := [pw.step, pw.back.size()]
	var t0 := clock
	var note := ""
	var ok := false
	var budget := 45.0
	if OS.get_cmdline_user_args().has("--trace"):
		var rt: PackedVector2Array = GuideWay.route(g, g.drone.global_position, pw.target()) if pw.target() != Vector2.INF else PackedVector2Array()
		print("  trace %s %s from %s way %s" % [k, z, _local(g.drone.global_position), str(Array(rt).map(func(q): return _local(q)))])
	match k:
		"station":
			ok = await _fly(pw.target(), func(): return _advanced(pw, s0), 40.0)
		"ride":
			if _advanced(pw, s0):
				ok = true
				note = "already there"
			else:
				var stop: Vector2 = pw.target()
				ok = await _arrive(stop, 1.5, 40.0, func(): return _advanced(pw, s0) or g.tram.near_station() != "" and g.drone.linear_velocity.length() < 1.0 * Geom.M)
				if ok and not _advanced(pw, s0):
					await _tap(KEY_E)
					ok = await _wait_until(func(): return g.console_ui != null, 1.5)
					if ok:
						ok = _press(Port.name_of(z))
						if not ok:
							note = "no button for %s" % Port.name_of(z)
					else:
						note = "E at the stop opened nothing"
					if ok:
						var tr0 := clock
						ok = await _wait_until(func(): return _advanced(pw, s0), 60.0)
						if not ok:
							note = "tram phase %s at %s riding %s, drone %s" % [g.tram.phase, g.tram.at, g.tram.riding, _local(g.drone.global_position)]
				budget = 60.0
		"console", "desk":
			var near := func(): return g.port_structure.near_console() == z
			ok = await _e_works(pw, near, pw.target(), 40.0)
			if ok:
				await _page_through(pw)
				if z not in ["power", "trade"]:
					await _close_page()
				ok = await _wait_until(func(): return _advanced(pw, s0), 2.0)
			else:
				note = "E did not open the console"
		"screen":
			ok = _press("动力区控制屏")
			if ok:
				await _wait_until(func(): return pw.page_open(), 1.5)
				await _page_through(pw)
				await _close_page()
				ok = await _wait_until(func(): return _advanced(pw, s0), 2.0)
		"exchange":
			ok = _press(g.port_walk._ex_key())
			if not ok:
				var bs := []
				if g.console_ui != null:
					for bn in g.console_ui.find_children("*", "Button", true, false):
						bs.append("%s%s" % [bn.text, "(off)" if bn.disabled else ""])
				note = "page %s buttons %s" % [pw._page(), str(bs)]
			if ok:
				await _wait_until(func(): return pw.page_open(), 1.5)
				await _page_through(pw)
				await _close_page()
				ok = await _wait_until(func(): return _advanced(pw, s0), 2.0)
		"shelf":
			ok = await _e_works(pw, func(): return g.cargo_floor != null and g.cargo_floor.near_mouth() == "A", pw.target(), 40.0)
			if ok:
				await _page_through(pw)
				await _close_page()
				ok = await _wait_until(func(): return _advanced(pw, s0), 2.0)
		"mill":
			ok = await _e_works(pw, func(): return g.mill_line != null and g.mill_line.near(), pw.target(), 40.0)
			if ok:
				await _page_through(pw)
				await _close_page()
				ok = await _wait_until(func(): return _advanced(pw, s0), 2.0)
		"gallery", "gate", "hub", "home":
			ok = await _fly(pw.target(), func(): return _advanced(pw, s0), 40.0)
		"furnace":
			ok = await _e_works(pw, func(): return g.industrial_heat.near(), pw.target(), 40.0)
			if ok:
				ok = await _wait_until(func(): return _advanced(pw, s0), 2.0)
		"queue":
			if g.console_ui == null:
				ok = await _e_works(pw, func(): return g.industrial_heat.near(), pw.target(), 20.0)
			await _tap(KEY_ENTER)
			ok = await _wait_until(func(): return _advanced(pw, s0), 2.0)
			await _close_page()
		"watch":
			# a look: nothing pressed, the drone left where the last step left it (on the gallery)
			var y0: float = g.drone.global_position.y
			if not before:
				check(pw.is_look(), "  %s watch: a look step (no arrow from the drone)" % walk)
				var seen := await _wait_until(func(): return pw.target_seen(), 2.5)
				check(seen, "  %s watch: the camera shows the furnace without flying there" % walk)
			ok = await _wait_until(func(): return _advanced(pw, s0), 20.0)
			budget = 15.0
			note = "looked from %s" % _local(g.drone.global_position)
			check(g.drone.global_position.y <= y0 + 0.5 * Geom.M, "  %s watch: the drone was not taken down to the furnace" % walk)
		"repair":
			await _tap(KEY_B)
			ok = await _wait_until(func(): return g.console_ui != null, 2.0)
			if ok:
				# the berth's key is lit with "Enter 打开" once the screen has booted
				await _wait_until(func(): return float(g.console_ui.get("boot_t")) >= float(g.console_ui.BOOT_T) + 0.6, 4.0)
				await _tap(KEY_ENTER)
				ok = await _wait_until(func(): return pw.page_open(), 2.0)
				if ok:
					for i in 200:
						await _tick()
					await _close_page()
					if g.console_ui != null:
						await _close_page()
					ok = await _wait_until(func(): return _advanced(pw, s0), 2.0)
				else:
					note = "Enter did not open the berth page (%s)" % pw._page()
		"end":
			ok = await _wait_until(func(): return pw.done, 8.0)
	var s := clock - t0
	var row := {"walk": walk, "step": "%d%s" % [int(s0[0]) + 1, "" if int(s0[1]) == 0 else "·前置"], "kind": k, "zone": z, "s": s, "ok": ok and s <= budget, "note": note}
	log_rows.append(row)
	print("  %-8s %-6s %-9s %-8s %5.1f s  %s %s" % [walk, row.step, k, z, s, "ok" if row.ok else "FAIL", note])
	return row


func _walk(part: String) -> void:
	var j0 := jumps
	var c0 := coll_off
	g.drone.global_position = Dock.centre() * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	_last = Vector2.INF
	for i in 10:
		await _tick()
	g.start_port_walk(true, part)
	for i in 6:
		await _tick()
	var pw = g.port_walk
	check(pw != null and not pw.done, "%s: the walk started" % part)
	if pw == null:
		return
	var all_ok := true
	var n := 0
	while not pw.done and n < 30:
		n += 1
		var r := await _step(part, pw)
		if not bool(r.ok):
			all_ok = false
			check(false, "%s step %s (%s %s) done in time with the keys (%.1f s) %s" % [part, r.step, r.kind, r.zone, r.s, r.note])
			pw.stop()
			break
	check(all_ok and pw.done, "%s: walked through to the end with the keys only" % part)
	check(jumps == j0, "%s: no wall passed — the drone never jumped (%d)" % [part, jumps - j0])
	check(coll_off == c0, "%s: its collision on all the way (%d frames off)" % [part, coll_off - c0])
	# back to the berth for the next walk
	if g.console_ui != null:
		await _close_page()


func _run() -> void:
	_career()
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1, "ring": 1}
	Career.data.seen.erase("port_walk")
	Career.data.seen.erase("port_walk_all")
	Career.data.seen.erase("port_walk_started")
	Career.data.heat_count = 0
	Career.data.material_batches = []
	HallMarket.data().orders = []
	Career.save()
	await _spawn()
	g.bot.erase("move")            # the movement keys, not the bot's input
	g.bot.erase("brake")
	g.bot.erase("dash")
	await _frames(10)
	var parts: Array = ["core", "process", "power", "tug", "cargo", "trade"]
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--only="):
			parts = str(a).substr(7).split(",")
	for part in parts:
		print("== walk %s" % part)
		await _walk(part)
	print("REACH TABLE")
	for r in log_rows:
		print("| %s | %s | %s | %s | %.1f | %s | %s |" % [r.walk, r.step, r.kind, r.zone, r.s, "ok" if r.ok else "FAIL", r.note])
	print("GUIDE REACH %s (%d checks, %d failed)%s" % ["PASS" if fails == 0 else "FAIL", checks, fails, " [before]" if before else ""])
	_release()
	g.queue_free()
	await _frames(4)
	quit()

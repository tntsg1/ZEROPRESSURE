extends SceneTree
# 2026-11-10 无人机外观款式（阶段二回归）。Own test saves only.
#  - the save: an old career (no fields) flies the stock H1; a bad or unowned id falls back to it
#  - buying with the company's funds: short of money nothing changes; bought: money down, owned,
#    flown; bought twice: refused; written to the save and read back the same
#  - the terminal's drone page: the six airframes after the three upgrades; Enter buys, Enter on an
#    owned one flies it, on the one flown refuses; short of money refused with the funds unchanged
#  - the loadout page: ◀ ▶ step through those owned only
#  - in the berth, for each airframe: the drone flies it, its lamp's colour / width / reach, the
#    jets, the outline used by the launch pad / settlement / afterimages; a screenshot each
#  - the drawing contract for every airframe: draws without errors in every tool and thrust
#   tools/run_test.sh tests/drone_skins_check.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
const Skins = preload("res://scripts/drone_skins.gd")
var g: Node
var fails := 0
var checks := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_drone_skins_career.json"
	SaveGame.path = "user://zp_test_drone_skins_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	# ---- the save
	Career.data = Career.fresh()
	check(Skins.current() == "arrowring" and Skins.owned() == ["arrowring"], "a new / old career flies H1, owns only H1")
	Career.data.drone_skin = "nonsense"
	check(Skins.current() == "arrowring", "an unknown id falls back to H1")
	Career.data.drone_skin = "swift"
	check(Skins.current() == "arrowring", "an id not owned falls back to H1")
	Career.data.erase("drone_skin")
	# ---- buying
	Career.data.money = 10000.0
	var why := Skins.buy("anvil")
	check(why != "" and float(Career.data.money) == 10000.0 and not Skins.owns("anvil"), "short of money: refused, funds unchanged (%s)" % why)
	Career.data.money = 100000.0
	why = Skins.buy("anvil")
	check(why == "" and is_equal_approx(float(Career.data.money), 75000.0) and Skins.owns("anvil") and Skins.current() == "anvil", "bought ANVIL: -$25,000, owned, flown")
	why = Skins.buy("anvil")
	check(why != "" and is_equal_approx(float(Career.data.money), 75000.0), "bought twice: refused, funds unchanged")
	check(not Skins.equip("swift") and Skins.current() == "anvil", "can't fly one not owned")
	check(Skins.equip("arrowring") and Skins.current() == "arrowring", "back to H1")
	Skins.equip("anvil")
	# ---- the save written and read back
	check(Career.save(), "the test career saves")
	var back := SaveGame.read_career(Career.path)
	check(str(back.get("drone_skin", "")) == "anvil" and Array(back.get("drone_skins", [])).has("anvil"), "read back: flies ANVIL, owns it (%s)" % str(back.get("drone_skins", [])))
	var keep := Career.data
	Career.data = back
	check(Skins.current() == "anvil", "the loaded career flies ANVIL")
	Career.data = keep
	# ---- the drawing contract
	var node := Node2D.new()
	root.add_child(node)
	var drawn := [0]   # an array: a lambda captures a plain int by value
	node.draw.connect(func() -> void:
		for id in Skins.ORDER:
			for tool in [0, 1, 2, 3, 4, 5]:
				for th in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0.7, -0.7)]:
					for boot in [0.3, 1.0]:
						Skins.draw(node, id, {"heading": 0.4, "tool": tool, "open": 0.7, "t": 1.0, "thrust": th, "dash": th.x > 0.5, "boot": boot, "base_xf": Transform2D.IDENTITY})
						drawn[0] += 1
		node.draw_set_transform_matrix(Transform2D.IDENTITY))
	node.queue_redraw()
	await _frames(3)
	check(drawn[0] >= 6 * 6 * 5 * 2, "every airframe draws in every tool, push and launch state (%d)" % drawn[0])
	for id in Skins.ORDER:
		var hp := Skins.hull(id)
		var r := 0.0
		for v in hp:
			r = maxf(r, v.length())
		check(hp.size() >= 6 and r < 34.0, "%s: an outline within the drone's size (%.1f)" % [id, r])
		var j := Skins.jets(id, Vector2(1, 0)) if id != "arrowring" else []
		if id != "arrowring":
			var fw := j.filter(func(e): return float(e[2]) > 0.5)
			check(not fw.is_empty() and fw.all(func(e): return (e[1] as Vector2).x < -0.5), "%s: pushing ahead, the jets blow back" % id)
			var br := Skins.jets(id, Vector2(-1, 0)).filter(func(e): return float(e[2]) > 0.5)
			check(not br.is_empty() and br.all(func(e): return (e[1] as Vector2).x > 0.3), "%s: braking, the jets blow forward" % id)
			var up := Skins.jets(id, Vector2(0, -1)).filter(func(e): return float(e[2]) > 0.5)
			check(not up.is_empty() and up.all(func(e): return (e[1] as Vector2).y > 0.5), "%s: pushed toward -y, the jets blow +y" % id)
	node.queue_free()
	# ---- the auxiliary jets (2026-11-10): each at its full share of the push, in the mains' style,
	# never much shorter than the mains; the attitude jets push the airframe round the right way
	for id in Skins.ORDER:
		var main_len := 0.0
		var main_style := ""
		if id != "arrowring":
			for e in Skins.jets(id, Vector2(1, 0)):
				if float(e[2]) > 0.99:
					main_len = maxf(main_len, Skins.flame_len(str(e[4]), 1.0, float(e[3])))
					main_style = str(e[4])
			var aux: Array = []
			for lt in [Vector2(-0.5, 0), Vector2(0, -0.5), Vector2(0, 0.5)]:
				var lit_now: Array = Skins.jets(id, lt).filter(func(e): return float(e[2]) > 0.01)
				check(not lit_now.is_empty() and lit_now.all(func(e): return is_equal_approx(float(e[2]), 0.5)), "%s: half the push %s, each lit jet at half (%s)" % [id, str(lt), str(lit_now.map(func(e): return snappedf(float(e[2]), 0.01)))])
				aux.append_array(Skins.jets(id, lt * 2.0).filter(func(e): return float(e[2]) > 0.99))
			var shortest := 999.0
			for e in aux:
				shortest = minf(shortest, Skins.flame_len(str(e[4]), 1.0, float(e[3])))
			check(not aux.is_empty() and aux.all(func(e): return str(e[4]) == main_style), "%s: the braking and side jets burn in the mains' style (%s)" % [id, main_style])
			check(shortest >= 0.8 * main_len and shortest > 12.0, "%s: the shortest auxiliary flame %.1f vs the mains' %.1f (at least 80 %%)" % [id, shortest, main_len])
		var tj := Skins.turn_jets(id, 0.7)
		var torque := 0.0
		for e in tj:
			torque += (e[0] as Vector2).cross(-(e[1] as Vector2) * float(e[2]))
		check(tj.size() == 2 and tj.all(func(e): return is_equal_approx(float(e[2]), 0.7)) and torque > 0.0, "%s: turning +0.7, two attitude jets at 0.7 pushing it round the + way" % id)
		check(Skins.turn_jets(id, -0.7).size() == 2 and Skins.turn_jets(id, 0.0).is_empty(), "%s: the other pair for -, none when not turning" % id)
	# ---- the beam's colour (2026-11-10): H1 keeps the stock beam; each other its own, all apart
	check(Skins.lheat(0.7, 2.2, "arrowring") == Pal.heat(0.7, 2.2) and Skins.lcore(Color(2.0, 1.7, 1.4, 0.8), "arrowring") == Color(2.0, 1.7, 1.4, 0.8), "H1: the stock beam, halo and core")
	var hues := []
	for id in Skins.ORDER:
		var c := Skins.lheat(1.0, 1.0, id)
		hues.append([id, Vector3(c.r, c.g, c.b).normalized()])
		var core := Skins.lcore(Color(2.0, 1.7, 1.4, 0.8), id)
		check(is_equal_approx(maxf(core.r, maxf(core.g, core.b)), 2.0) and is_equal_approx(core.a, 0.8), "%s: the core as bright as the stock one" % id)
	var closest := 9.0
	var pair := ""
	for i in hues.size():
		for j in range(i + 1, hues.size()):
			var dd: float = (hues[i][1] as Vector3).distance_to(hues[j][1])
			if dd < closest:
				closest = dd
				pair = "%s/%s" % [hues[i][0], hues[j][0]]
	check(closest > 0.2, "the six beams apart from each other (closest %s %.2f)" % [pair, closest])
	Career.data.drone_skins = Skins.ORDER.duplicate()
	Skins.equip("swift")
	check(Skins.lheat(1.0, 1.0) == Skins.lheat(1.0, 1.0, "swift"), "the beam follows the airframe flown")
	Skins.equip("anvil")
	# ---- the game: the terminal, the loadout page, the berth
	Career.start_new()
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	Career.data.market = true
	Career.data.money = 60000.0
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null
	g.open_console("terminal")
	await _frames(10)
	var term = g.console_ui
	term._skip_boot()
	term.set_tab(Terminal.DRONE_PAGE)
	await _frames(30)
	var its: Array = term.items()
	check(its.size() == Terminal.DRONE_UPGRADES + 6 and its[Terminal.DRONE_UPGRADES][1] == "skin", "drone page: three upgrades then six airframes (%d)" % its.size())
	var base := Terminal.DRONE_UPGRADES
	term.sel = base + Skins.ORDER.find("swift")
	await _frames(20)
	Cap.save(root, "res://tests/out/drone_skins_terminal_zh.png")
	term.act()
	await _frames(2)
	check(is_equal_approx(float(Career.data.money), 22000.0) and Skins.current() == "swift", "terminal: bought SWIFT for $38,000 and flies it")
	term.sel = base + Skins.ORDER.find("greyhawk")
	term.act()
	await _frames(2)
	check(is_equal_approx(float(Career.data.money), 22000.0) and not Skins.owns("greyhawk"), "terminal: short of money for GREYHAWK, refused, funds unchanged")
	term.sel = base + Skins.ORDER.find("arrowring")
	term.act()
	check(Skins.current() == "arrowring", "terminal: Enter on an owned one flies it")
	term.act()
	check(Skins.current() == "arrowring" and is_equal_approx(float(Career.data.money), 22000.0), "terminal: Enter on the one flown changes nothing")
	await _frames(20)
	Cap.save(root, "res://tests/out/drone_skins_terminal_owned_zh.png")
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(8)
	# the loadout page: steps through those owned
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 90
	root.add_child(layer)
	layer.add_child(host)
	var lp := LoadoutPanel.open(host, Callable(), Callable())
	await _frames(4)
	lp._skin_step(1)
	check(Skins.current() == "swift", "loadout ▶: H1 → SWIFT")
	lp._skin_step(1)
	check(Skins.current() == "arrowring", "loadout ▶: SWIFT → H1 (only the owned ones)")
	lp._skin_step(-1)
	await _frames(30)
	Cap.save(root, "res://tests/out/drone_skins_loadout_zh.png")
	check(Skins.current() == "swift", "loadout ◀: back to SWIFT")
	layer.queue_free()
	await _frames(4)
	# the berth, each airframe in turn
	Career.data.drone_skins = Skins.ORDER.duplicate()
	var at: Vector2 = Dock.BAY * Geom.M + Vector2(-260, -120)
	g.drone.alive = true
	g.zoom_override = 2.6
	g.cam_override = at
	for id in Skins.ORDER:
		Skins.equip(id)
		g.bot.move = Vector2(1, 0)
		for i in 26:
			g.drone.global_position = at
			g.drone.linear_velocity = Vector2(-200, 0)
			g.bot.aim = at + Vector2(300, -40)
			await _frames(1)
		check(g.drone.skin_id() == id, "berth: the drone flies %s" % id)
		var lk: Array = g.look._lamp_kind() if g.get("look") != null else []
		check(lk.is_empty() or (lk[0] == Skins.SKINS[id].lamp[0] and is_equal_approx(g.look.beam.scale.x, float(Skins.SKINS[id].lamp[1]))), "berth: %s's lamp colour and width" % id)
		Cap.save(root, "res://tests/out/drone_skin_berth_%s.png" % id)
	g.bot.move = Vector2.ZERO
	Skins.equip("arrowring")
	print("DRONE SKINS: %d checks, %d failed" % [checks, fails])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	finished = true
	quit(1 if fails > 0 else 0)

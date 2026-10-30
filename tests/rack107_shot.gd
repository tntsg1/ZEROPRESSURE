extends SceneTree
# 107 号 Q1/Q2: the parts rack as a rack. A career with parts on every shelf (more than fit on one),
# a listed sail roll, a part under the repair line, plate and sections in the bins; shots of the
# panel opened, a crate picked further along, and after selling one; then the berth's own rack.
#   tools/run_test.sh tests/rack107_shot.gd --fixed-fps 60 -- tag=v1
const Cap = preload("res://tests/cap.gd")
var tag := "v1"
var fails := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	Career.path = "user://zp_test_rack107_career.json"
	SaveGame.path = "user://zp_test_rack107_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _parts() -> Array:
	var out: Array = []
	var spec := [["sail", "p_sail_roll", 4], ["power", "p_battery", 3], ["power", "p_gen", 2], ["power", "p_inverter", 2],
		["thermal", "p_pump", 3], ["thermal", "p_radiator", 2], ["drive", "p_motor", 3], ["drive", "p_winch", 2]]
	var n := 0
	for s in spec:
		for k in int(s[2]):
			n += 1
			var cond := 0.45 if n == 7 else 0.62 + 0.035 * ((n * 7) % 11)
			out.append({"uid": "J%d:T%d" % [n, n], "cls": s[0], "tag": "%s-%02d" % [str(s[1]).substr(2, 3).to_upper(), n], "nk": s[1],
				"cond": snappedf(cond, 0.01), "value": 3200.0 + 900.0 * ((n * 5) % 7), "ship": "cf90", "job": "SV-%03d" % (100 + n)})
	out[1]["listed"] = {"ask": 6000.0, "t": 40.0}
	return out


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true}
	Career.data.money = 90000.0
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.parts = _parts()
	Career.data.structure_t = 6.5
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	if g.codex_hud != null:
		g.codex_hud.visible = false
	g.open_parts_rack()
	await _frames(60)
	var pn = g.console_ui
	check(pn != null and pn.get_script().resource_path.ends_with("parts_rack_panel.gd"), "the rack opens its own panel")
	check(pn.find_child("Shelf_power", true, false) != null, "four shelves, one per class")
	Cap.save(root, "res://tests/out/rack107_%s_open.png" % tag)
	# along the power shelf, past what fits
	pn._select(1, 0)
	for i in 6:
		pn._select(1, pn.sel_col + 1)
	await _frames(40)
	check(pn.selected().get("cls", "") == "power" and pn.sel_col == 6, "the seventh power part picked")
	check(pn.scroll[1] > 1.0, "the shelf scrolled to show it")
	Cap.save(root, "res://tests/out/rack107_%s_scrolled.png" % tag)
	var before := float(Career.data.money)
	var worth := Repair.part_worth(pn.selected())
	var n0: int = Career.data.parts.size()
	pn._sell_sel()
	await _frames(12)
	check(Career.data.parts.size() == n0 - 1 and absf(float(Career.data.money) - before - worth) < 1.0, "Enter sells the crate for its worth")
	Cap.save(root, "res://tests/out/rack107_%s_sold.png" % tag)
	# sell all asks first
	pn._sell_all()
	await _frames(2)
	check(Career.data.parts.size() == n0 - 1, "the first press of sell-all only asks")
	pn.close()
	await _frames(10)
	# the berth's own rack: four shelves of crates
	g.drone.global_position = Consoles.rack_centre() + Vector2(0, 3.5) * Geom.M
	g.cam.position = Consoles.rack_centre()
	g.cam.zoom = Vector2(2.2, 2.2)
	await _frames(30)
	Cap.save(root, "res://tests/out/rack107_%s_world.png" % tag)
	print("RACK107 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()

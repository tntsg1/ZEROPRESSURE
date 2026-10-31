extends SceneTree
# The playtest pack carries the first hour's ships only (user 2026-10-30 "只打包第一小时"): nothing the
# first hour can reach asks for a ship the pack hasn't, and the export preset lists exactly Demo.SHIPS.
# With --demo --main-pack <the exported pck> this runs on the real pruned files as well:
#   godot --headless --main-pack build/playtest/check.pck --script E:/godot/zeropower/tests/demo_pack_check.gd --demo
# Otherwise from the project (the files are all there; Ship.available holds the line):
#   godot --headless --path . -s tests/demo_pack_check.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _career(extra := {}) -> Dictionary:
	var c := {"rep": 0, "done": 0, "money": 50000.0, "upgrades": {}, "market": true, "history": [], "plans": {}}
	c.merge(extra, true)
	return c


func _run() -> void:
	var pack: bool = not FileAccess.file_exists("res://ships/m14.json")
	print("real pruned pack: ", pack)
	# what fits the 50 m berth, measured before the build's limit is on
	if not pack:
		var fit: Array = []
		for e in Market.POOL:
			if float(Market.type_of(e[0]).get("length", 0.0)) <= Dock.TIERS[0][0] - 6.0:
				fit.append(e[0])
		check(fit.all(func(s): return s in Demo.SHIPS), "every ship the 50 m berth takes is in the pack: %s" % str(fit))
		check(Market.POOL.filter(func(e): return e[0] in Demo.SHIPS).size() == fit.size(), "and no bigger one is")
		var cfg := ConfigFile.new()
		check(cfg.load("res://export_presets.cfg") == OK, "export presets read")
		# json files are resources: the export takes them all unless the preset's exclude list says no
		var ex := Array(str(cfg.get_value("preset.2", "exclude_filter", "")).split(","))
		var want: Array = []
		for f in DirAccess.get_files_at("res://ships"):
			if f.ends_with(".json") and not f.ends_with("_course.json") and not f.trim_suffix(".json") in Demo.SHIPS:
				want.append("ships/" + f)
		var listed: Array = ex.filter(func(f): return f.begins_with("ships/"))
		want.sort()
		listed.sort()
		check(listed == want, "the preset leaves out exactly what isn't in Demo.SHIPS (%d files)" % want.size())
		check("data/台词.txt" in str(cfg.get_value("preset.2", "include_filter", "")).split(","), "the playtest pack carries the author's lines")
		check("data/台词.txt" in str(cfg.get_value("preset.0", "include_filter", "")).split(","), "and so does the full build")
	else:
		check(Array(DirAccess.get_files_at("res://ships")).filter(func(f): return f.ends_with(".json") and not f.ends_with("_course.json")).size() == Demo.SHIPS.size(), "the pack holds exactly Demo.SHIPS' files")
		check(FileAccess.file_exists(Lines.FILE), "the pack holds data/台词.txt")
		check(not FileAccess.file_exists("res://data/界面文字_原文.json"), "the UI text source is left out")
	Demo.forced = true
	Ship.clear_cache()
	check(not Ship.available("m14") and not Ship.available("ark01"), "a later ship isn't available")
	check(Ship.load_data("ark01").is_empty(), "and loads as nothing, quietly")
	for s in Demo.SHIPS:
		check(not Ship.load_data(s).is_empty(), "pack ship %s loads" % s)
	check(Market.pool().all(func(e): return e[0] in Demo.SHIPS), "the market pool is the pack's: %d" % Market.pool().size())
	# the market through a lot of seeds, at the start and with everything the first hour can have
	var seen := {}
	for c in [_career(), _career({"rep": 40, "done": 12})]:
		for seed in 200:
			for o in Market.make(seed * 31 + 7, c):
				seen[str(o.get("ship", ""))] = true
	check(seen.keys().all(func(s): return s == "" or s in Demo.SHIPS), "200 markets only offer pack ships: %s" % str(seen.keys()))
	var saved: Dictionary = Career.data
	Career.data = _career()
	# the fixed jobs: the opening, the training page
	for o in Career.OPENING:
		check(str(o.ship) in Demo.SHIPS, "opening job %s" % o.ship)
	for k in Career.TRIALS:
		check(str(Career.TRIALS[k].ship) in Demo.SHIPS, "trial %s" % k)
	for id in Methods.ORDER:
		var s := Methods.ship_for(id)
		check(s == "" or s in Demo.SHIPS, "method %s comes on %s" % [id, s])
		var need := Methods.berth_needed(id)
		check(s != "" or need == 0.0 or need >= Dock.EXTENDED or Methods.SPEC[id].get("ships", []).is_empty() or Ship.available(str(Methods.SPEC[id].ships[0])), "method %s: needs %d m" % [id, int(need)])
		var ship := Methods.showcase_ship(id)
		check(ship == "" or Ship.available(ship) or preload("res://scripts/ship_market.gd")._showcase(id).is_empty(), "showcase for %s holds" % id)
	var names: Array = []
	for e in Route.ships():
		var n := Route.ship_node(e)
		names.append(str(n.cls))
		check(str(n.id) in Demo.SHIPS and str(n.name) != "", "roadmap row %s" % n.id)
	print("roadmap: ", names)
	for cls in ["energy", "cryo", "fluid", "precise", "load", "isolate", "atmos", "engine", "pump", "power"]:
		Repair.ships_with(cls)
	Career.data = saved
	# the code goes on the window's title bar and nowhere in the picture
	var cf := ProjectSettings.globalize_path(Demo.CFG)
	var keep := FileAccess.get_file_as_bytes(cf) if FileAccess.file_exists(cf) else PackedByteArray()
	Demo.remember("ZP-TEST-0000")
	Demo.mark(self)
	check(root.title.ends_with("ZP-TEST-0000"), "the title bar reads: %s" % root.title)
	if keep.size() > 0:
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_buffer(keep)
	else:
		DirAccess.remove_absolute(cf)
	Demo.forced = false
	Ship.clear_cache()
	print("DEMO PACK %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails > 0 else 0)

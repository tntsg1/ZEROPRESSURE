extends "res://tests/guide_check.gd"
# The tug station's cryo collection tanks (2026-11-11, user: "要，按我说的改"): a hulk's leftover LH2 /
# LOX drawn off at the mouth by the stage's share into the station's own tanks, the hulk left with
# less, the tanks piped on to the gas line's LH2 / LOX (GasLine.CRYO_S), the fuel cells' stock
# counting them; a ship's cargo with its own mechanism (HG-170's boil-off tanks) left aboard;
# an old save without the tanks reads as empty. Then the tank group and the run, shot.
#   tools/run_test.sh tests/tug_cryo_check.gd --fixed-fps 60

const PS = preload("res://scripts/power_supply.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_tug_cryo_career.json"
	SaveGame.path = "user://zp_test_tug_cryo_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _career() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 2, "power": 1, "cargo": 1, "tug": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true, "gas_flow_film": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	if not Career.data.has("upgrades"):
		Career.data.upgrades = {}
	Career.data.upgrades["gas_line"] = true
	Career.data.upgrades["lox_tank"] = true


func _run() -> void:
	_career()
	# --- what a ship carries
	var nr := TugYard.cryo_of("nr95")
	check(absf(float(nr.lh2) - 0.6) < 0.001 and float(nr.lox) == 0.0, "NR-95's leftover LH2 tank counts: %.2f m³ LH2, %.2f m³ LOX" % [float(nr.lh2), float(nr.lox)])
	var hg := TugYard.cryo_of("hg170")
	check(float(hg.lh2) == 0.0, "HG-170's LH2 is its cargo (boil-off tanks): not drawn off (%.2f m³)" % float(hg.lh2))
	# --- an old save: no tanks yet
	check(not Career.data.has("tug_cryo") and float(TugYard.cryo().lh2) == 0.0 and float(TugYard.cryo().lox) == 0.0, "an old save without the tanks reads them empty")
	# --- the hulk comes in, the station (stage 2: 70 %) draws it off
	var a := {"id": "CRYO-1", "ship": "nr95", "state": "arrived", "yard": 0, "listing": {"offer": {"ship": "nr95"}}}
	ShipMarket.data().assets.append(a)
	var share := TugYard.drain_share()
	TugYard.prepped(a, share)
	var want := 0.6 * share * 71.0
	check(absf(float(TugYard.cryo().lh2) - want) < 0.5, "drawn into the LH2 collection tank: %.1f kg (0.6 m³ × %.0f %% × 71 kg/m³ = %.1f)" % [float(TugYard.cryo().lh2), share * 100.0, want])
	check(absf(float(a.get("prep", {}).get("cryo", {}).get("lh2", 0.0)) - share) < 0.001, "the hulk's record keeps the share drawn off (%.2f)" % float(a.get("prep", {}).get("cryo", {}).get("lh2", 0.0)))
	check(PS.stock_h2() >= want - 0.5, "the fuel cells' LH2 stock counts the tug's tank (%.1f kg)" % PS.stock_h2())
	Career.save()
	# --- the hulk stripped: its LH2 tank holds what was left
	Game.contract = {"id": "CRYO-1", "ship": "nr95"}
	Game.start_ship = "nr95"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	var left := float(g.sys.fvol.get("lh2", {}).get("amount", -1.0))
	check(absf(left - 0.6 * (1.0 - share)) < 0.001, "aboard NR-95 the LH2 tank holds what was left: %.3f m³ (0.6 × %.0f %%)" % [left, (1.0 - share) * 100.0])
	g.queue_free()
	await _frames(5)
	# --- piped on to the gas line's LH2 tank, taking its time
	var lh0 := float(GasLine.data().get("lh2", {}).get("kg", 0.0))
	var got := float(TugYard.cryo().lh2) + GasLine.cryo_piping("lh2")   # (the stripping scene's clock may have sent it already)
	GasLine.advance(null, 0.1)
	check(GasLine.cryo_piping("lh2") > 0.0 and float(TugYard.cryo().lh2) < 0.5, "the tank's LH2 sent down the pipe (%.1f kg on the way)" % GasLine.cryo_piping("lh2"))
	check(float(GasLine.data().get("lh2", {}).get("kg", 0.0)) == lh0, "not there yet")
	for i in int(GasLine.CRYO_S / 0.5) + 2:
		GasLine.advance(null, 0.5)
	var lh1 := float(GasLine.data().get("lh2", {}).get("kg", 0.0))
	check(absf(lh1 - lh0 - got) < 0.5 and GasLine.cryo_piping("lh2") < 0.01, "arrived in the gas line's LH2 tank after %.0f s: +%.1f kg (%.2f kg still on the way, %.2f kg in the tug tank)" % [GasLine.CRYO_S, lh1 - lh0, GasLine.cryo_piping("lh2"), float(TugYard.cryo().lh2)])
	check(absf(PS.stock_h2() - lh1) < 0.5, "stock counted once (%.1f kg)" % PS.stock_h2())
	# --- LOX the same way (a test charge: no ship file carries liquid LOX)
	TugYard.set_cryo("lox", 900.0)
	var lox0 := float(GasLine.data().lox.kg)
	for i in int(GasLine.CRYO_S / 0.5) + 4:
		GasLine.advance(null, 0.5)
	check(absf(float(GasLine.data().lox.kg) - lox0 - 900.0) < 1.0, "LOX piped into the gas line's LOX tank: +%.0f kg" % (float(GasLine.data().lox.kg) - lox0))
	# --- the console's lines
	Txt.zh = true
	var ls := TugYard.cryo_lines()
	check(ls.size() == 2 and str(ls[0]).contains("液氢") and str(ls[1]).contains("液氧"), "the tug console shows both tanks: %s" % " / ".join(ls))
	# (pictures: tests/gas_route_shot.gd, tug_tanks / tug_piping)
	print("TUG CRYO %s (%d of %d)" % ["PASS" if fails == 0 else "FAIL", checks - fails, checks])
	quit(1 if fails > 0 else 0)

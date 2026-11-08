extends SceneTree
# 96 号: the tug station's mouth pre-processes the hulk lying in it for real (Q11 B). A GR-7 in
# yard berth 1 at stage 1: moored, its propellant drawn off by 40 %, the push frame set, the hull
# scanned; the asset remembers the share, the station's tank holds what came off,
# and the hulk's systems start with that much less fuel.
# A hulk too tall for the mouth waits outside and is drawn off nothing. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/tug_prep_check.gd
const TW = preload("res://scripts/tug_works.gd")
var fails := 0
var checks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_tugprep_career.json"
	SaveGame.path = "user://zp_test_tugprep_save.json"
	SaveGame.allow_test = true
	_run()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _asset(id: String, ship: String, slot: int) -> Dictionary:
	var a := {"id": id, "ship": ship, "listing": {"offer": {"ship": ship}}, "state": "arrived", "seen_in": true,
		"yard": slot, "run": {}, "tow": 0.0, "price": 0.0, "claimed": false, "mind": {}, "tug": ""}
	Career.data.ship_market.assets.append(a)
	return a


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.port = {"tug": 1, "power": 1}
	ShipMarket.data()
	TW.reset()
	check(TugYard.dock_in("gr7") > 0.0 and TugYard.dock_in("ch110") < 0.0, "GR-7 goes into the mouth; CH-110 (40 m tall) does not")
	var a := _asset("P-1", "gr7", 0)
	check(TugYard.docked() == a, "GR-7 in berth 1 lies in the mouth")
	var fuel := TugYard.fuel_of("gr7")
	check(fuel > 0.1, "GR-7 carries propellant (%.2f m³)" % fuel)
	var t := 0.0
	while not bool(TW.hulk.get("done", false)) and t < 240.0:
		TW.tick(1.0 / 30.0)
		t += 1.0 / 30.0
	check(bool(TW.hulk.get("done", false)), "pre-processed in %.0f s" % t)
	check(TW.frame_on == "hulk" and TW.arms > 0.99, "the push frame on its stern, the clamp arms on it")
	check(is_equal_approx(float(a.get("prep", {}).get("drained", 0.0)), 0.4), "stage 1 draws off 40 %")
	check(absf(TugYard.tank() - fuel * 0.4) < 1e-4, "the tank holds what came off (%.3f m³)" % TugYard.tank())
	# the berth's systems start with that much less fuel
	var fake := {"job": {"id": "P-1"}}
	check(is_equal_approx(TugYard.drained_of(FakeGame.new(fake)), 0.4), "the stripping game sees the share drawn off")
	# too tall: waits outside, nothing drawn off
	a.state = "stripped"
	TW.reset()
	var b := _asset("P-2", "ch110", 0)
	check(TugYard.docked().is_empty(), "CH-110 in berth 1 is not in the mouth")
	for i in 600:
		TW.tick(1.0 / 30.0)
	check(not b.has("prep") and TW.hulk.is_empty(), "nothing drawn off a hulk outside")
	print("TUG PREP %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()


class FakeGame extends RefCounted:
	var job := {}
	func _init(d: Dictionary) -> void:
		job = d.job

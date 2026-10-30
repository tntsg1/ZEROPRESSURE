extends SceneTree
# A company batch (industrial sorting / heat) reserves the plant only at the empty
# berth (2026-10-24): in a contract or sandbox scene the metal mouth takes scrap as
# usual and the developer's auto sort still works; contracts can be taken while a
# batch is parked; at the berth the metal mouth still refuses other scrap.
# godot --headless --path . --fixed-fps 60 -s tests/plant_mutex_check.gd

var frame := 0
var g
var dev
var fails := 0
var loose0 := 0
var dev_was := false
var phase := 1


func _initialize() -> void:
	Txt.zh = true
	dev_was = Txt.dev
	Career.path = "user://zp_test_mutex_career.json"
	SaveGame.path = "user://zp_test_mutex_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Career.data = {}
	Career.start_new()
	# a sorting batch parked mid-transport, as the player's save had it
	Career.data.industrial_sort = {"id": "SORT-TEST", "state": "product_transport", "quantity": 1.0, "transport": {"claimed": true}, "outputs": [], "received": [], "output_index": 0, "energy_debt": 0.0, "energy_cost": 0.0, "energy_meter_j": 0.0}
	check(Career.production_busy(), "the parked batch counts as busy")
	# contracts are no longer refused while it is parked
	var story: Dictionary = Career.data.active.duplicate(true)
	Career.data.market = true
	Career.data.active = {}
	Career.data.offers = [{"id": "T-9", "ship": "gr7", "fee": 0.0, "scope": "full", "time": 600.0, "stars": 1, "reg": "GR-9", "traps": [], "variant": 1}]
	var o := Career.accept(0)
	check(not o.is_empty() and Career.active().get("id", "") == "T-9", "a contract can be taken while a batch is parked")
	check(not Career.take_story().has("blocked"), "take_story has no production gate")
	Career.data.active = story
	Career.data.offers = []
	Career.data.market = false
	Career.save()
	Game.contract = Career.sign_active()
	Game.start_ship = Game.contract.ship
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(-30, -30) * 48.0, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _loose() -> Array:
	return g.world.bodies.filter(func(b): return is_instance_valid(b) and b.capture == null and not b.pieces.is_empty())


func _process(_dt: float) -> bool:
	frame += 1
	if phase == 1:
		if frame == 30:
			Txt.dev = true
			for n in g.get_children():
				if n is DevPanel:
					dev = n
			DevPanel.god = true
			check(not g.in_berth() and Career.production_busy() and not Career.plant_reserved(g), "on a contract the plant is not reserved")
			dev.run(2)
			dev.run(3)
		elif frame == 40:
			loose0 = _loose().size()
			dev.run(13)
			check(DevPanel.sort_on, "auto sort switched on")
		elif frame == 2440:
			var l := _loose()
			var skip := l.filter(func(b): return b.get_meta("sort_skip", false)).size()
			print("  after 40 s: loose %d of %d, turned away %d, recovery %.1f%%" % [l.size(), loose0, skip, g.recovery_rate() * 100.0])
			check(loose0 > 10, "F3 freed the ship (%d loose bodies)" % loose0)
			check(l.size() <= loose0 * 0.25, "the mouths took the scrap in spite of the parked batch (%d of %d left)" % [l.size(), loose0])
			check(g.recovery_rate() > 0.5, "recovery above 50 percent")
			dev.run(13)
			DevPanel.god = false
			g.queue_free()
			phase = 2
			frame = 0
		return false
	if phase == 2:
		if frame == 5:
			Game.contract = {}
			Game.start_ship = "berth"
			Career.data.active = {}
			Career.save()
			g = load("res://scenes/main.tscn").instantiate()
			root.add_child(g)
		elif frame == 60:
			check(g.in_berth() and g.plant != null and not Career.plant_reserved(g), "30 号: the batch runs on the processing district's works, so even at the empty berth the berth's furnace stays free")
			var p = g.world.add_piece("cargo", Geom.rect_poly(Rect2(Vector2(20.0, -4.0) * Geom.M - Vector2.ONE * 20.0, Vector2.ONE * 40.0)), {"key": "MUTEX-T", "mass": 0.3, "cls": "equip", "scope": false, "value": 0.0, "label": "T"})
			g.world.make_body([p], null)
			var v: Dictionary = g.judge(p.body, "metal")
			check(str(v.get("reason", "")) != "rej_plant_reserved", "the berth's metal mouth no longer refuses scrap for a parked batch (%s)" % str(v.get("reason", "")))
			Txt.dev = dev_was
			print("MUTEX %s" % ("PASS" if fails == 0 else "FAIL"))
			quit(0 if fails == 0 else 1)
			return true
	return false

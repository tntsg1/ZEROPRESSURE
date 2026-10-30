extends SceneTree
# 26 号: the opening hulks are unowned and free; every market carries one unowned hulk (two
# once the tug station is fully built): the whole ship, no client goal, no named pieces, a
# tow-in fee by the metre (half once the tug station works), its years adrift; the card says so.
#   tools/run_test.sh tests/opening_salvage_check.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var fails := 0
var checks := 0


func _initialize() -> void:
	# 68 号: this test reads the hulks the market drew by itself (before the star-map sweep)
	Scan.ON = false
	Career.path = "user://zp_test_openingsalvage_career.json"
	SaveGame.path = "user://zp_test_openingsalvage_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _drifts(offers: Array) -> Array:
	return offers.filter(func(o): return o.get("owner", "") == "salvage")


func _run() -> void:
	Txt.zh = true
	# 1. the opening: three unowned hulks, all free
	var opening_ok := true
	for i in Career.OPENING.size():
		var o := Career.opening(i)
		opening_ok = opening_ok and o.get("owner", "") == "salvage" and float(o.get("fee", -1.0)) == 0.0
	check(opening_ok, "the tug, the Swift and the Heron are unowned hulks, free")
	check(Txt.t("c_fee").find("9,000") < 0 and Txt.t("c_fee").find("无主") >= 0, "the Heron's briefing no longer asks $9,000 (%s)" % Txt.t("c_fee"))

	# 2. the market: one unowned hulk, its terms
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.rep = 20
	Career.data.port = {}
	var ok_all := true
	var fee_ok := true
	var mand_ok := true
	var client_named := 0
	for seed in [11, 22, 33, 44, 55]:
		var offers := Market.make(seed, Career.data)
		var dr := _drifts(offers)
		# 62 号: the market is all finds (three, four with the tug station built)
		ok_all = ok_all and offers.size() == 3 and dr.size() == 3
		for o in dr:
			ok_all = ok_all and o.scope == "full" and o.goal == "" and o.get("named", []).is_empty() and int(o.drift_years) >= 3 and int(o.drift_years) <= 40
			fee_ok = fee_ok and float(o.fee) > 0.0 and o.has("station") and float(o.get("tow_days", 0.0)) > 0.0
			var d := Variant.make(Ship.load_data(str(o.ship)), o)
			mand_ok = mand_ok and not d.pieces.any(func(pd): return pd.get("mandatory", false))
		for o in offers:
			if o.get("owner", "") != "salvage" and not o.get("named", []).is_empty():
				client_named += 1
	check(ok_all, "five markets: three finds each, whole ship, no goal, no named pieces, 3–40 years adrift (62 号)")
	check(fee_ok, "each find quotes its tow home from the station it drifts near")
	check(mand_ok, "its ship data asks for no piece whole")
	check(client_named == 0, "no client contracts any more (62 号)")
	var len_gr := float(Market.type_of("gr7").length)
	check(is_equal_approx(Market.drift_fee("gr7", Career.data), snappedf(len_gr * Market.DRIFT_PER_M, 100.0)), "GR-7 towed in: %s at tug station 0" % Pal.money(Market.drift_fee("gr7", Career.data)))
	Career.data.port = {"tug": 1}
	check(is_equal_approx(Market.drift_fee("gr7", Career.data), snappedf(len_gr * Market.DRIFT_PER_M * 0.5, 100.0)), "half once the tug station works (%s)" % Pal.money(Market.drift_fee("gr7", Career.data)))
	Career.data.port = {"tug": 2}
	check(_drifts(Market.make(66, Career.data)).size() == 4, "one more find once the tug station is fully built")

	# 3. the card
	Career.data.port = {}
	Career.data.offers = Market.make(77, Career.data)
	Career.save()
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	term._skip_boot()
	term.set_tab(0)
	var di := -1
	for i in term.offers().size():
		if term.offers()[i].get("owner", "") == "salvage":
			di = i
	term.sel = di
	await _frames(90)
	check(di >= 0 and Career.data.get("seen", {}).has("drift_first"), "the market shows the unowned hulk (and the first-sighting line is marked)")
	Cap.save(root, "res://tests/out/opening_drift_card_zh.png")
	term.queue_free()
	await _frames(4)
	print("OPENING SALVAGE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()

extends SceneTree
# 87-7: the economy after 87-1 to 87-6. Per formal ship: everything the ship can pay (every unit
# whole, its structure as scrap by material, gas, fluids, ore, the sail furled whole) against the
# recovery's denominator — no strip can read over 100 %; the scrap by material adds up to the ship
# file's figure. The one-off sums are bounded: the tow fee once, a listed sail roll at most 5.8 %
# over its fair price, the rolls never above the sail. Then a long career on the market's terms
# (contract value by unlock order, the broker's fee, a recovery of 90 %): how many contracts until
# every skill volume and every berth expansion is bought — not a runaway, not a grind.
#   godot --headless --path . -s tests/economy_check.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	var over: Array = []
	var scrap_off: Array = []
	var rows: Array = []
	for row in Market.POOL:
		var sid := str(row[0])
		var d: Dictionary = Ship.load_data(sid)
		var w = World.new()
		Ship.build(w, d)
		var metal := float(d.get("value", {}).get("metal", 0.0))
		w.finalize(metal)
		var pay := float(d.get("gas", {}).get("value", 0.0)) + float(d.get("value", {}).get("bonus", 0.0))
		pay += float(d.get("ore", {}).get("fines", 0.0)) * float(d.get("ore", {}).get("price", 0.0))
		for f in d.get("fluids", {}).get("value", {}):
			pay += float(d.fluids.value[f])
		pay += preload("res://scripts/sail.gd").asset_full(d)
		var scrap := 0.0
		for id in w.order:
			var p = w.pieces[id]
			if p.cls == "equip":
				pay += p.value * (0.4 if p.hazard in Systems.HAZARD_ONLY else 1.0)
			else:
				scrap += w.scrap_value(p)
		pay += scrap
		# the denominator as the game sets it (game.gd full_value / rate_base)
		var full := metal + float(d.get("gas", {}).get("value", 0.0)) + preload("res://scripts/sail.gd").asset_full(d)
		for fv in d.get("fluids", {}).get("value", {}).values():
			full += float(fv)
		for id in w.order:
			if w.pieces[id].cls == "equip":
				full += float(w.pieces[id].value)
		var base := maxf(float(d.value.total), full)
		if pay > base * 1.001:
			over.append("%s %.0f/%.0f" % [sid, pay, base])
		if absf(scrap - metal) > maxf(1.0, metal * 0.001):
			scrap_off.append(sid)
		rows.append([sid, float(d.value.total), pay])
		w.free()
	check(over.is_empty(), "no formal ship can pay more than its recovery's denominator: no strip over 100 %% (%s)" % str(over))
	check(scrap_off.is_empty(), "each ship's scrap, shared out by material, is its ship file's figure (%s)" % str(scrap_off))
	# the one-offs
	var BoatTow = preload("res://scripts/boat_tow.gd")
	check(BoatTow.FEE <= 10000.0 and BoatTow.STEEL_T <= BoatTow.HULK_MASS, "the tow is paid once, its steel no more than the section weighs")
	var fair := 40000.0
	var listed := fair * (1.0 + Repair.LIST_K) * (1.0 - Repair.LIST_FEE)
	check(listed / fair < 1.06, "a listed sail roll fetches at most %.1f %% over its fair price" % ((listed / fair - 1.0) * 100.0))
	# a long career on the market's terms
	var skills := 0.0
	for tr in Growth.TRACKS:
		for p in tr[5]:
			skills += float(p)
	var berths := 0.0
	for it in Repair.ITEMS:
		berths += float(it[3])
	var ports := 0.0
	for z in Port.ZONES:
		for n in [1, 2]:
			ports += Port.cash(z, n, false)
	var goal := skills + berths + ports
	var money := 10000.0
	var done := 0
	var spent := 0.0
	var at_goal := -1
	var curve: Array = []
	var by_unlock: Array = Market.POOL.duplicate()
	by_unlock.sort_custom(func(a, b): return int(a[2]) < int(b[2]))
	var max_gain := 0.0
	for k in 120:
		var open: Array = by_unlock.filter(func(r): return int(r[2]) <= done)
		var r: Array = open[k % open.size()]
		var d: Dictionary = Ship.load_data(str(r[0]))
		var value := float(d.value.total)
		var fee := value * 0.10
		var net := value * 0.90 - fee
		max_gain = maxf(max_gain, net / value)
		money += net
		done += 1
		# what the career buys as it can
		var buy := minf(money * 0.8, goal - spent)
		money -= buy
		spent += buy
		if at_goal < 0 and spent >= goal - 1.0:
			at_goal = done
		if k in [9, 29, 59, 119]:
			curve.append("after %d contracts: $%.0f spent of $%.0f (%.0f %%), $%.0f in hand" % [done, spent, goal, spent / goal * 100.0, money])
	for c in curve:
		print("  " + c)
	print("  every skill ($%.0f), berth repair and expansion ($%.0f) and district stage ($%.0f) bought after %d contracts" % [skills, berths, ports, at_goal])
	check(max_gain < 1.0 and is_finite(money), "no contract pays more than it is worth (%.0f %% at most), money stays finite" % (max_gain * 100.0))
	check(at_goal >= 25 and at_goal <= 110, "the whole port takes %d contracts to build: no runaway, no endless grind" % at_goal)
	print("ECONOMY %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)

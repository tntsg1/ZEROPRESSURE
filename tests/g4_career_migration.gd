extends SceneTree
# Real saves are read-only inputs. Every migrated/write-tested career is a
# test-private clone. This is serialization/migration evidence, not playtesting.
var checks := 0
var fails := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func same_saved_value(a,b) -> bool:
	# JSON stores numbers as float; the production normalizer restores some
	# integer fields. Require exact numeric values, keys and array order.
	if (a is int or a is float) and (b is int or b is float): return float(a) == float(b)
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same_saved_value(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not same_saved_value(a[i],b[i]): return false
		return true
	return a == b
func _run() -> void:
	Txt.cfg_path = "user://zp_test_g4_migration_settings.cfg"
	SaveGame.path = "user://zp_test_g4_migration_field.json"
	SaveGame.allow_test = false
	for slot in [1,2,3]:
		var original: String = Career.slot_files(slot)[0]
		if not FileAccess.file_exists(original):
			check(false,"expected existing career slot %d is available" % slot)
			continue
		var digest := FileAccess.get_sha256(original)
		var old: Dictionary = SaveGame.read_career(original)
		check(not old.is_empty(),"slot %d original can be read without selecting or modifying the slot" % slot)
		Career.path = "user://zp_test_g4_migration_slot%d.json" % slot
		Career.data = old.duplicate(true)
		check(Career.save(),"slot %d test-private clone is written" % slot)
		Career.data = {}
		Career.load_or_new()
		check(int(Career.data.done) == int(old.get("done",0)) and Career.data.get("plans",{}) == old.get("plans",{}),"slot %d completed jobs and original recorded plans survive migration" % slot)
		var expected_upgrades: Dictionary = old.get("upgrades",{}).duplicate(true)
		var expected_money: float = old.get("money",0.0)
		# Existing G3 explicitly retires skill volumes and refunds their exact
		# historical prices. They are not missing permanent berth facilities.
		if not old.has("skills_refunded"):
			for row in Growth.TRACKS:
				for level in clampi(int(expected_upgrades.get("skill_"+row[0],0)),0,3): expected_money += float(row[5][level])
				expected_upgrades.erase("skill_"+row[0])
		for kind in Gear.OLD_MODS: expected_money += int(old.get("gear",{}).get(kind,0))*Gear.price(kind)
		if not old.has("repair_migrated") and int(old.get("done",0)) > 0:
			for id in Repair.BASE: expected_upgrades[id] = 1
		check(same_saved_value(Career.data.get("upgrades",{}),expected_upgrades),"slot %d permanent berth facilities match exactly; documented retired skill volumes are refunded" % slot)
		check(absf(float(Career.data.money)-expected_money) < 0.001,"slot %d exact old funds plus documented skill/module refunds are retained" % slot)
		if Career.data.get("upgrades",{}) != expected_upgrades:
			print("MIGRATION UPGRADE DIAGNOSTIC slot=",slot," expected=",expected_upgrades," actual=",Career.data.get("upgrades",{}))
		var owned := true
		for kind in old.get("gear",{}):
			if kind not in Gear.OLD_MODS and int(Career.data.get("gear",{}).get(kind,0)) != int(old.gear[kind]): owned = false
		check(owned,"slot %d reusable equipment is retained (existing retired-module refund migration remains separate)" % slot)
		check(Career.data.get("work_orders",{}) == old.get("work_orders",{}) and Career.data.get("plan_books",{}) == old.get("plan_books",{}),"slot %d migration invents neither engineering rewards nor purpose-qualified plans" % slot)
		var migrated := Career.data.duplicate(true)
		check(Career.save(),"slot %d migrated clone saves through the normal atomic career API" % slot)
		Career.data = {}
		Career.load_or_new()
		check(same_saved_value(Career.data,migrated),"slot %d migration is semantically exact across a second real disk load (JSON numeric types may normalize)" % slot)
		if not same_saved_value(Career.data,migrated):
			for key in Career.data:
				if Career.data[key] != migrated.get(key): print("MIGRATION SECOND LOAD slot=",slot," key=",key," before=",migrated.get(key)," after=",Career.data[key])
		check(FileAccess.get_sha256(original) == digest,"slot %d original SHA256 is unchanged" % slot)
	# Explicit pre-G4 control-only fixture, with exact preserved current G3
	# finances/stock. It does not claim that an old recording was purpose-tested.
	Career.path = "user://zp_test_g4_migration_legacy.json"
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.done = 39
	Career.data.money = 52748.0
	Career.data.loan = 1234.0
	Career.data.gear = {"probe":2,"anchor":3}
	Career.data.plans = {"tug":[{"do":"w","ctrl":"K-T","pre":[],"value":false}]}
	for key in ["work_orders","plan_books","plan_notes","settled_jobs"]: Career.data.erase(key)
	var legacy: Dictionary = Career.data.plans.duplicate(true)
	Career.save()
	Career.data = {}
	Career.load_or_new()
	check(Career.data.done == 39 and Career.data.money == 52748.0 and Career.data.loan == 1234.0,"declared pre-G4 fixture retains exact jobs, funds and debt")
	check(Career.data.gear == {"probe":2,"anchor":3} and Career.data.plans == legacy,"declared pre-G4 fixture retains reusable equipment and the complete control-only plan")
	var game := Game.new()
	game.ship_id = "tug"
	game.ship = {"berth":true}
	game.state = "berth"
	var plan := WorkPlan.new()
	plan.setup(game)
	check(plan.steps == legacy.tug,"the real executor loads the migrated control-only recording")
	var definitions: Array = plan.packages.catalogue
	check(definitions.size() == 1 and definitions[0].kind == "legacy" and definitions[0].targets.is_empty(),"the migrated recording is explicitly legacy, without forged structural-purpose qualification")
	plan.free()
	game.free()
	print("CAREER MIGRATION %s (%d checks, %d failed); real-save clones plus declared legacy fixture, no human playtesting" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)

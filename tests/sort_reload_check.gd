extends "res://tests/guide_check.gd"
# 42 号: a sorting batch survives a reload. A save keeps 15 significant digits, so the outputs
# worked out again from an uneven non-magnetic share differ in the last bit from the saved ones;
# that is the same record. Checks the comparison on a JSON round trip, then loads a copy of a
# real career that locked the desk (tests' own copy, never the player's file).
#   tools/run_test.sh tests/sort_reload_check.gd --fixed-fps 60

const COPY := "user://zp_test_slot3copy_career.json"


func _initialize() -> void:
	Career.path = COPY
	SaveGame.path = "user://zp_test_sort_reload_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	var Sort = preload("res://scripts/industrial_sort.gd")
	var probe = Sort.new()
	var share := 0.0451720918592268
	var expected := [{"item": "ferrous_scrap", "magnetic": true, "quantity": 1.0 - share, "suffix": "FE"}, {"item": "nonferrous_mix", "magnetic": false, "quantity": share, "suffix": "NF"}]
	var saved = JSON.parse_string(JSON.stringify(expected))
	var exact: bool = saved == expected
	check(probe._same_outputs(saved, expected), "after a save round trip the outputs are the same record (exact match: %s)" % exact)
	var wrong: Array = saved.duplicate(true)
	wrong[0].quantity = float(wrong[0].quantity) - 0.001
	check(not probe._same_outputs(wrong, expected), "a real difference is still caught")
	check(probe._same_profile({"version": 1, "nonmagnetic_share": share, "basis": "x"}, JSON.parse_string(JSON.stringify({"version": 1, "nonmagnetic_share": share, "basis": "x"}))), "the material record too")
	probe.free()
	if not FileAccess.file_exists(COPY):
		check(true, "(no copy of the locked career here: skipped)")
	else:
		Career.data = {}
		Career.load_or_new()
		check(str(Career.data.get("industrial_sort", {}).get("state", "")) == "complete", "the copy's last sorting batch is complete")
		Game.start_ship = "berth"
		Game.contract = {}
		SaveGame.load_requested = false
		g = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		await _frames(20)
		var svc = g.get("industrial_sort")
		check(svc != null and str(svc.fault) == "", "loaded, the sorting desk has no fault (%s)" % (str(svc.fault) if svc != null else "no desk"))
		g.queue_free()
		await _frames(4)
	print("SORT RELOAD %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()

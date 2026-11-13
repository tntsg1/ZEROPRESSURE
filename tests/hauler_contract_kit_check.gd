extends SceneTree
# 2026-11-12 (user on CF-51: "不是有好多无人机吗？我怎么才两个，而且我升级都升了呀"): a contract's kit is the
# career's upgrades as they were when it was signed; the third to seventh hauling drones bought after
# signing never came to that hulk. Now the hauling drones are read from the career as it is now:
#   A  a contract signed with two haulers, four more bought since: six on site
#   B  a dev job (DevPanel) keeps its own kit: two
#   C  the berth: six, as before
# Own test career and saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/hauler_contract_kit_check.gd

var fails := 0
const IDS := ["hauler", "hauler2", "hauler3", "hauler4", "hauler5", "hauler6"]


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Career.path = "user://zp_test_haulkit_career.json"
	SaveGame.path = "user://zp_test_haulkit_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _site(job: Dictionary, ship: String):
	Game.contract = job
	Game.start_ship = ship
	SaveGame.load_requested = false
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	var n: int = g.haulers().size()
	g.queue_free()
	await _frames(3)
	return n


func _run() -> void:
	Txt.zh = true
	Career.start_new()
	DevPanel.skip_guides()
	for id in IDS:
		Career.data.upgrades[id] = 1
	Career.save()
	# signed when only the first two were had
	var kit := {"hauler": 1, "hauler2": 1}
	var n: int = await _site({"id": "T-HAULKIT", "ship": "m14", "variant": 4242, "traps": [], "stars": 1, "kit": kit}, "m14")
	check(n == 6, "A a contract signed with two haulers, four bought since: %d on site" % n)
	n = await _site({"id": "T-HAULKIT-DEV", "ship": "m14", "variant": 4242, "traps": [], "stars": 1, "kit": kit, "dev": true}, "m14")
	check(n == 2, "B a dev job keeps its own kit: %d" % n)
	n = await _site({}, "berth")
	check(n == 6, "C the berth: %d" % n)
	SaveGame.clear()
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".works"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	print("HAULER CONTRACT KIT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

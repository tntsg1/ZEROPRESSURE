extends SceneTree
# User 2026-10-27 crash (variant.gd _hazards: key 'T1' on the berth's gas): a save made in the
# empty berth has no job; with a contract waiting, "continue" took that save for the contract's
# and loaded the berth as the contract's ship. Now: the save is left alone, the contract's ship
# comes in as it should. Own test saves only.
#   tools/run_test.sh tests/berth_save_contract_check.gd --fixed-fps 60
var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_berthsave_career.json"
	SaveGame.path = "user://zp_test_berthsave_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + what)
	if not ok:
		fails += 1


func _run() -> void:
	Txt.zh = true
	SaveGame.clear()
	# the empty berth, saved
	Game.contract = {}
	Game.start_ship = "berth"
	var b = load("res://scenes/main.tscn").instantiate()
	b.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(b)
	await _frames(30)
	b.state = "play"
	SaveGame.save(b)
	var saved := SaveGame.read(SaveGame.path)
	check(not saved.is_empty() and not saved.has("job"), "a save made in the empty berth has no job (ship %s)" % saved.get("ship", "-"))
	b.queue_free()
	await _frames(4)
	# a contract on M-14 waiting, and the game asked to continue
	var job := {"id": "T-BERTH-SAVE", "ship": "m14", "variant": 4242, "traps": ["wrong_valve"], "stars": 2}
	Game.contract = job
	Game.start_ship = "m14"
	SaveGame.load_requested = not saved.is_empty() and saved.has("job") and str(saved.job.get("id", "")) == str(job.id)
	check(not SaveGame.load_requested, "the berth's save is not taken for the contract's")
	# and even when asked to load it, a save of another ship is not used for this contract
	SaveGame.load_requested = true
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	check(g.ship_id == "m14" and not g.world.order.is_empty(), "the contract's own ship comes in (%s, %d pieces)" % [g.ship_id, g.world.order.size()])
	print("BERTH SAVE CONTRACT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)

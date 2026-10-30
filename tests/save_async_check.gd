extends SceneTree
# The autosave written on a worker thread (SaveGame.save_async, 2026-10-27 60 FPS work): the file
# it leaves is the same save the synchronous one writes; a read straight after waits for it; the
# game keeps changing while it writes without touching what is being written. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/save_async_check.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	SaveGame.path = "user://zp_test_save_async.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "nr95"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 40:
		await process_frame
	SaveGame.save(g)
	var sync: Dictionary = SaveGame.read()
	SaveGame.clear()
	var t0 := Time.get_ticks_usec()
	SaveGame.save_async(g)
	var main_ms := (Time.get_ticks_usec() - t0) / 1000.0
	# the game goes on changing what the save came from while the worker writes
	for p in g.world.pieces.values():
		p.cond = 0.123
	g.losses += 999.0
	var got: Dictionary = SaveGame.read()
	check(not got.is_empty(), "a read straight after the async save waits for it and finds the file (%.1f ms on the main thread)" % main_ms)
	got.erase("saved_at")
	sync.erase("saved_at")
	check(JSON.stringify(got.get("world", {})) == JSON.stringify(sync.get("world", {})), "the world written by the worker is the one the synchronous save wrote")
	check(float(got.get("game", {}).get("loss", -1.0)) == float(sync.get("game", {}).get("loss", -2.0)), "what changed after the call is not in it")
	SaveGame.save_async(g)
	SaveGame.save_async(g)
	SaveGame.settle()
	check(not SaveGame.read().is_empty(), "two calls close together: the second waits or is skipped, the file stays whole")
	SaveGame.clear()
	print("SAVE ASYNC %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

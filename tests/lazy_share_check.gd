extends SceneTree
# 认真拆有奖励, the lazy route's cap (scripts/clean_run.gd LAZY_CAP): each ship's lazy pay share as the
# game works it out on loading, against tools/clean_run_calib.py's (the same sum from the ship file),
# and what a mishap and the drain rack then take off a machine.
# godot --headless --path . --fixed-fps 60 -s tests/lazy_share_check.gd
var fails := 0
var checks := 0
# tools/clean_run_calib.py, LAZY_CAP 1.05
const WANT := {"tug": 1.0, "gr7": 1.0, "fr26": 0.69, "vt80": 0.82, "med47": 0.71}


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveGame.allow_test = false
	for sid in WANT:
		Game.contract = {}
		var g = load("res://scenes/main.tscn").instantiate()
		g.ship_id = sid
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		for i in 8:
			await process_frame
		var k: float = g.clean.lazy_k
		check(absf(k - float(WANT[sid])) < 0.03, "%s: lazy pay share %.2f (model %.2f)" % [sid, k, float(WANT[sid])])
		if k < 0.999:
			# a machine with leftovers, drained: it keeps k of its price, and the review says why
			var p = null
			for id in g.world.order:
				var q = g.world.pieces[id]
				if q.cls == "equip" and q.intact and CleanRun.benign(g.clean.residual(q)):
					p = q
					break
			if p != null:
				var v0: float = float(p.value)
				g.clean.lazy_cut(p)
				check(absf(float(p.value) - v0 * k) < 0.5 and g.devalued.any(func(x): return x[0] == "dv_leftover"), "%s: %s kept %.0f of %.0f" % [sid, p.tag, p.value, v0])
		g.queue_free()
		for i in 4:
			await process_frame
	print("lazy_share_check: %d/%d" % [checks - fails, checks])
	quit(1 if fails > 0 else 0)

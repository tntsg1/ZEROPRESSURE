extends SceneTree
# OB-90 sample ship, the readable chain (94 号; user 2026-10-28: segment by segment against a
# backplane at a time; the segments' state in words): the card names the mirror and both ways with
# money, time, risk and the crane the second needs; the board shows the cover, the locks and each
# ring; a cut close by with the cover up and a segment taken off unlocked are logged with their
# cause and money; the review groups the segments by their state, the losses by cause, and says
# what to do next time. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/ob90_chain_check.gd

const CoreAsset = preload("res://scripts/core_asset.gd")
var g
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ob90chain_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _free(p) -> void:
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	for id in g.world.lines:
		var l = g.world.lines[id]
		if l.alive and (l.a == p.id or l.b == p.id):
			g.world.kill_line(l)
	g.world.relink()


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "ob90"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null
	var op = g.optics

	# ---- the card
	var ca: Dictionary = CoreAsset.card(g)
	check(ca.get("name", "") == "主镜镜片" and ca.methods.size() == 2, "the card names the mirror and two ways")
	check(absf(float(ca.full) - 684000.0) < 1.0, "the mirror whole: %s" % Pal.money(ca.full))
	var blocks: Dictionary = ca.methods[1]
	check(str(blocks.name) == "按背板分块吊" and str(blocks.need).contains("吊车"), "the second way says it needs the crane: %s" % blocks.need)
	check(str(ca.methods[0].risks).contains("防尘罩") and (ca.methods[0].minutes as Array).size() == 2, "each with its time and its risk")

	# ---- the board as it starts
	var b0: Dictionary = CoreAsset.board(g)
	check(b0.rows.size() == 4 and str(b0.rows[0].name) == "锁" and b0.rows[0].alert, "the board: the locks open (alert), three rings")
	check((b0.warn as Array).any(func(w): return str(w).contains("防尘罩")), "and the cover up, warned")

	# ---- a cut close by, the cover up: dust, logged with its cause and money
	# the nearest piece to the mirror that is not part of it
	var near = null
	var mc: Vector2 = g.world.frame(g.world.tag("PM-U5")) * Geom.centroid(g.world.tag("PM-U5").poly)
	var best := INF
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or str(p.name_key) in ["p_ob_segment", "p_ob_actuator", "p_ob_backplane"]:
			continue
		var d: float = (g.world.frame(p) * Geom.centroid(p.poly)).distance_to(mc)
		if d < best:
			best = d
			near = p
	# (dust settles at most once every few seconds: past the first gap)
	await _frames(int(60 * (op.DUST_GAP + 0.5)))
	op.on_cut(near)
	await _frames(2)
	var b1: Dictionary = CoreAsset.board(g)
	check(not b1.recent.is_empty() and str(b1.recent[0].text).contains("粉尘污染"), "a cut close by: %s, −%s" % [str(b1.recent[0].text) if not b1.recent.is_empty() else "-", Pal.money(float(b1.recent[0].money) if not b1.recent.is_empty() else 0.0)])
	check(float(b1.worth) < 684000.0 - 1.0, "the mirror worth less: %s" % Pal.money(b1.worth))

	# ---- an outer segment taken off with its ring unlocked: it drops and cracks
	var seg = g.world.tag("PM-U7")
	_free(seg)
	await _frames(3)
	check(CoreAsset.mirror_state(g, "PM-U7") == "摔裂", "taken off unlocked: %s" % CoreAsset.mirror_state(g, "PM-U7"))

	# ---- the review
	var rv: Dictionary = CoreAsset.review(g)
	var words: Array = rv.units.map(func(u): return str(u.text))
	# one cut with the cover up dusted every segment within its reach: the whole mirror
	check(words.any(func(s): return s.begins_with("摔裂 1")) and words.any(func(s): return s.begins_with("粉尘污染")), "the segments by their state: %s" % str(words))
	var kinds: Array = rv.lost.map(func(l): return l.k)
	check(kinds.has("drop") and kinds.has("dust"), "the losses by cause: %s" % str(kinds))
	check(str(rv.advice) == CoreAsset.advice(str(rv.lost[0].k)), "next time: %s" % rv.advice)
	check(rv.reasons.size() >= 2, "why: %s" % str(rv.reasons))
	print("OB90 CHAIN %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

extends SceneTree
# 128 号 第 7 段: an old save with the removed achievements (section, pressure, field) — the career's
# feats and a job saved mid-strip — reads without a word. Test saves only.
var fails := 0
func check(ok: bool, what: String) -> void:
	if not ok: fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])

func _initialize() -> void:
	Career.path = "user://zp_test_seg7o_career.json"
	SaveGame.path = "user://zp_test_seg7o_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()

func _run() -> void:
	Career.data = Career.fresh()
	Career.data.feats = {"section": {"ship": "gr7", "job": "X", "at": 1, "measure": 9.0}, "pressure": {"ship": "gr7", "job": "X", "at": 1, "measure": 1800.0}, "field": {"ship": "m14", "job": "Y", "at": 2, "measure": 120.0}}
	Career.save()
	Career.load_or_new()
	Methods.migrate()
	check(Career.data.feats.size() == 3, "the old entries stay in the save, untouched")
	check(Gear.FEATS.is_empty() and Gear.FEAT_GRANT.is_empty(), "no achievement page row and no gift for them")
	Game.start_ship = "gr7"
	Game.contract = {}
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 5: await process_frame
	var st: Dictionary = g.gear.save_state() if g.gear.has_method("save_state") else {}
	st.feats = {"section": 9.0, "pressure": 1800.0, "field": 120.0, "propped": 0.0}
	g.gear.load_state(st)
	check(g.gear.feats_now.keys() == ["propped"], "a job saved mid-strip: the removed ones dropped, the rest kept (%s)" % str(g.gear.feats_now))
	print("SEG7 OLD FEATS %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(0)

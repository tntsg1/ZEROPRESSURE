extends "res://tests/guide_check.gd"
# 61 号: the main line's first batch. Every word the main line, the terminal's opening notices,
# the contract page and the home show is plain (no shorthand from the blacklist); the home has
# its one "next" card and no port cells; the growth page shows four kinds; a ship never trained
# for is taken without being sent to a course; the work-plan key opens nothing. Own saves only.
#   tools/run_test.sh tests/plain_text_check.gd --fixed-fps 60

const BLACK := ["资质", "排队一单", "备料", "整线加工", "炉次", "托管", "运驳", "定级", "待决策", "出钢中"]


func _initialize() -> void:
	Career.path = "user://zp_test_plain_text_career.json"
	SaveGame.path = "user://zp_test_plain_text_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _bad(s: String) -> String:
	for wd in BLACK:
		if s.find(wd) >= 0:
			return wd
	return ""


func _run() -> void:
	Txt.zh = true
	# ---- the words
	var texts: Array = []
	Career.data = Career.fresh()
	for id in Mainline.CHAPTERS:
		texts.append(Mainline.name_of(id))
		texts.append(str(Mainline.step(id).get("text", "")))
	for key in Onboarding.ORDER:
		texts.append(str(Onboarding.TEXT[key][0]))
	for key in ["tm_queued", "tm_hold", "rt_goals", "rp_missing", "tm_needs", "rt_short_berth", "rt_short_market", "rp_cls_power", "rp_cls_drive", "rp_cls_thermal", "rp_cls_structure"]:
		texts.append(Txt.t(key))
	for d in Ops.decisions(null):
		texts.append(str(d.title) + " " + str(d.get("why", "")))
	var hits: Array = []
	for s in texts:
		var b := _bad(str(s))
		if b != "":
			hits.append("%s ← %s" % [b, str(s).left(40)])
	check(hits.is_empty(), "the main line, notices, contract page and problems speak plainly %s" % str(hits))
	# ---- a fresh career at its terminal
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(20)
	# 97–109 号 (Codex.COURSES_REQUIRED, the seven special courses made a qualification): a ship never
	# trained for asks for its courses first (was: taken without one)
	check(not Game.G4_OPEN and not Codex.missing("fx70").is_empty() and Codex.required("fx70") == (Codex.missing("fx70") if Codex.COURSES_REQUIRED else []), "a ship never trained for: its untrained families are the courses it requires (fx70 %s)" % str(Codex.required("fx70")))
	Cap.save(root, "res://tests/out/plain_berth_zh.png")
	g.open_console("terminal")
	await _frames(6)
	var term = g.console_ui
	term._skip_boot()
	await _frames(40)
	check(term._ops_cells.is_empty(), "the home has no port cells")
	var nt := str(Mainline.step().get("text", ""))
	check(nt != "" and _bad(nt) == "", "its one card says the next step plainly (%s)" % nt)
	Cap.save(root, "res://tests/out/plain_home_zh.png")
	term.set_tab(5)
	await _frames(30)
	var cats: int = term.route_panel.categories.get_child_count() if term.route_panel != null else -1
	check(cats == 3, "the growth page shows three kinds: repairs, the port, upgrades (66 号: no ship catalogue) (%d)" % cats)
	Cap.save(root, "res://tests/out/plain_growth_zh.png")
	term.close()
	await _frames(6)
	g.queue_free()
	await _frames(4)
	print("PLAIN TEXT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()

extends "res://tests/guide_check.gd"
# 125/126 号: a heat seen as the player sees it, on a COPY of a career (written to the test path
# first): at the furnace desk, melting on the grid's share; the melt hurried on (a probe of what
# comes after, not 15 minutes of it); tapping; the billets cooling; the result card; the stores.
#   tools/run_test.sh tests/heat_flow_shot.gd --fixed-fps 60 -- file=<copy>


func _initialize() -> void:
	var src := _arg("file", "")
	Career.path = "user://zp_test_heatflow_career.json"
	SaveGame.path = "user://zp_test_heatflow_save.json"
	SaveGame.allow_test = true
	var f := FileAccess.open(Career.path, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(src))
	f.close()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _say(tag: String) -> void:
	var st: Dictionary = g.guide.step if g.guide != null and g.guide.get("step") != null else {}
	var inf: Dictionary = g.industrial_heat.info()
	print("[%s] info: %s · %s | guide: %s · %s | furnace label: %s" % [tag, inf.title, str(inf.text).replace("\n", " / "), str(st.get("title", "")), str(st.get("text", "")).replace("\n", " / "), str(preload("res://scripts/process_works.gd").furnace_state(g))])


func _shot(tag: String) -> void:
	_say(tag)
	Cap.save(root, "res://tests/out/heatflow_%s.png" % tag)


func _run() -> void:
	Txt.zh = true
	Career.load_or_new()
	await _spawn()
	Game.cine_in_tests = true
	await _frames(30)
	var ih = g.industrial_heat
	g.drone.global_position = ih.site()
	g.drone.freeze = true
	await _frames(90)
	await _shot("1_melting")
	# the melt hurried on: liquid and hot (what comes after is the probe)
	var fu = ih.furnace()
	fu.m_s = 0.0
	fu.m_l = 2.0
	fu.T = 1650.0
	var t := 0
	var seen := {}
	while t < 60 * 400:
		await _frames(1)
		t += 1
		var k := str(ih.info().key)
		var st := str(Career.data.get("industrial_heat", {}).get("state", ""))
		if k == "tapping" and not seen.has("tap"):
			seen.tap = true
			await _frames(120)
			await _shot("2_tapping")
		elif k == "cooling" and not seen.has("cool") and seen.has("tap"):
			seen.cool = true
			await _frames(200)
			await _shot("3_cooling")
		elif st == "complete" and not seen.has("done"):
			seen.done = true
			await _frames(30)
			await _shot("4_done")
			break
	var card = null
	for c in g.hud.get_children():
		if c is ResultCard:
			card = c
	print("RESULT CARD: %s" % ("shown" if card != null else "NONE"))
	if card != null:
		for b in card.find_children("*", "Button", true, false):
			if str(b.text).begins_with("查看仓库"):
				b.pressed.emit()
		await _frames(20)
		Cap.save(root, "res://tests/out/heatflow_5_store.png")
		print("store open: %s" % (g.console_ui != null and g.console_ui.get_script() == preload("res://scripts/company_store.gd")))
	print("HEAT FLOW DONE after %.0f s" % (t / 60.0))
	quit(0)

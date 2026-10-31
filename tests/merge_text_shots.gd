extends SceneTree
# 2026-10-30 the author's rewritten interface text (data/界面文字.txt merged back): the places that draw
# with no wrap and that text_fit does not measure: the permit, the opening's goal line, the belt
# prelude's typed lines, then the prologue card. Stills: tests/out/mergetext_<lang>_*.png; the widest
# belt line is printed. Own test saves only.
#   tools/run_test.sh tests/merge_text_shots.gd --fixed-fps 60 -- zh
#   tools/run_test.sh tests/merge_text_shots.gd --fixed-fps 60 -- en

const Cap = preload("res://tests/cap.gd")
var lang := "zh"
var g: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		lang = a[0]
	Txt.test_zh = lang == "zh"
	Txt.zh = lang == "zh"
	Career.path = "user://zp_test_mergetext_career.json"
	SaveGame.path = "user://zp_test_mergetext_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	Cap.save(root, "res://tests/out/mergetext_%s_%s.png" % [lang, name])


func _key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.keycode = k
		ev.pressed = down
		Input.parse_input_event(ev)
		await process_frame


func _prelude():
	for c in g.get_children():
		if c.get_script() == preload("res://scripts/belt_prelude.gd"):
			return c
	return null


func _run() -> void:
	Game.opening_in_tests = true
	Game.cine_in_tests = true
	Career.start_new()
	Career.data.company = "七号坞回收公司" if lang == "zh" else "BERTH SEVEN SALVAGE CO."
	Career.data.term_open = {}
	Career.save()
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	await _frames(30)
	var o = g.opening
	if o != null:
		o.card = 2
		o.t = 0.0
		await _frames(300)
		await _shot("1_card3")
		o.card = 3
		o.t = 0.0
		await _frames(420)
		await _shot("2_permit")
		await _key(KEY_ESCAPE)
	await _frames(90)
	await _shot("3_after_opening")
	var pre = null
	for i in 600:
		pre = _prelude()
		if pre != null:
			break
		await process_frame
	print("MERGETEXT prelude ", pre != null, " state ", g.state)
	if pre != null:
		while is_instance_valid(pre) and pre.t < 6.0:
			await process_frame
		await _shot("4_prelude_a")
		while is_instance_valid(pre) and pre.t < 11.0:
			await process_frame
		await _shot("5_prelude_b")
		await _key(KEY_ESCAPE)
	await _frames(120)
	await _shot("6_prologue")
	print("MERGETEXT DONE")
	quit(0)

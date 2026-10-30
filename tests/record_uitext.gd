extends "res://tests/record108.gd"
# 界面文字导出 (user 2026-10-29: "那些 UI 的介绍之类的文字你也要给我"): about 30 s of the opening cards,
# the words of data/台词.txt as the author wrote them. 31 characters the author used (曾、昼、夜、企、雇、
# 遵……) were not in the font subset — tools/subset_font.py did not read the .txt files — and drew as
# boxes; with the subset rebuilt they are all there. Own test saves only.
#   tools/run_test.sh tests/record_uitext.gd --write-movie recordings/record_uitext.avi --fixed-fps 30


func _initialize() -> void:
	Career.path = "user://zp_test_record_uitext_career.json"
	SaveGame.path = "user://zp_test_record_uitext_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Game.opening_in_tests = true
	cap_total = 3
	_caption_layer()
	# up to the middle left, clear of the cards' own captions (bottom) and the permit (centre)
	cap_layer.offset = Vector2(0, -330)
	Career.start_new()
	Career.data.company = "七号坞回收公司"
	Career.data.term_open = {}
	Career.save()
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _secs(0.5)
	_beat(1, "缺字补上了", "你改的台词里有 31 个字以前显示成方框")
	await _secs(9.5)
	if g.opening != null and g.opening.card < 2:
		g.opening.card = 2
		g.opening.t = 0.0
	_beat(2, "界面文字 7130 条", "本地一份 + 云端四份，短标签同字只列一次")
	await _secs(8.0)
	if g.opening != null and g.opening.card < 3:
		g.opening.card = 3
		g.opening.t = 0.0
	_beat(3, "证上的字都在了", "企业、雇员、遵守、涉及：以前是方框")
	await _secs(12.0)
	print("RECORD_UITEXT DONE")
	quit()

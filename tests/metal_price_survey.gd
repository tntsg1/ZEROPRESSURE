extends "res://tests/guide_check.gd"
# 108 号 第 5 件 (economy): every formal ship's scrap price a tonne (World.metal_price, from its file's
# metal_value over its structure), its structure's tonnes and its equipment's value — the figures
# the ingots' direct sale and the processing are weighed against. Prints a table.
#   tools/run_test.sh tests/metal_price_survey.gd --fixed-fps 60

const SKIP := ["arktest", "belt", "berth", "e07a", "e07b", "e07c", "e07d", "ts1", "ts1_course"]


func _initialize() -> void:
	Career.path = "user://zp_test_metalsurvey_career.json"
	SaveGame.path = "user://zp_test_metalsurvey_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	Career.data = Career.fresh()
	var rows: Array = []
	for f in DirAccess.get_files_at("res://ships"):
		var id := f.get_basename()
		if not f.ends_with(".json") or id in SKIP or id.begins_with("sp_"):
			continue
		Game.start_ship = id
		Game.contract = {}
		SaveGame.load_requested = false
		g = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		await _frames(3)
		var w = g.world
		var equip := 0.0
		for p in w.pieces.values():
			if p.cls == "equip":
				equip += float(p.value)
		rows.append([id, float(w.metal_price), float(w.structural_mass), equip, float(Ship.load_data(id).value.metal)])
		g.queue_free()
		await _frames(2)
	rows.sort_custom(func(a, b): return a[1] < b[1])
	for r in rows:
		print("SHIP %-8s  $%6.0f/t  %7.1f t  scrap $%8.0f  file $%8.0f  equip $%9.0f" % [r[0], r[1], r[2], r[1] * r[2], r[4], r[3]])
	print("SURVEY DONE %d" % rows.size())
	quit()

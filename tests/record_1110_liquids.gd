extends SceneTree
# Video (2026-11-10): every liquid in its real colour (scripts/liquid_colors.gd) — a ball of each
# and a stream leaking out of it, named, row by row. Set-up of tests/liquid_colors_shot.gd; test saves only.
#   tools/run_test.sh tests/record_1110_liquids.gd --write-movie G:/temp/zp_rec_20261110/liquids.avi --fixed-fps 60

const LC = preload("res://scripts/liquid_colors.gd")
const NAME := {"water": "水", "fuel": "煤油", "mmh": "甲基肼 MMH", "nto": "四氧化二氮 NTO", "glycol": "冷却液（乙二醇）",
	"oil": "润滑油", "hydraulic": "液压油", "foam": "灭火泡沫", "mud": "钻井泥浆", "lhe": "液氦", "lh2": "液氢",
	"lng": "液化天然气", "ln2": "液氮", "lox": "液氧", "refrigerant": "制冷剂", "solvent": "溶剂", "acid": "酸液", "nutrient": "营养液"}
var kit: Node
var order: Array = []


func _initialize() -> void:
	Career.path = "user://zp_test_rec1110_liq_career.json"
	SaveGame.path = "user://zp_test_rec1110_liq_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# 3 rows of 6, 7.5 m apart; the tetroxide last, well away from the hydrazine
func _cell(i: int) -> Vector2:
	return Vector2((i % 6) * 7.5, (i / 6) * 13.0 - 80.0) * Geom.M


func _run() -> void:
	Txt.zh = true
	order = LC.ORDER.duplicate()
	order.erase("nto")
	order.append("nto")
	Game.contract = {}
	Game.start_ship = "pod"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	g.tutorial = null
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1
	g.drone.global_position = Vector2(0.0, 80.0) * Geom.M
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans SC", "sans-serif"])
	var labels := Node2D.new()
	labels.z_index = 30
	g.world.add_child(labels)
	labels.draw.connect(func():
		for i in order.size():
			labels.draw_string(font, _cell(i) + Vector2(-170.0, 175.0), str(NAME.get(order[i], order[i])), HORIZONTAL_ALIGNMENT_CENTER, 340, 28, Color(0.92, 0.92, 0.92, 0.95)))
	labels.queue_redraw()
	kit.follow = func():
		g.tutorial = null
		if g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
			g.hud.voice.fold()
	# the screen furniture off for this line-up (only the liquids, their names and space behind)
	for cl in g.find_children("*", "CanvasLayer", true, false):
		if cl.layer >= 0:
			cl.visible = false
	for row in 3:
		kit.keep(false)
		g.zoom_override = 0.78
		g.cam_override = Vector2(18.75, row * 13.0 - 79.0) * Geom.M
		for k in 6:
			if row * 6 + k < order.size():
				g.liquids.spill(_cell(row * 6 + k), Vector2.ZERO, 2.0, str(order[row * 6 + k]), 1, 0.0, 0.0, true)
		await _frames(30)
		kit.keep(true, "liq")
		# each one leaks: a stream out of a hole at its top
		for f in 330:
			if f % 5 == 0 and f < 260:
				for k in 6:
					var i := row * 6 + k
					if i < order.size():
						g.liquids.spill(_cell(i) + Vector2(0.0, -1.6) * Geom.M, Vector2(0.35, -1.0), 0.012, str(order[i]), 2, 0.25, 2.2, true)
			await process_frame
	kit.keep(false, "end")
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	quit()

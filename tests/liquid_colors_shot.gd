extends SceneTree
# Every liquid in its real colour (scripts/liquid_colors.gd; user 2026-11-10 "不同液体用它现实里的
# 颜色"): one ball of each, side by side in open space beside the ship, labelled; then close-ups.
# tools/run_test.sh tests/liquid_colors_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
const LC = preload("res://scripts/liquid_colors.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_liqcol_career.json"
	SaveGame.path = "user://zp_test_liqcol_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "pod"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 20:
		await process_frame
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1
	g.drone.global_position = Vector2(0.0, 80.0) * Geom.M
	var base := Vector2(0.0, -30.0) * Geom.M
	var order: Array = LC.ORDER
	var labels := Node2D.new()
	labels.z_index = 30
	g.world.add_child(labels)
	var font: Font = ThemeDB.fallback_font
	labels.draw.connect(func():
		for i in order.size():
			var at: Vector2 = _cell(i)
			labels.draw_string(font, at + Vector2(-60.0, 170.0), str(order[i]), HORIZONTAL_ALIGNMENT_CENTER, 120, 26, Pal.ink(0.8)))
	for i in order.size():
		var at: Vector2 = _cell(i)
		g.liquids.spill(at, Vector2.ZERO, 2.0, str(order[i]), 1, 0.0, 0.0, true)
	labels.queue_redraw()
	g.zoom_override = 0.3
	g.cam_override = base + Vector2(25.0, 10.0) * Geom.M
	for i in 60:
		await process_frame
	Cap.save(root, "res://tests/out/liq_colors_all.png")
	for row in 3:
		g.zoom_override = 0.85
		g.cam_override = Vector2(18.75, row * 10.0 - 28.0) * Geom.M
		for i in 20:
			await process_frame
		Cap.save(root, "res://tests/out/liq_colors_row%d.png" % row)
	g.cam_override = _cell(3)
	g.zoom_override = 0.9
	for i in 20:
		await process_frame
	Cap.save(root, "res://tests/out/liq_colors_nto.png")
	quit()


# a grid 10 m apart; the tetroxide well away from the hydrazine (together they ignite)
func _cell(i: int) -> Vector2:
	if i == 3:
		return Vector2(25.0, 34.0) * Geom.M + Vector2(0.0, -30.0) * Geom.M
	return Vector2.ZERO + Vector2((i % 6) * 7.5, (i / 6) * 10.0) * Geom.M + Vector2(0.0, -30.0) * Geom.M

extends SceneTree
# G5.1 pictures: the loadout page's scrap switch, the assay bench and its console mid-reading.
# tools/run_test.sh tests/retain_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var finished := false
func _initialize() -> void:
	Career.path = "user://zp_test_retainshot_career.json"
	SaveGame.path = "user://zp_test_retainshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()
func _process(_dt: float) -> bool:
	return finished
func _frames(n: int) -> void:
	for i in n: await process_frame
func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 80000.0
	Career.data.port = {"trade": 1, "process": 1}
	Career.data.active = {"id": "G51-SHOT", "ship": "pod", "fee": 0, "time": 0, "fee_paid": true, "kit": {}, "items": {}, "scope": "full"}
	Career.save()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var page := LoadoutPanel.open(host, Callable(), Callable())
	await _frames(4)
	page.retain_btn.button_pressed = true
	await _frames(6)
	Cap.save(root, "res://tests/out/retain_loadout_zh.png")
	host.queue_free()
	Career.data.active = {}
	# a sorted ferrous lot from keel steel waiting for its assay
	preload("res://scripts/industrial_exchange.gd").command("view")
	var actor: Dictionary = Career.data.exchange.actors.company
	actor.lots["SHOT-SRC"] = {"id": "SHOT-SRC", "key": "mixed_metal:0", "available": 0.0, "total": 2.0, "consumed": 2.0, "origin": "receiver", "material_profile": {"version": 1, "nonmagnetic_share": 0.03, "basis": "ship_structure_keel"}}
	actor.lots["SHOT-SRC/FE"] = {"id": "SHOT-SRC/FE", "key": "ferrous_scrap:0", "available": 1.94, "total": 1.94, "origin": "magnetic_separation", "parents": [{"source_id": "SHOT-SRC", "quantity": 2.0}]}
	actor.stock["ferrous_scrap:0"] = 1.94
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(8)
	var at: Vector2 = g.industrial_assay.site()
	g.drone.global_position = at + Vector2(-1.5 * Geom.M, -1.0 * Geom.M)
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.freeze = true
	g.zoom_target = 1.6
	g.zoom_now = 1.6
	g.cam_override = at
	await _frames(30)
	Cap.save(root, "res://tests/out/retain_bench_zh.png")
	g.drone.global_position = at
	g.open_assay()
	await _frames(4)
	g.industrial_assay.begin("SHOT-SRC/FE")
	await _frames(600)
	Cap.save(root, "res://tests/out/retain_assay_zh.png")
	finished = true

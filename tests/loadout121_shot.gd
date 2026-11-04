extends SceneTree
# 121 号: the loadout page in the user's words (2026-11-04). Own test saves only.
#   tools/run_test.sh tests/loadout121_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var finished := false
func _initialize() -> void:
	Career.path = "user://zp_test_loadout121_career.json"
	SaveGame.path = "user://zp_test_loadout121_save.json"
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
	Career.data.money = 3312940.0
	Career.data.gear = {"anchor": 1, "pump": 1}
	Career.data.active = {"id": "SM-009", "ship": "gr7", "fee": 0, "time": 0, "fee_paid": true, "kit": {}, "items": {}, "scope": "full"}
	Career.save()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	LoadoutPanel.open(host, Callable(), Callable())
	await _frames(8)
	Cap.save(root, "res://tests/out/loadout121_zh.png")
	print("LOADOUT121 DONE")
	finished = true
	quit(0)

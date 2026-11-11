extends SceneTree
# 2026-11-11 炭黑 v2: the save cards (title.gd's slots under the terminal title), fully open, the pointer
# on the second card. A fixture: never the player's real slots, and nothing is entered or written.
#   tools/run_test.sh tests/charcoal_slots_shot.gd --fixed-fps 60 -- tag=v2 lang=zh
const Cap = preload("res://tests/cap.gd")

class TestTitle extends "res://scripts/title_terminal.gd":
	var fixture: Array = []
	func _refresh_home() -> void:
		select_home(fixture, [10, 30, 0])
	func _open_slots() -> void:
		super._open_slots()
		slots = fixture.duplicate(true)
	func _enter(_i: int) -> void:
		pass

var title: TestTitle
var tag := "after"
var lang := "zh"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		if a.begins_with("lang="):
			lang = a.substr(5)
	_run.call_deferred()


func frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.cfg_path = "user://zp_test_charcoal_slots.cfg"
	Txt.test_zh = lang == "zh"
	Txt.zh = lang == "zh"
	Txt.dev = false
	root.add_child(preload("res://tests/test_window.gd").new())
	title = TestTitle.new()
	title.fixture = [
		{"company": "旧港回收" if lang == "zh" else "OLD PORT SALVAGE", "certified": false, "money": 0, "loan": 0, "done": 0, "rep": 0, "time": 300, "active": {}},
		{"company": "远航回收" if lang == "zh" else "FAR REACH SALVAGE", "certified": true, "money": 185000, "loan": 42000, "done": 12, "rep": 30, "time": 31000, "active": {"id": "DEV-ARK", "ship": "ark01"}}, {}]
	root.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.pointer_override = Vector2(-100, -100)
	await frames(10)
	Txt.zh = lang == "zh"
	title._open_slots()
	await frames(20)
	title.pointer_override = title._slot_rect(1).get_center()
	await frames(150)
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://tests/out/charcoal_slots_%s_%s.png" % [tag, lang])
	print("CHARCOAL SLOTS SHOT done")
	quit(0)

extends "res://tests/hud_center_check.gd"
# 2026-11-12 update video: the HUD's centre — hover outline and tag, middle-click a danger part for its
# card (the check's own run with its picture pauses; the pointer is the bot's aim). Test saves only.
#   tools/run_test.sh tests/record_1112_hud.gd --write-movie G:/temp/zp_upd1112/hud.avi --fixed-fps 60 -- shots rec
var tick: Node


func _initialize() -> void:
	super()
	tick = preload("res://tests/rec_tick_1112.gd").new()
	root.add_child(tick)

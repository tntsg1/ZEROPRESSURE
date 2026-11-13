extends "res://tests/crew_anim_shot.gd"
# 2026-11-12 update video: the works crew on the berth lights (the shot's own camera), the whole job on
# the timeline (REC_T). Test saves only.
#   tools/run_test.sh tests/record_1112_crew.gd --write-movie G:/temp/zp_upd1112/crew.avi --fixed-fps 60 -- job=lights tag=rec
var tick: Node


func _initialize() -> void:
	super()
	tick = preload("res://tests/rec_tick_1112.gd").new()
	root.add_child(tick)

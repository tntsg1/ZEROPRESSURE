extends "res://tests/baler_flow_check.gd"
# 2026-11-12 update video: the baler's whole run by train (the check's own camera on the press);
# the press phase printed when it changes ("REC_EV <frame> press=<phase>") for the cut. Test saves only.
#   tools/run_test.sh tests/record_1112_baler.gd --write-movie G:/temp/zp_upd1112/baler.avi --fixed-fps 60
var tick: Node
var _ph := ""


func _initialize() -> void:
	super()
	tick = preload("res://tests/rec_tick_1112.gd").new()
	root.add_child(tick)
	tick.follow = func():
		var p := str(ProcessLine.press_phase()[0]) if ProcessLine.press() != null else ""
		if p != _ph:
			_ph = p
			print("REC_EV %d press=%s" % [tick.frame, p])

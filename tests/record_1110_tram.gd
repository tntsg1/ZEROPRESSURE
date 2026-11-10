extends "res://tests/tram_block_freight_check.gd"
# Video (2026-11-10): the shuttle parked at the trade port's stop gives way, the freight train comes
# in and unloads. The run of tests/tram_block_freight_check.gd, its camera; test saves only.
# Prints REC_EV lines (frame, what) so the long stretches can be sped up when cut.
#   tools/run_test.sh tests/record_1110_tram.gd --write-movie G:/temp/zp_rec_20261110/tram.avi --fixed-fps 60

var kit: Node
var started := false
var arrived_f := -1
var last := {}


func _initialize() -> void:
	Career.path = "user://zp_test_rec1110_tram_career.json"
	SaveGame.path = "user://zp_test_rec1110_tram_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	want_shots = false
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	kit.follow = _watch
	_run.call_deferred()


func _ev(key: String, v) -> void:
	if str(last.get(key, "")) != str(v):
		last[key] = v
		print("REC_EV %d %s=%s" % [kit.frame, key, str(v)])


func _watch() -> void:
	if g == null or not is_instance_valid(g):
		return
	if g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
		g.hud.voice.fold()
	if not started and not HallMarket.order("OTB").is_empty():
		started = true
		kit.keep(true, "tram")
	if not started:
		return
	_ev("tram", "%s/%s" % [str(g.tram.at), str(g.tram.phase)])
	var tr := _order_train()
	if not tr.is_empty():
		_ev("train", "%s moving=%s" % [str(tr.place), str(tr.moving)])
	if arrived_f < 0 and FW.order_arrived("OTB") >= 1:
		arrived_f = kit.frame
		_ev("arrived", true)
	if arrived_f >= 0 and kit.frame > arrived_f + 420:
		kit.keep(false, "end")
		started = false
		arrived_f = 1 << 30
		quit()

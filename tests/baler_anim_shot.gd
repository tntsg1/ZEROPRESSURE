extends "res://tests/guide_check.gd"
# The baler's whole run (2026-11-12, user: "压块机从火车上卸下来，然后再放到这个压块机里面，这动画做得很
# 糟糕"): key frames from the warehouse's piece arriving at the processing district to the bale going
# back down the hatch, each phase held at a fixed point (Career.data.press.t pinned) so before / after
# compare frame for frame. tests/out/baler_<tag>_<nn>_<phase>.png
#   tools/run_test.sh tests/baler_anim_shot.gd --fixed-fps 60 -- tag=before [what=part|raw]


func _initialize() -> void:
	Career.path = "user://zp_test_baler_shot_career.json"
	SaveGame.path = "user://zp_test_baler_shot_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


# the press's job pinned at t seconds into its run for n frames
func _hold(t: float, n: int) -> void:
	for i in n:
		ProcessLine.press().t = t
		await process_frame


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(10)
	var raw := _arg("what", "part") == "raw"
	var job := {"id": "B1", "pl": {}, "name": "TEST", "mass": 0.4 if not raw else 1.2, "value": 100.0, "cells": 1,
		"look": {"cat": "raw" if raw else "part", "ship": "tug", "tag": "BAT-T", "nk": "p_battery", "key": "", "w": 1, "h": 1},
		"charged": _arg("charged", "0") == "1", "held": "", "ship": "tug", "hx": float(_arg("hx", "48.4"))}
	var pr := ProcessLine.press()
	pr.jobs = []
	pr.cur = job
	pr.t = 0.0
	var box := PortStructure.box("process")
	var M := PortStructure.M()
	g.drone.global_position = box.position + Vector2(30.0, 24.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	var frames := []
	var acc := 0.0
	var seq: Array = ProcessLine.press_seq(job)
	for ph in seq:
		var d := float(ProcessLine.press_len(job, ph))
		var us := [0.5]
		match ph:
			"land": us = [0.03, 0.2, 0.45, 0.7, 0.85, 0.97]
			"feed", "eject": us = [0.02, 0.3, 0.45, 0.6, 0.8, 0.95]
			"press": us = [0.2, 0.55, 0.9]
			"reject": us = [0.1, 0.3, 0.45, 0.6, 0.75, 0.9]
			"approach", "probe": us = [0.3, 0.9]
		for u in us:
			frames.append([ph, acc + d * u, u])
		acc += d
	var tag := _arg("tag", "after")
	var i := 0
	for f in frames:
		g.drone.global_position = box.position + Vector2(30.0, 24.0) * M
		_put(box.position + Vector2(40.0 if _arg("tag", "after") != "before" else 36.0, 22.3 if _arg("tag", "after") != "before" else 20.5) * M, 1080.0 / ((16.5 if _arg("tag", "after") != "before" else 13.0) * M))
		await _hold(float(f[1]), 40)
		Cap.save(root, "res://tests/out/baler_%s_%02d_%s_%02d.png" % [tag, i, f[0], int(float(f[2]) * 100.0)])
		i += 1
	# the wider frame: the freight spur over it
	_put(box.position + Vector2(36.0, 16.0) * M, 1080.0 / (26.0 * M))
	await _hold(1.0, 30)
	Cap.save(root, "res://tests/out/baler_%s_wide.png" % tag)
	print("BALER SHOTS %d" % (i + 1))
	quit(0)

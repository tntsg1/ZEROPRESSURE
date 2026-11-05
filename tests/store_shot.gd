extends "res://tests/guide_check.gd"
# 126 号: the company stores page, on a COPY of a career (written to the test path first; the real
# save is never opened for writing) — all, equipment, products, a part picked, then out and in again.
#   tools/run_test.sh tests/store_shot.gd --fixed-fps 60 -- file=<copy> tag=user


func _initialize() -> void:
	var src := _arg("file", "")
	Career.path = "user://zp_test_store_career.json"
	SaveGame.path = "user://zp_test_store_save.json"
	SaveGame.allow_test = true
	if src != "":
		var f := FileAccess.open(Career.path, FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string(src))
		f.close()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _shot(name: String) -> void:
	await _frames(12)
	Cap.save(root, "res://tests/out/store126_%s_%s.png" % [_arg("tag", "user"), name])


func _run() -> void:
	Txt.zh = true
	Career.load_or_new()
	await _spawn()
	await _frames(30)
	g.open_store()
	await _frames(6)
	var ui = g.console_ui
	var by := {}
	for it in ui.items:
		by[str(it.cat)] = int(by.get(str(it.cat), 0)) + 1
	print("STORE: %s" % JSON.stringify(by))
	for it in ui.items:
		print("  %s · %s · %s · %d×%d" % [it.cat, it.name, it.qty, int(it.w), int(it.h)])
	await _shot("all")
	ui.open_kind("equip")
	await _shot("equip")
	ui.open_kind("product")
	await _shot("product")
	ui.open_kind("material")
	await _shot("material")
	var n0: int = ui.items.size()
	ui._close()
	await _frames(10)
	# out and in again: the same things
	Career.load_or_new()
	g.open_store()
	await _frames(6)
	print("AGAIN: %d things (was %d)" % [g.console_ui.items.size(), n0])
	print("STORE SHOTS DONE")
	quit(0)

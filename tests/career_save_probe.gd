extends SceneTree
# Where Career.save's time goes (2026-11-12: a works step's save stalled the frame 10–15 ms): the JSON,
# the checksum, the file write and the renames, each timed. Own test career only.
#   godot --headless --path . -s tests/career_save_probe.gd


func _initialize() -> void:
	Career.path = "user://zp_test_save_probe_career.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	if "big" in OS.get_cmdline_user_args():
		# a copy of a big career (the probe never touches the real file)
		Career.data = SaveGame.read_career("user://zp_test_save_probe_big_career.json")
	else:
		Career.start_new()
		DevPanel.skip_guides()
	Career.save()
	var file := Career.path
	var full := ProjectSettings.globalize_path(file)
	for n in 5:
		var t0 := Time.get_ticks_usec()
		var body := JSON.stringify(Career.data)
		var t1 := Time.get_ticks_usec()
		var sum := body.md5_text()
		var t2 := Time.get_ticks_usec()
		var f := FileAccess.open(file + ".tmp", FileAccess.WRITE)
		f.store_string("X 1 %s\n" % sum)
		f.store_string(body)
		f.close()
		var t3 := Time.get_ticks_usec()
		if FileAccess.file_exists(file + ".bak"):
			DirAccess.remove_absolute(full + ".bak")
		DirAccess.rename_absolute(full, full + ".bak")
		DirAccess.rename_absolute(full + ".tmp", full)
		var t4 := Time.get_ticks_usec()
		var t7 := Time.get_ticks_usec()
		var copy := Career.data.duplicate(true)
		var t8 := Time.get_ticks_usec()
		print("    deep copy %.2f ms" % [(t8 - t7) / 1000.0])
		var t5 := Time.get_ticks_usec()
		Career.save()
		var t6 := Time.get_ticks_usec()
		print("  %d KB: json %.2f md5 %.2f write %.2f renames %.2f | Career.save %.2f ms" % [body.length() / 1024, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0, (t6 - t5) / 1000.0])
	for ext in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(full + ext)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://zp_test_save_probe_big_career.json"))
	quit()

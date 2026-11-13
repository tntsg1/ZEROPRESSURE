extends SceneTree
# 2026-11-12 (user's hard rule: a test never touches the player's own saves; a real training save was
# written and retired by a test that forgot its training path): a run of a test script refuses, at
# the lowest write, every player file — the full game's career / contract / training / special course
# / exam / best / settings ("zeropower_*", with .bak / .tmp / .done / .works), the slots ("zp_slot*"),
# and the playtest build's files and folders ("playtest*"). Every write tried here is aimed into this
# test's own sandbox folder under a player's file NAME, so even a broken guard could not reach a real
# file; the real files' times are read before and after (read only). No scene: safe while the game runs.
#   tools/run_test.sh tests/save_guard_check.gd

const SANDBOX := "user://zp_test_save_guard"
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	_run.call_deferred()


func _real_times() -> Dictionary:
	var out := {}
	var dir := ProjectSettings.globalize_path("user://")
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if SaveGame.player_file("user://" + f):
			out[f] = FileAccess.get_modified_time(dir.path_join(f))
	return out


func _exists(name: String) -> bool:
	var p := SANDBOX + "/" + name
	return FileAccess.file_exists(p) or FileAccess.file_exists(p + ".tmp") or FileAccess.file_exists(p + ".done")


func _run() -> void:
	var before := _real_times()
	check(Career._test_run(), "(this is a test run)")
	# ---- what counts as the player's
	var players := ["user://zeropower_career.json", "user://zeropower_career.json.works", "user://zeropower_save.json.bak",
		"user://zeropower_training.json", "user://zeropower_training.json.done", "user://zeropower_save_exam.json",
		"user://zeropower_best.json", "user://zeropower_settings.cfg", "user://zp_slot2_training.json", "user://zp_slot3_save.json.done",
		"user://playtest_slot1_career.json", "user://playtest_save.json", "user://playtest_career.json", "user://playtest_settings.cfg",
		"user://playtest_activation.cfg", "user://playtest_records/2026-11-12/report.html", "user://playtest/2026/entries.json",
		"user://playtest_feedback_outbox/fb_1.json", ProjectSettings.globalize_path("user://zeropower_career.json")]
	for p in players:
		check(SaveGame.player_file(p) and SaveGame.forbidden(p), "refused: %s" % p)
	for p in ["user://zp_test_x_career.json", "user://zp_test_playtest_save.json", "user://zp_test_x_training.json.done", "res://ships/tug.json", "G:/zeropower_save_backup/x/zeropower_career.json"]:
		check(not SaveGame.forbidden(p), "a test's own (or not user://): allowed: %s" % p)
	# ---- the playtest build's files are a test's own copies in a test run
	Demo.forced = true
	check(not SaveGame.player_file(Demo.CFG) and Demo.user_file("playtest_save.json").begins_with("user://zp_test_"), "the playtest build's files in a test run are zp_test_ copies (%s)" % Demo.CFG)
	Demo.forced = false
	# ---- every low-level writer, aimed at a player's name inside the sandbox
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SANDBOX))
	SaveGame.allow_test = true
	check(not SaveGame.write_file(SANDBOX + "/zeropower_training.json", {"x": 1}) and not _exists("zeropower_training.json"), "SaveGame.write_file refused (the training course)")
	check(not SaveGame.write_file(SANDBOX + "/zp_slot2_save.json", {"x": 1}) and not _exists("zp_slot2_save.json"), "  (a slot's contract)")
	# a file already there under a player's name is never retired to .done
	var bait := SANDBOX + "/zeropower_save.json"
	var f := FileAccess.open(bait, FileAccess.WRITE)
	f.store_string("bait")
	f.close()
	SaveGame.clear(bait)
	check(FileAccess.file_exists(bait) and not FileAccess.file_exists(bait + ".done"), "SaveGame.clear refused: nothing renamed to .done")
	var keep_career := Career.path
	Career.path = SANDBOX + "/zeropower_career.json"
	Career.data = Career.fresh()
	check(not Career.save() and not _exists("zeropower_career.json"), "Career.save refused")
	Career.path = keep_career
	var keep_cfg := Txt.cfg_path
	Txt.cfg_path = SANDBOX + "/zeropower_settings.cfg"
	Txt.save_settings(false)
	check(not _exists("zeropower_settings.cfg"), "Txt.save_settings refused even when told it is not a test")
	Txt.cfg_path = keep_cfg
	var keep_act: String = Demo.CFG
	Demo.CFG = SANDBOX + "/playtest_activation.cfg"
	Demo.touched()
	check(not _exists("playtest_activation.cfg"), "the playtest activation refused")
	Demo.CFG = keep_act
	check(SaveGame.forbidden(SaveGame.BEST), "the best record refused (not written here: its path is the real one)")
	check(SaveGame.forbidden(SANDBOX + "/zeropower_career.json.works"), "the works journal refused (checked on its worker too)")
	# ---- the real files: not one changed
	var after := _real_times()
	var changed: Array = []
	for k in after:
		if not before.has(k) or int(before[k]) != int(after[k]):
			changed.append(k)
	check(changed.is_empty() and before.size() == after.size(), "the player's own files untouched (%d checked) %s" % [after.size(), str(changed)])
	# clean the sandbox
	var d := DirAccess.open(ProjectSettings.globalize_path(SANDBOX))
	if d != null:
		for n in d.get_files():
			d.remove(n)
	print("SAVE GUARD %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)

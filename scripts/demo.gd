class_name Demo
extends RefCounted
# The playtest build (user 2026-10-30: "a a a b a … 做成联网的 … a c"):
#   Q1 A  the first hour only: an end card at 60 minutes played, or once the main line reaches the 88 m
#         berth chapter, whichever comes first
#   Q2 A  Chinese and English, by the system language (the settings switch it)
#   Q3 A  the playtest recorder on by default, told on the gate, switchable in the settings
#   Q4 B  the developer bench kept but hidden: F12 does nothing unless started with --dev
#   Q5    one code, one machine, checked online at playtest.stellarascensiongame.com (server/playtest),
#         a hard end date, the record uploaded at the end only if the player says yes
#   Q6 A  its own saves and settings, apart from the full game's
#   Q7 C  three questions at the end, answered in the game, kept with the record
# A playtest build is the "Windows Playtest" export (feature tag "playtest"); --demo starts the same
# from the editor or a normal build.

const URL := "https://playtest.stellarascensiongame.com"
const EXPIRES := "2026-11-21"        # last day (UTC), the same as the server's
const LIMIT_S := 3600.0               # the first hour
const GRACE_S := 3 * 86400            # offline, a machine that checked in within this still plays
const CFG := "user://playtest_activation.cfg"

static var forced := false            # tests turn it on without the export tag
static var watch_in_tests := false    # tests let the end card come up
static var gate_open := false         # the gate is up: the title answers nothing behind it


static func on() -> bool:
	if forced or OS.has_feature("playtest"):
		return true
	return "--demo" in OS.get_cmdline_args() or "--demo" in OS.get_cmdline_user_args()


static func dev_allowed() -> bool:
	return not on() or "--dev" in OS.get_cmdline_args() or "--dev" in OS.get_cmdline_user_args()


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# before anything loads: the build's own saves, settings and record folder; the recorder on by default
static func apply() -> void:
	if not on():
		return
	if SaveGame.path != "user://playtest_save.json":
		print("ZERO PRESSURE playtest build, until ", EXPIRES)
	SaveGame.path = "user://playtest_save.json"
	Career.path = "user://playtest_career.json"
	Txt.cfg_path = "user://playtest_settings.cfg"
	Playtest.root = "user://playtest_records"
	Txt.playtest = true


static func expired() -> bool:
	var until := Time.get_unix_time_from_datetime_string(EXPIRES + "T23:59:59")
	return Time.get_unix_time_from_system() > until


static func machine() -> String:
	return OS.get_unique_id().sha256_text().substr(0, 32)


static func _cfg() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(CFG)
	return cf


static func code() -> String:
	return str(_cfg().get_value("gate", "code", ""))


static func remember(c: String) -> void:
	var cf := _cfg()
	cf.set_value("gate", "code", c)
	cf.set_value("gate", "machine", machine())
	cf.set_value("gate", "last_ok", int(Time.get_unix_time_from_system()))
	cf.save(CFG)


static func touched() -> void:
	var cf := _cfg()
	cf.set_value("gate", "last_ok", int(Time.get_unix_time_from_system()))
	cf.save(CFG)


static func forget() -> void:
	var cf := _cfg()
	if cf.has_section_key("gate", "code"):
		cf.erase_section_key("gate", "code")
	cf.save(CFG)


static func within_grace() -> bool:
	var last := int(_cfg().get_value("gate", "last_ok", 0))
	return last > 0 and int(Time.get_unix_time_from_system()) - last < GRACE_S


static func finished() -> bool:
	return bool(_cfg().get_value("gate", "done", false))


static func mark_finished() -> void:
	var cf := _cfg()
	cf.set_value("gate", "done", true)
	cf.save(CFG)


# what an error from the server means, in words
static func error_text(e: String) -> String:
	match e:
		"used":
			return w("这个激活码已经在另一台电脑上用过了。", "This code has already been used on another computer.")
		"unknown":
			return w("没有这个激活码，请检查输入。", "There is no such code. Please check it.")
		"revoked":
			return w("这个激活码已经停用。", "This code has been withdrawn.")
		"expired":
			return w("试玩已经在 %s 结束了。谢谢！" % EXPIRES, "The playtest ended on %s. Thank you!" % EXPIRES)
		"invalid":
			return w("激活码格式不对，应该是 ZP-XXXX-XXXX。", "That isn't a code: it looks like ZP-XXXX-XXXX.")
		"offline":
			return w("连不上服务器，请检查网络后再试。", "Can't reach the server. Check the connection and try again.")
	return w("出了点问题（%s），请稍后再试。" % e, "Something went wrong (%s). Please try again." % e)


# ---------------------------------------------------------------- the end of the first hour

# called every frame by the game: the end card once the hour is up or the 88 m chapter is reached
static func watch(g) -> void:
	if not on() or g == null or (g.testing and not watch_in_tests) or g.get_meta("demo_end", false):
		return
	if g.state != "play" or g.menu_open or Career.data.is_empty():
		return
	var t := float(Career.data.get("time", 0.0))
	var reached: bool = Mainline.chapter() == "berth88"
	if t < LIMIT_S and not reached:
		return
	g.set_meta("demo_end", true)
	var card = preload("res://scripts/demo_end.gd").new()
	g.add_child(card)


# the record folder zipped (every session, the answers with them) for the upload
static func zip_records() -> PackedByteArray:
	var src := ProjectSettings.globalize_path(Playtest.root)
	var out := ProjectSettings.globalize_path("user://playtest_upload.zip")
	var zp := ZIPPacker.new()
	if zp.open(out) != OK:
		return PackedByteArray()
	_zip_dir(zp, src, "")
	zp.close()
	return FileAccess.get_file_as_bytes(out)


static func _zip_dir(zp: ZIPPacker, base: String, rel: String) -> void:
	var d := DirAccess.open(base.path_join(rel) if rel != "" else base)
	if d == null:
		return
	for f in d.get_files():
		var r := rel.path_join(f) if rel != "" else f
		zp.start_file(r)
		zp.write_file(FileAccess.get_file_as_bytes(base.path_join(r)))
		zp.close_file()
	for sub in d.get_directories():
		_zip_dir(zp, base, rel.path_join(sub) if rel != "" else sub)

class_name Demo
extends RefCounted
# The playtest build (user 2026-10-30: "a a a b a … 做成联网的 … a c"):
#   Q1 A  (2026-11-11: now 5 hours) an end card at LIMIT_S played, or once the main line reaches the 88 m
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
# Against a crack (user 2026-10-30 "只打包第一小时+水印"): the pack carries only SHIPS, so a cracked
# build still has only the first hour's ships. The code goes on the window's title bar and nowhere in
# the picture (user: "激活码水印可以不搞……边框上有的话就行").
# 公测版 (user 2026-11-08, "b a c a b"): the build goes up for anyone to download —
#   Q1 B  no codes: the first start registers this machine online (its fingerprint) and goes straight in;
#         every start checks in (/hello), offline it plays on for 3 days after the last check-in; a switch
#         on the server stops everyone ("公测已结束，谢谢"). The code flow is kept behind CODES.
#   Q2 A  still the first hour and Demo.SHIPS only. Since the port redesign the main line reaches the
#         tug yard (a hulk over 44 m) before the 88 m berth, and the pack has none longer than 44 m, so
#         the first hour ends where the main line asks for a bigger hulk: every chapter before "tug" done.
#   Q3 C  no end date; the switch stops it
#   Q4 A  feedback from the pause menu at any time (scripts/demo_feedback.gd)

const URL := "https://playtest.stellarascensiongame.com"
const VERSION := "0.9-公测-20261112"
const CODES := false                  # the 10-30 code gate; the public build registers the machine instead
const LIMIT_S := 18000.0              # 5 hours (user 2026-11-11 "5个小时，或者是两个小时")
const GRACE_S := 3 * 86400            # offline, a machine that checked in within this still plays
# 2026-11-12: a test run uses its own copies of the build's files ("zp_test_" + the name), never the
# player's (tests/demo_check.gd used to delete and rewrite the real ones)
static var CFG := user_file("playtest_activation.cfg")
# every ship file in the pack: what fits the 50 m berth (the 88 m chapter ends the playtest), the
# training rigs and the berth itself. The export preset lists the same (tests/demo_pack_check.gd).
const SHIPS := ["tug", "pod", "s09", "gr7", "h22", "jd38", "qc30", "st40",
	"berth", "belt", "e07a", "e07b", "e07c", "e07d", "ts1",
	"sp_atmos", "sp_cryo", "sp_energy", "sp_fluid", "sp_isolate", "sp_load", "sp_precise"]

static var forced := false            # tests turn it on without the export tag
static var base_url := URL            # tests point the gate at a dead address (offline)
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
	if SaveGame.path != user_file("playtest_save.json"):
		print("ZERO PRESSURE public test ", VERSION)
	SaveGame.path = user_file("playtest_save.json")
	Career.path = user_file("playtest_career.json")
	Txt.cfg_path = user_file("playtest_settings.cfg")
	Playtest.root = user_file("playtest_records")
	Txt.playtest = true


# one of the build's own files: the player's in a real run, a test's own copy in a test run
static func user_file(name: String) -> String:
	return ("user://zp_test_" if Career._test_run() else "user://") + name


# no end date any more (Q3 C): the server's switch ends it
static func expired() -> bool:
	return false


static func machine() -> String:
	return OS.get_unique_id().sha256_text().substr(0, 32)


static func _cfg() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(CFG)
	return cf


# a test never writes the player's activation (SaveGame.forbidden)
static func _save(cf: ConfigFile) -> void:
	if not SaveGame.forbidden(CFG):
		cf.save(CFG)


static func code() -> String:
	return str(_cfg().get_value("gate", "code", ""))


static func remember(c: String) -> void:
	var cf := _cfg()
	cf.set_value("gate", "code", c)
	cf.set_value("gate", "machine", machine())
	cf.set_value("gate", "last_ok", int(Time.get_unix_time_from_system()))
	_save(cf)


static func touched() -> void:
	var cf := _cfg()
	cf.set_value("gate", "last_ok", int(Time.get_unix_time_from_system()))
	_save(cf)


static func forget() -> void:
	var cf := _cfg()
	if cf.has_section_key("gate", "code"):
		cf.erase_section_key("gate", "code")
	_save(cf)


static func within_grace() -> bool:
	var last := int(_cfg().get_value("gate", "last_ok", 0))
	return last > 0 and int(Time.get_unix_time_from_system()) - last < GRACE_S


static func finished() -> bool:
	return bool(_cfg().get_value("gate", "done", false))


static func mark_finished() -> void:
	var cf := _cfg()
	cf.set_value("gate", "done", true)
	_save(cf)


# the version (and with the old gate the code) on the window's title bar from the moment the gate lets go
static func mark(tree: SceneTree) -> void:
	if not on():
		return
	var t := "%s · %s · %s" % [ProjectSettings.get_setting("application/config/name"), w("公测版", "PUBLIC TEST"), VERSION]
	if CODES and code() != "":
		t += " · " + code()
	tree.root.title = t


# the version small in the title's bottom right corner
static func version_label() -> Label:
	var l := Label.new()
	l.name = "DemoVersion"
	l.text = "%s  %s" % [w("公测版", "PUBLIC TEST"), VERSION]
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 90
	return l


# what an error from the server means, in words
static func error_text(e: String) -> String:
	match e:
		"used":
			return w("这个激活码已经在另一台电脑上用过了。", "This code has already been used on another computer.")
		"unknown":
			return w("没有这个激活码，请检查输入。", "There is no such code. Please check it.")
		"revoked":
			return w("这个激活码已经停用。", "This code has been withdrawn.")
		"expired", "closed":
			return w("公测已结束，谢谢！", "The public test is over. Thank you!")
		"invalid":
			return w("激活码格式不对，应该是 ZP-XXXX-XXXX。", "That isn't a code: it looks like ZP-XXXX-XXXX.")
		"offline":
			return w("连不上服务器。公测版需要联网，请检查网络后再试。", "Can't reach the server. The public test needs the internet: check the connection and try again.")
	return w("出了点问题（%s），请稍后再试。" % e, "Something went wrong (%s). Please try again." % e)


# ---------------------------------------------------------------- the end of the first hour

# called every frame by the game: the end card once the hour is up or the 88 m chapter is reached
static func watch(g) -> void:
	if not on() or g == null or (g.testing and not watch_in_tests) or g.get_meta("demo_end", false):
		return
	if g.state != "play" or g.menu_open or Career.data.is_empty():
		return
	var t := float(Career.data.get("time", 0.0))
	var reached := main_line_done()
	if t < LIMIT_S and not reached:
		return
	g.set_meta("demo_end", true)
	var card = preload("res://scripts/demo_end.gd").new()
	g.add_child(card)


# the main line as far as the pack's hulks carry it: every chapter before the tug yard done (or the
# 88 m berth's reached, for a pack that someday holds longer hulks)
static func main_line_done() -> bool:
	if Mainline.chapter() == "berth88":
		return true
	for id in Mainline.CHAPTERS:
		if id == "tug":
			return true
		if not Mainline.done(id):
			return false
	return true


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

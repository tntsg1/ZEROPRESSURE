class_name Settings
# Puts the saved settings into effect: the three volumes on the audio buses,
# and the picture quality (glow and anti-aliasing) on the viewport. The values
# themselves live in Txt with the rest of the settings file.

const MUSIC_DB := -5.0
const SFX_DB := -3.0

static var env: Environment = null     # the game's glow, while a game is running
static var look: Node = null           # 91 号: the game's picture layer (scripts/look.gd), while a game is running


static func _bus(name: String) -> int:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
	return i


static func _level(i: int, base_db: float, v: float) -> void:
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, base_db + linear_to_db(maxf(v, 0.001)))


static func apply_audio() -> void:
	_level(0, 0.0, Txt.vol_master)
	_level(_bus("Music"), MUSIC_DB, Txt.vol_music)
	_level(_bus("SFX"), SFX_DB, Txt.vol_sfx)


static func apply_video(vp: Viewport) -> void:
	var high := Txt.quality == "high"
	# full screen, a borderless window or a window (never touched by a headless test, nor by a test
	# that does not ask for it: a test's window stays where the test put it)
	if DisplayServer.get_name() != "headless" and (not Career._test_run() or window_tests):
		apply_window(Txt.win_mode)
	if vp != null:
		vp.msaa_2d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	if env != null:
		env.glow_enabled = high
	if look != null and is_instance_valid(look):
		look.apply_settings()


static var window_tests := false     # a test that checks the display modes for real
static var _framed := Rect2i()        # the framed window as it was, to go back to


# 公测反馈 #13 (Jev B 0.66): "window" a framed window; "borderless" no frame over the screen's work
# area (the taskbar stays); "full" Godot's full screen as before
static func apply_window(mode: String) -> void:
	var cur := DisplayServer.window_get_mode()
	var full_now := cur in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	var bare_now := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	match mode:
		"full":
			if not full_now:
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			if full_now:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			elif not bare_now:
				_framed = Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
			var scr := DisplayServer.window_get_current_screen()
			var area := DisplayServer.screen_get_usable_rect(scr)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_position(area.position)
			DisplayServer.window_set_size(area.size)
		_:
			if full_now:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if bare_now or full_now:
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				if _framed.has_area():
					DisplayServer.window_set_size(_framed.size)
					DisplayServer.window_set_position(_framed.position)
				else:
					var scr := DisplayServer.window_get_current_screen()
					var area := DisplayServer.screen_get_usable_rect(scr)
					var sz := Vector2i(mini(1600, area.size.x - 80), mini(900, area.size.y - 80))
					DisplayServer.window_set_size(sz)
					DisplayServer.window_set_position(area.position + (area.size - sz) / 2)


static func apply(vp: Viewport) -> void:
	apply_audio()
	apply_video(vp)

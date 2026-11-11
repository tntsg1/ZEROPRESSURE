class_name Fonts
# Chakra Petch for numerals and Latin, Noto Sans SC (subset) behind it for Chinese,
# and the system's CJK font behind that.

static var _cache := {}
static var watch: Node            # scripts/font_watch.gd under the root: redraws all when a glyph cache is rebuilt


static func get_font(weight: String = "Regular") -> Font:
	if _cache.has(weight):
		return _cache[weight]
	var f: FontFile = load("res://assets/fonts/ChakraPetch-%s.ttf" % weight)
	var sc_name := "Regular"
	if weight == "Light":
		sc_name = "Light"
	elif weight == "SemiBold":
		sc_name = "Semibold"
	var path := "res://assets/fonts/ZeroSC-%s.ttf" % sc_name
	var fb: Array[Font] = []
	if ResourceLoader.exists(path):
		fb.append(load(path))
	# last resort for what the subset can't know ahead (a company name the
	# player types): the system's own CJK font
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Source Han Sans SC", "SimHei"])
	sys.font_weight = 300 if weight == "Light" else (500 if weight in ["Medium", "SemiBold"] else 400)
	fb.append(sys)
	f.fallbacks = fb
	_cache[weight] = f
	_watch(f)
	return f


static func _watch(f: Font) -> void:
	if watch == null or not is_instance_valid(watch):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null or tree.root == null:
			return
		watch = preload("res://scripts/font_watch.gd").new()
		watch.name = "FontWatch"
		tree.root.add_child.call_deferred(watch)
	watch.watch(f)

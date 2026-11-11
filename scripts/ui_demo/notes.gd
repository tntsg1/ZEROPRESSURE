extends RefCounted
# Notes beside each proposal, and the boards that lay the shots out.

const K = preload("res://scripts/ui_demo/demo_kit.gd")

const NOTE := {
	"A": {"name": "A  工业仪表", "lines": [
		"要点：浅暖灰面板、凹陷深色显示窗放大号数字、实体按键按下 4 px + 橙色唇边、旋钮指向当前入口。",
		"优点：质感最“实物”，数字最醒目，和其他游戏一眼区分。",
		"风险：亮色界面与近黑的游戏世界反差最大，切换时刺眼；高密度表格（仓库、交易行）难做。",
		"工作量：大，约 3–4 周，面板要重画按键/显示窗。"],
		"motion": "按键按下下沉 4 px（80 ms）、松开回弹；旋钮跟着选中转到 1–4 并带一格“咔哒”；资金数字逐位翻动；LED 亮起 120 ms 渐亮。"},
	"B": {"name": "B  战术终端", "lines": [
		"要点：近黑底、40 px 细网格、扫描线、角标分区（不加框）、左侧命令列表、设施状态矩阵。",
		"优点：信息密度最高，最适合仓库/交易/电网这类数据页，和 OSD 回传画面一脉相承。",
		"风险：“战术 HUD”在同类游戏里常见，惊艳感要靠动效；扫描线久看费眼，要给关闭开关。",
		"工作量：中，约 2 周，现有面板换网格和角标即可。"],
		"motion": "选中高亮条在列表里上下滑动（90 ms）；下一步文字逐字打出+光标闪烁；在线点外圈脉冲；扫描亮带慢速下移；数字变化时先闪成橙色再回白。"},
	"C": {"name": "C  蓝图剖面", "lines": [
		"要点：船坞剖面占满画面，四个入口是图上引线标注，指向它打开的那部分；资金声望在图纸标题栏，设施是明细表。",
		"优点：最独特，第一眼最像“这个游戏自己的界面”，和已认可的工业剖面样片同源。",
		"风险：只有有“图”的页面能这么做；文字页需要另一套骨架。",
		"工作量：首页约 1 周；全部 UI 需配一套通用骨架，约 3 周。"],
		"motion": "切换入口时：引线从部件沿折线“画”出来（120 ms），被指的部件变橙并亮一下，编号圆点填满；进入页面时镜头从图纸推进到该部件。"},
	"D": {"name": "D  极简编辑排版", "lines": [
		"要点：去掉卡片和框，只用字号、字重、留白和细分隔线；超大标题和资金数字，下一步做成引文，入口是目录。",
		"优点：最干净、最“高级”，最容易推广成全局规范（任何页面都能套）。",
		"风险：留白多，信息量大的页面会变长；第一眼冲击靠字体，没有图形记忆点。",
		"工作量：小到中，约 1.5–2 周，主要是统一字号阶梯和间距。"],
		"motion": "目录顶部的橙色短线在四栏之间滑动（110 ms，缓出），编号由灰变橙；大数字变化时整体淡出上移、新值淡入；页面切换为文字分层错时淡入。"},
}


const CROP := {"C": Rect2(1180, 250, 740, 620), "D": Rect2(64, 820, 1000, 260), "B": Rect2(40, 360, 520, 580), "A": Rect2(40, 760, 1000, 230)}


class Board extends Control:
	var mode := "grid"
	var strip_key := "A"
	var _keep: Array = []  # textures must outlive _draw or they render white

	func _ready() -> void:
		size = Vector2(1920, 1080)

	func _tex(path: String) -> Texture2D:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var tx: Texture2D = ImageTexture.create_from_image(img) if img else null
		_keep.append(tx)
		return tx

	func _draw() -> void:
		var Kit = load("res://scripts/ui_demo/demo_kit.gd")
		var N = load("res://scripts/ui_demo/notes.gd")
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.047, 0.052))
		if mode == "compare":
			var items := [["ui_style_A", "A  原版（浅暖灰）"], ["ui_style_A_dark1", "A-暗1  炭黑"], ["ui_style_A_dark2", "A-暗2  黑金属"]]
			Kit.txt(self, Vector2(40, 64), "A 工业仪表 · 原版与两个暗色版", 26, Color(1, 1, 1), "SemiBold")
			for i in 3:
				var r := Rect2(40 + i * 624, 110, 600, 337.5)
				var tx := _tex("res://tests/out/%s.png" % items[i][0])
				if tx:
					draw_texture_rect(tx, r, false)
				draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
				Kit.txt(self, Vector2(r.position.x, r.end.y + 32), items[i][1], 20, Color(0.9, 0.9, 0.9), "SemiBold")
			# close-ups at full size: the header controls and the keys
			for i in 3:
				var r := Rect2(40 + i * 624, 510, 600, 240)
				var tx := _tex("res://tests/out/%s.png" % items[i][0])
				if tx:
					draw_texture_rect_region(tx, r, Rect2(800, 36, 600, 240))
				draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
				var r2 := Rect2(40 + i * 624, 766, 600, 240)
				if tx:
					draw_texture_rect_region(tx, r2, Rect2(40, 770, 600, 240))
				draw_rect(r2, Color(1, 1, 1, 0.12), false, 1.0)
			Kit.txt(self, Vector2(40, 1046), "下两排为 1:1 局部：旋钮与资金显示窗、选中的「1 找船」键。", 16, Color(0.7, 0.71, 0.72))
		elif mode == "grid":
			var keys := ["A", "B", "C", "D"]
			for i in 4:
				var k: String = keys[i]
				var cx := 24.0 + (i % 2) * 948.0
				var cy := 20.0 + (i / 2) * 530.0
				var img := Rect2(cx, cy, 704, 396)
				var tx := _tex("res://tests/out/ui_style_%s.png" % k)
				if tx:
					draw_texture_rect(tx, img, false)
				draw_rect(img, Color(1, 1, 1, 0.12), false, 1.0)
				var note: Dictionary = N.NOTE[k]
				Kit.txt(self, Vector2(cx + 720, cy + 26), note.name, 22, Color(1, 1, 1), "SemiBold")
				var y := cy + 62
				for ln in note.lines:
					y = _wrap(Kit, ln, Vector2(cx + 720, y), 200, 14, Color(0.78, 0.79, 0.8))
					y += 8
				var my := cy + 420
				Kit.txt(self, Vector2(cx, my), "动效", 14, Kit.ORANGE, "SemiBold")
				_wrap(Kit, note.motion, Vector2(cx + 40, my), 860, 14, Color(0.78, 0.79, 0.8))
		else:
			Kit.txt(self, Vector2(40, 70), "%s · 选中切换 1 → 2（三帧）" % N.NOTE[strip_key].name, 26, Color(1, 1, 1), "SemiBold")
			var caps := ["帧 1  选中「1 找船」", "帧 2  过渡中（约 60 ms 处）", "帧 3  选中「2 船坞」"]
			for i in 3:
				var r := Rect2(40 + i * 624, 120, 600, 337.5)
				var tx := _tex("res://tests/out/ui_style_%s_sel%d.png" % [strip_key, i])
				if tx:
					draw_texture_rect(tx, r, false)
				draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
				Kit.txt(self, Vector2(r.position.x, r.end.y + 34), caps[i], 18, Color(0.85, 0.86, 0.87))
			# close-ups of the area that changes
			var crop: Rect2 = N.CROP.get(strip_key, Rect2(0, 640, 1000, 440))
			for i in 3:
				var r := Rect2(40 + i * 624, 516, 600, 600.0 * crop.size.y / crop.size.x)
				var tx := _tex("res://tests/out/ui_style_%s_sel%d.png" % [strip_key, i])
				if tx:
					draw_texture_rect_region(tx, r, crop)
				draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
			Kit.txt(self, Vector2(40, 1058), "下排为变化区域局部放大。" + N.NOTE[strip_key].motion, 16, Color(0.75, 0.76, 0.77))

	func _wrap(Kit, s: String, at: Vector2, w: float, fs: int, col: Color) -> float:
		var line := ""
		var y := at.y
		for ch in s:
			if Kit.width(line + ch, fs) > w:
				Kit.txt(self, Vector2(at.x, y), line, fs, col)
				y += fs + 7
				line = ""
			line += ch
		if line != "":
			Kit.txt(self, Vector2(at.x, y), line, fs, col)
			y += fs + 7
		return y

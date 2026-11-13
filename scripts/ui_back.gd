extends RefCounted
# 134 号 (user 2026-11-10: "从哪里进入，就开始从哪里返回的。你检查一下还有没有这样的 bug"): one way back
# for every full-screen page. A page that leaves for another (the find-ships page for the hulk
# market, the exchange for the star map, a district console for the exchange…) first leaves here
# how to open it again as it was (its tab, its filter, its scroll); Esc or the page's back key
# then closes the page and opens the one it came from, and that one goes back to where it came
# from in turn. Going to a page already behind steps back to it instead of piling up.
# A page opened from the site (a hotkey, a guide card, a console on the floor) starts a fresh
# trail: every page calls arrive() as it opens, and one that was not just stepped to clears it.
#   go(from, to, open)    leaving: from = entry(key, label, reopen); to = the page's key
#   back(game) -> bool    Esc / the back key, after the page closed itself
#   close_text()          "返回找船 [Esc]" when there is a way back, else "关闭 [Esc]"
# Nothing is saved: the trail lives as long as the pages are open.

const DEPTH := 8
const HOP_FRAMES := 90          # a page opened this soon after a step keeps the trail (~1.5 s)
static var stack: Array = []    # {key, label: [zh, en], reopen: Callable}
static var _hop := -1000


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func entry(key: String, label: Array, reopen: Callable) -> Dictionary:
	return {"key": key, "label": label, "reopen": reopen}


static func _mark() -> void:
	_hop = Engine.get_process_frames()


# a page leaves for another (it has closed itself already)
static func go(from: Dictionary, to: String, open: Callable) -> void:
	for i in range(stack.size() - 1, -1, -1):
		if str(stack[i].key) == to:
			# the page asked for is behind us: back to it as it was
			var e: Dictionary = stack[i]
			stack = stack.slice(0, i)
			_mark()
			(e.reopen as Callable).call_deferred()
			return
	if not from.is_empty() and str(from.key) != to:
		stack.append(from)
		if stack.size() > DEPTH:
			stack = stack.slice(stack.size() - DEPTH)
	_mark()
	open.call_deferred()


# every page as it opens: a page not just stepped to starts a fresh trail
static func arrive() -> void:
	if Engine.get_process_frames() - _hop > HOP_FRAMES:
		stack.clear()
	_hop = -1000


static func has_back() -> bool:
	return not stack.is_empty()


# Esc / the back key: the page it came from, opened again as it was (false: nowhere to go back to)
static func back() -> bool:
	if stack.is_empty():
		return false
	var e: Dictionary = stack.pop_back()
	_mark()
	(e.reopen as Callable).call_deferred()
	return true


static func label() -> String:
	if stack.is_empty():
		return ""
	var l: Array = stack[-1].label
	return str(l[0] if Txt.zh else l[1])


static func close_text(spaced := false) -> String:
	if stack.is_empty():
		return w("关闭 [Esc]", "CLOSE  [Esc]" if spaced else "CLOSE [Esc]")
	return w("返回%s [Esc]", "BACK TO %s  [Esc]" if spaced else "BACK TO %s [Esc]") % label()


# 2026-11-12 HUD 中央交互: what stands open on the site itself (the device card, scripts/hud_center.gd)
# is the first thing Esc takes back, before the menu: each registers a Callable -> bool (true: closed)
static var site: Array = []


static func site_add(cb: Callable) -> void:
	if not site.has(cb):
		site.append(cb)


static func site_remove(cb: Callable) -> void:
	site.erase(cb)


static func site_back() -> bool:
	for i in range(site.size() - 1, -1, -1):
		var cb: Callable = site[i]
		if not cb.is_valid():
			site.remove_at(i)
			continue
		if cb.call():
			return true
	return false


static func reset() -> void:
	stack.clear()
	_hop = -1000

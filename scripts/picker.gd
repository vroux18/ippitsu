extends Control
## Choix d'une carte parmi trois (rouleaux d'amélioration ou malédictions du sanctuaire).
## Voile d'encre, titre, trois cartes verticales en éventail ; la carte choisie s'illumine.

const Toon = preload("res://scripts/toon.gd")
const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")

const CARD := Color("#F5EEDD")
const SCHOOL_NAMES := {"火": "FEU", "水": "EAU", "雷": "FOUDRE", "風": "VENT", "影": "OMBRE", "鬼": "MALÉDICTION", "道": "CHEMIN"}

signal picked(id: String)
signal reroll

var rerolls := 0  # relances disponibles (Atelier : Choix)

var _ids: Array = []
var _infos: Array = []
var _t := 0.0
var _down := -1
var _chosen := -1
var _rects: Array = []
var _reroll_rect := Rect2()
var _curse_mode := false
var _ui := FontVariation.new()
var _title := FontVariation.new()
var _last_ms := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UI_FONT
	_ui.spacing_glyph = 1
	_title.base_font = TITLE_FONT
	_title.spacing_glyph = 6


func open(ids: Array, infos: Array) -> void:
	_ids = ids
	_infos = infos
	_t = 0.0
	_down = -1
	_chosen = -1
	_curse_mode = false
	for info in infos:
		if String(info.get("kanji", "")) == "鬼":
			_curse_mode = true
	visible = true


func _gui_input(event: InputEvent) -> void:
	if _chosen >= 0 or _t < 0.5:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if rerolls > 0 and _reroll_rect.has_point(event.position):
			if not event.pressed:
				rerolls -= 1
				visible = false
				reroll.emit()
			accept_event()
			return
		var i := _hit(event.position)
		if event.pressed:
			_down = i
		elif _down >= 0 and i == _down:
			_chosen = i
			_t = 0.0
		else:
			_down = -1
		accept_event()


func _hit(p: Vector2) -> int:
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		if r.has_point(p):
			return i
	return -1


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var now := Time.get_ticks_msec()
	_t += 0.0 if _last_ms == 0 else minf((now - _last_ms) / 1000.0, 0.1)
	_last_ms = now
	if _chosen >= 0 and _t > 0.55:
		visible = false
		_last_ms = 0
		picked.emit(String(_ids[_chosen]))
	queue_redraw()


func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	var u := minf(w / 400.0, h / 760.0)
	var fade := _ease(_t / 0.3) if _chosen < 0 else 1.0 - _ease((_t - 0.25) / 0.3)
	# voile d'encre et lueur de l'école / du sanctuaire
	draw_rect(Rect2(Vector2.ZERO, size), Color(Color("#120F12"), 0.82 * fade))
	var glow := Color("#5E1A14") if _curse_mode else Color("#1F3A5F")
	draw_circle(Vector2(w / 2.0, h * 0.5), w * 0.75, Color(glow, 0.18 * fade))

	# titre
	var title := "SANCTUAIRE" if _curse_mode else "UN ROULEAU"
	var sub := "Une malédiction contre une récompense" if _curse_mode else "Choisis ton pouvoir"
	var tfs := int(30 * u)
	var tw := _title.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var ty := h * 0.17 - 16 * u * (1.0 - fade)
	draw_string(_title, Vector2(w / 2.0 - tw / 2.0, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(Toon.WASHI, fade))
	var sfs := int(13 * u)
	var sw := _ui.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
	draw_string(_ui, Vector2(w / 2.0 - sw / 2.0, ty + 26 * u), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(Toon.WASHI, 0.55 * fade))
	draw_line(Vector2(w / 2.0 - 40 * u, ty + 40 * u), Vector2(w / 2.0 + 40 * u, ty + 40 * u), Color(Toon.VERMILION if _curse_mode else Toon.GOLD, fade), 2.0 * u)

	# cartes
	var n := _infos.size()
	var gap := 9.0 * u
	var cw := minf(122.0 * u, (w - 24 * u - gap * (n - 1)) / maxf(1.0, n))
	var ch := minf(cw * 2.2, h * 0.5)
	var total := cw * n + gap * (n - 1)
	var x0 := (w - total) / 2.0
	var cy := h * 0.25
	_rects.clear()
	for i in n:
		var info: Dictionary = _infos[i]
		var k := _ease((_t - 0.06 * i) / 0.45)
		var lift := 0.0
		var a := k * fade
		var grow := 1.0
		if _chosen >= 0:
			if i == _chosen:
				a = 1.0
				grow = 1.0 + 0.08 * _ease(_t / 0.2)
				lift = -14.0 * u * _ease(_t / 0.2)
			else:
				a = 1.0 - _ease(_t / 0.25)
		elif _down == i:
			grow = 0.96
		var r := Rect2(Vector2(x0 + i * (cw + gap), cy + 60 * u * (1.0 - k) + lift), Vector2(cw, ch))
		_rects.append(r)
		r = Rect2(r.get_center() - r.size * grow / 2.0, r.size * grow)
		_card(r, info, u, a, i == _chosen)

	# relance
	_reroll_rect = Rect2()
	if rerolls > 0 and _chosen < 0 and n > 0:
		_reroll_rect = Rect2(Vector2(w / 2.0 - 78 * u, cy + ch + 34 * u), Vector2(156 * u, 42 * u))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(Toon.WASHI, 0.7 * fade)
		sb.set_border_width_all(int(1.5 * u))
		sb.set_corner_radius_all(999)
		draw_style_box(sb, _reroll_rect)
		var txt := "RELANCER   %d" % rerolls
		var fs := int(13 * u)
		var rw := _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_ui, Vector2(_reroll_rect.get_center().x - rw / 2.0, _reroll_rect.get_center().y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.WASHI, fade))


func _card(r: Rect2, info: Dictionary, u: float, a: float, chosen: bool) -> void:
	if a <= 0.01:
		return
	var col: Color = info.color
	var kanji := String(info.kanji)
	var is_curse := kanji == "鬼"
	var radius := int(12 * u)
	# halo de la carte choisie
	if chosen:
		var halo := StyleBoxFlat.new()
		halo.bg_color = Color(0, 0, 0, 0)
		halo.border_color = Color(Toon.VERMILION if is_curse else Toon.GOLD, 0.9)
		halo.set_border_width_all(int(3 * u))
		halo.set_corner_radius_all(radius + int(5 * u))
		draw_style_box(halo, r.grow(5 * u))
	# ombre et corps
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color("#2A0E0B") if is_curse else CARD, a)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.45 * a)
	sb.shadow_size = int(14 * u)
	sb.shadow_offset = Vector2(0, 6 * u)
	draw_style_box(sb, r)
	# en-tête coloré avec l'idéogramme
	var head := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.38))
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(col, a)
	hb.corner_radius_top_left = radius
	hb.corner_radius_top_right = radius
	draw_style_box(hb, head)
	# motif de vagues discret dans l'en-tête
	for k in 3:
		var yy := head.end.y - (8 + k * 9) * u
		draw_arc(Vector2(head.position.x + head.size.x * 0.25, yy + 10 * u), 10 * u, PI, TAU, 10, Color(1, 1, 1, 0.08 * a), 1.5 * u)
		draw_arc(Vector2(head.position.x + head.size.x * 0.75, yy + 10 * u), 10 * u, PI, TAU, 10, Color(1, 1, 1, 0.08 * a), 1.5 * u)
	var kfs := int(46 * u)
	var kw := TITLE_FONT.get_string_size(kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
	draw_string(TITLE_FONT, Vector2(head.get_center().x - kw / 2.0, head.get_center().y + kfs * 0.36), kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Color(Toon.WASHI, a))
	# étiquette d'école
	var school := String(SCHOOL_NAMES.get(kanji, ""))
	var ink := Toon.WASHI if is_curse else Toon.SUMI
	var y := head.end.y + 16 * u
	if school != "":
		var lfs := int(9 * u)
		var lw := _ui.get_string_size(school, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
		var tag := Rect2(Vector2(r.get_center().x - lw / 2.0 - 7 * u, y - 10 * u), Vector2(lw + 14 * u, 15 * u))
		var tb := StyleBoxFlat.new()
		tb.bg_color = Color(Toon.VERMILION, 0.25 * a) if is_curse else Color(col, 0.18 * a)
		tb.set_corner_radius_all(999)
		draw_style_box(tb, tag)
		draw_string(_ui, Vector2(tag.position.x + 7 * u, tag.position.y + 11 * u), school, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(col.lightened(0.5) if is_curse else col, a))
		y += 14 * u
	# nom
	var nfs := int(16 * u)
	draw_multiline_string(TITLE_FONT, Vector2(r.position.x + 8 * u, y + 14 * u), String(info.name), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16 * u, nfs, 2, Color(ink, a))
	y += 40 * u
	# niveau : losanges
	var lvl := int(info.get("level", -1))
	if lvl >= 0:
		for k in 3:
			var c := Vector2(r.get_center().x + (k - 1) * 14 * u, y)
			var d := PackedVector2Array([c + Vector2(0, -5) * u, c + Vector2(5, 0) * u, c + Vector2(0, 5) * u, c + Vector2(-5, 0) * u])
			if k < lvl:
				draw_colored_polygon(d, Color(col, a))
			else:
				var dd := d.duplicate()
				dd.append(d[0])
				draw_polyline(dd, Color(ink, 0.3 * a), 1.2 * u, true)
		y += 16 * u
	# effet ; pour une malédiction : malus en rouge, récompense en or
	var efs := int(11 * u)
	var text := String(info.text)
	var tx := r.position.x + 9 * u
	var tw := r.size.x - 18 * u
	if text.contains("·"):
		var parts := text.split("·")
		draw_multiline_string(_ui, Vector2(tx, y + 6 * u), "- " + parts[0].strip_edges(), HORIZONTAL_ALIGNMENT_CENTER, tw, efs, 3, Color(Color("#FF8A7A") if is_curse else Toon.VERMILION, a))
		draw_multiline_string(_ui, Vector2(tx, y + 50 * u), "+ " + parts[1].strip_edges(), HORIZONTAL_ALIGNMENT_CENTER, tw, efs, 3, Color(Toon.GOLD.lightened(0.2), a))
	else:
		draw_multiline_string(_ui, Vector2(tx, y + 6 * u), text, HORIZONTAL_ALIGNMENT_CENTER, tw, efs, 5, Color(ink, 0.8 * a))

extends Control
## Atelier : écran plein du refuge. Compteurs (encre, sceaux, Vues) et Pierre à encre (6 lignes d'améliorations).

const Toon = preload("res://scripts/toon.gd")
const Meta = preload("res://scripts/meta.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")

const PAPER := Color("#F6F0E2")
const LINE_COLORS := {
	"brush": Color("#1F3A5F"),
	"ink": Color("#1B1A1E"),
	"paper": Color("#D7372B"),
	"breath": Color("#4F7F7C"),
	"purse": Color("#C49A45"),
	"choice": Color("#6A4C7E"),
}

signal closed

var meta  # instance de meta.gd, fournie par main avant open()

var _t := 0.0  # temps réel depuis l'ouverture
var _down := -1  # ligne sous le doigt
var _rects: Array = []  # rectangles des cartes (pour le toucher)
var _price_rects: Array = []  # rectangles des boutons prix
var _pop: Array = []  # animation d'achat par ligne (1 -> 0)
var _shake: Array = []  # refus (pas assez d'encre) par ligne (1 -> 0)
var _splashes: Array = []  # éclaboussures d'encre en cours
var _bump := 0.0  # rebond du compteur d'encre
var _fibers: Array = []  # fibres du papier : [départ normalisé, vecteur, alpha, épaisseur, clair]
var _specks: Array = []  # petites impuretés du papier
var _rng := RandomNumberGenerator.new()
var _box := StyleBoxFlat.new()
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _back: InkButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title.base_font = TITLE_FONT
	_title.spacing_glyph = 3
	_ui.base_font = UI_FONT
	_ui.spacing_glyph = 2
	_box.anti_aliasing = true
	for i in Meta.ORDER.size():
		_pop.append(0.0)
		_shake.append(0.0)
	_back = InkButton.new()
	_back.text = "RETOUR"
	_back.style = "primary"
	_back.font = _ui
	add_child(_back)
	_back.pressed.connect(_close)
	_make_paper()


func open() -> void:
	_t = 0.0
	_down = -1
	_bump = 0.0
	_splashes.clear()
	for i in _pop.size():
		_pop[i] = 0.0
		_shake[i] = 0.0
	visible = true


func _close() -> void:
	visible = false
	closed.emit()


## Texture de papier : fibres pâles et impuretés, tirées une fois (graine fixe).
func _make_paper() -> void:
	_rng.seed = 1760
	for i in 90:
		var start := Vector2(_rng.randf(), _rng.randf())
		var ang := _rng.randf_range(-0.6, 0.6) + (PI if _rng.randf() < 0.5 else 0.0)
		var vec := Vector2.from_angle(ang) * _rng.randf_range(0.015, 0.08)
		var light := _rng.randf() < 0.4
		_fibers.append([start, vec, _rng.randf_range(0.03, 0.07), _rng.randf_range(0.6, 1.4), light])
	for i in 40:
		_specks.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.4, 1.2)))
	_rng.randomize()


func _gui_input(event: InputEvent) -> void:
	if _t < 0.3 or meta == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _hit(event.position)
		if event.pressed:
			_down = i
		elif _down >= 0:
			if i == _down:
				_tap(i)
			_down = -1
		accept_event()


func _hit(p: Vector2) -> int:
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		if r.has_point(p):
			return i
	return -1


func _tap(i: int) -> void:
	var id: String = Meta.ORDER[i]
	if meta.buy(id):
		_pop[i] = 1.0
		_bump = 1.0
		if i < _price_rects.size():
			var pr: Rect2 = _price_rects[i]
			_splash(pr.get_center())
	else:
		_shake[i] = 1.0


## Éclaboussure : une tache centrale et des gouttes projetées.
func _splash(p: Vector2) -> void:
	var drops: Array = []
	for j in 10:
		drops.append(Vector3(_rng.randf() * TAU, _rng.randf_range(0.9, 2.3), _rng.randf_range(0.1, 0.28)))
	_splashes.append({"p": p, "t": 0.0, "drops": drops})


func _process(delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var real := delta / maxf(Engine.time_scale, 0.01)
	_t += real
	for i in _pop.size():
		_pop[i] = maxf(0.0, float(_pop[i]) - real * 2.2)
		_shake[i] = maxf(0.0, float(_shake[i]) - real * 3.0)
	_bump = maxf(0.0, _bump - real * 3.0)
	for sp in _splashes:
		sp["t"] = float(sp["t"]) + real
	_splashes = _splashes.filter(func(sp): return float(sp["t"]) < 0.7)

	var w := size.x
	var h := size.y
	var u := _unit()
	var bw := minf(w * 0.56, 230.0 * u)
	var bh := 54.0 * u
	var appear := _ease(clampf((_t - 0.3) / 0.4, 0.0, 1.0))
	_back.size = Vector2(bw, bh)
	_back.position = Vector2((w - bw) / 2.0, h - bh - 24.0 * u + 16.0 * u * (1.0 - appear))
	_back.modulate.a = appear
	_back.font_size = int(21 * u)
	queue_redraw()


## Unité de dessin : largeur / 400, bornée par la hauteur pour tenir sur tout écran.
func _unit() -> float:
	return minf(size.x / 400.0, size.y / 760.0)


func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func _draw() -> void:
	if size.x < 10.0:
		return
	var w := size.x
	var h := size.y
	var u := _unit()

	# fond washi opaque et sa texture
	draw_rect(Rect2(Vector2.ZERO, size), Toon.WASHI)
	for f in _fibers:
		var p0: Vector2 = f[0]
		var vec: Vector2 = f[1]
		var fa: float = f[2]
		var fw: float = f[3]
		var light: bool = f[4]
		var c := Color(1, 1, 1, fa * 6.0) if light else Color(Toon.SUMI, fa)
		var start := Vector2(p0.x * w, p0.y * h)
		draw_line(start, start + vec * maxf(w, h * 0.6), c, fw * u, true)
	for s in _specks:
		var sk: Vector3 = s
		draw_circle(Vector2(sk.x * w, sk.y * h), sk.z * u, Color(Toon.SUMI, 0.08))

	if meta == null:
		return
	var a := _ease(clampf(_t / 0.4, 0.0, 1.0))
	_draw_header(w, u, a)

	# la Pierre à encre : cartes empilées entre l'en-tête et le bouton retour
	var top := 192.0 * u
	var bottom := h - 100.0 * u
	var n: int = Meta.ORDER.size()
	var gap := 10.0 * u
	var ch := clampf((bottom - top - gap * (n - 1)) / n, 56.0 * u, 84.0 * u)
	var cw := minf(w - 32.0 * u, 380.0 * u)
	var total := ch * n + gap * (n - 1)
	var y0 := top + maxf(0.0, (bottom - top - total) / 2.0)
	_rects.clear()
	_price_rects.clear()
	for i in n:
		var ap := _ease(clampf((_t - 0.1 - 0.05 * i) / 0.35, 0.0, 1.0))
		var r := Rect2(Vector2((w - cw) / 2.0 + 30.0 * u * (1.0 - ap), y0 + i * (ch + gap)), Vector2(cw, ch))
		_rects.append(r)
		var sh := float(_shake[i])
		var shown := r
		shown.position.x += sin(sh * 28.0) * 6.0 * u * sh
		var pop := float(_pop[i])
		if pop > 0.0:
			shown = shown.grow(3.0 * u * sin(pop * PI))
		_card(i, shown, ch / 78.0, ap)

	for sp in _splashes:
		_draw_splash(sp, u)


func _draw_header(w: float, u: float, a: float) -> void:
	# titre « Atelier » et petit sceau vermillon 墨
	var tfs := int(44 * u)
	var tw := _title.get_string_size("Atelier", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var ss := 34.0 * u
	var x0 := (w - tw - 12.0 * u - ss) / 2.0
	var ty := 78.0 * u - 8.0 * u * (1.0 - a)
	draw_string(_title, Vector2(x0, ty), "Atelier", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(Toon.SUMI, a))
	var seal := Rect2(Vector2(x0 + tw + 12.0 * u, ty - 38.0 * u), Vector2(ss, ss))
	_box.bg_color = Color(Toon.VERMILION, a)
	_box.set_border_width_all(0)
	_box.set_corner_radius_all(int(5 * u))
	draw_style_box(_box, seal)
	_centered(TITLE_FONT, "墨", Vector2(seal.get_center().x, seal.get_center().y + 8.0 * u), int(23 * u), Color(Toon.WASHI, a))
	var k := _ease(clampf((_t - 0.2) / 0.35, 0.0, 1.0))
	if k > 0.0:
		var b0 := Vector2(x0 - 4.0 * u, ty + 12.0 * u)
		var b1 := Vector2(x0 + tw + 6.0 * u, ty + 7.0 * u)
		_brush(b0, b0.lerp(b1, k), 4.0 * u, Color(Toon.VERMILION, 0.85 * a))

	# compteurs : encre, sceaux, Vues
	var fs := int(19 * u)
	var cy := 130.0 * u
	var ink_txt := str(meta.sumi)
	var seal_txt := str(meta.seals)
	var view_txt := "Vues %d/%d" % [int(meta.prints), Meta.MAX_PRINTS]
	var iw := 18.0 * u + 7.0 * u + _ui.get_string_size(ink_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sw := 16.0 * u + 7.0 * u + _ui.get_string_size(seal_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var vw := 14.0 * u + 7.0 * u + _ui.get_string_size(view_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sep := 28.0 * u
	var x := (w - iw - sw - vw - 2.0 * sep) / 2.0
	var base := cy + fs * 0.36
	# encre (rebondit et dore après un achat)
	_stick(Vector2(x + 9.0 * u, cy), 20.0 * u, a)
	var ic := Color(Toon.SUMI, a).lerp(Color(Toon.GOLD, a), _bump)
	draw_string(_ui, Vector2(x + 25.0 * u, base - 5.0 * u * sin(_bump * PI)), ink_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ic)
	x += iw + sep
	# sceaux
	_seal_icon(Vector2(x + 8.0 * u, cy), 16.0 * u, a)
	draw_string(_ui, Vector2(x + 23.0 * u, base), seal_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.SUMI, a))
	x += sw + sep
	# Vues
	_print_icon(Vector2(x + 7.0 * u, cy), 18.0 * u, a)
	draw_string(_ui, Vector2(x + 21.0 * u, base), view_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.SUMI, a))

	# intitulé de la station
	var lfs := int(12 * u)
	var ly := 172.0 * u
	var lw := _centered(_ui, "PIERRE À ENCRE", Vector2(w / 2.0, ly), lfs, Color(Toon.SUMI, 0.55 * a))
	var lc := Color(Toon.SUMI, 0.25 * a)
	draw_line(Vector2(w / 2.0 - lw / 2.0 - 46.0 * u, ly - lfs * 0.35), Vector2(w / 2.0 - lw / 2.0 - 10.0 * u, ly - lfs * 0.35), lc, 1.5 * u, true)
	draw_line(Vector2(w / 2.0 + lw / 2.0 + 10.0 * u, ly - lfs * 0.35), Vector2(w / 2.0 + lw / 2.0 + 46.0 * u, ly - lfs * 0.35), lc, 1.5 * u, true)


## Une ligne de la Pierre à encre. v = unité locale de la carte (carte de 78 v de haut).
func _card(i: int, r: Rect2, v: float, a: float) -> void:
	var id: String = Meta.ORDER[i]
	var line: Dictionary = Meta.LINES[id]
	var col: Color = LINE_COLORS[id]
	var rk: int = meta.rank(id)
	var mx: int = meta.max_rank(id)
	var price: int = meta.cost(id)
	var ok: bool = meta.can_buy(id)
	var maxed := price < 0
	var pressed := _down == i
	var ta := a * (1.0 if ok or maxed else 0.72)  # texte un peu éteint si trop cher

	# ombre et carte de papier
	var cr := r
	if pressed:
		cr.position.y += 3.0 * v
	_box.set_corner_radius_all(int(10 * v))
	_box.set_border_width_all(0)
	_box.bg_color = Color(Toon.SUMI, 0.16 * a)
	draw_style_box(_box, Rect2(r.position + Vector2(0, 5.0 * v), r.size))
	_box.bg_color = Color(PAPER, a)
	_box.border_color = Color(Toon.SUMI, a)
	_box.set_border_width_all(maxi(1, int(2.5 * v)))
	draw_style_box(_box, cr)

	# cartouche à l'idéogramme de la ligne
	var bs := cr.size.y - 16.0 * v
	var band := Rect2(cr.position + Vector2(8.0, 8.0) * v, Vector2(minf(bs, 56.0 * v), bs))
	_box.set_border_width_all(0)
	_box.set_corner_radius_all(int(6 * v))
	_box.bg_color = Color(col, a)
	draw_style_box(_box, band)
	_centered(TITLE_FONT, String(line["kanji"]), Vector2(band.get_center().x, band.get_center().y + 11.0 * v), int(32 * v), Color(Toon.WASHI, a))

	# bouton prix (à droite)
	var pr := Rect2(Vector2(cr.end.x - 10.0 * v - 84.0 * v, cr.get_center().y - 20.0 * v), Vector2(84.0 * v, 40.0 * v))
	_price_rects.append(pr)
	_box.set_corner_radius_all(999)
	if maxed:
		_box.bg_color = Color(Toon.GOLD, 0.16 * a)
		_box.border_color = Color(Toon.GOLD, a)
		_box.set_border_width_all(maxi(1, int(2 * v)))
		draw_style_box(_box, pr)
		_centered(_ui, "MAX", Vector2(pr.get_center().x, pr.get_center().y + 6.0 * v), int(16 * v), Color(Toon.GOLD, a))
	else:
		var pfs := int(17 * v)
		var ptxt := str(price)
		var pw := 14.0 * v + 6.0 * v + _ui.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
		var px := pr.get_center().x - pw / 2.0
		if ok:
			_box.bg_color = Color(Toon.SUMI, a)
			draw_style_box(_box, pr)
			_stick(Vector2(px + 7.0 * v, pr.get_center().y), 18.0 * v, a)
			draw_string(_ui, Vector2(px + 20.0 * v, pr.get_center().y + pfs * 0.36), ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(Toon.WASHI, a))
		else:
			_box.bg_color = Color(Toon.SUMI, 0.07 * a)
			_box.border_color = Color(Toon.SUMI, 0.25 * a)
			_box.set_border_width_all(maxi(1, int(1.5 * v)))
			draw_style_box(_box, pr)
			_stick(Vector2(px + 7.0 * v, pr.get_center().y), 18.0 * v, 0.35 * a)
			draw_string(_ui, Vector2(px + 20.0 * v, pr.get_center().y + pfs * 0.36), ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(Toon.SUMI, 0.4 * a))

	# nom, effet du prochain rang, pastilles de rang
	var tx := band.end.x + 12.0 * v
	var tw := pr.position.x - tx - 8.0 * v
	draw_string(TITLE_FONT, Vector2(tx, cr.position.y + 28.0 * v), String(line["name"]), HORIZONTAL_ALIGNMENT_LEFT, tw, int(19 * v), Color(Toon.SUMI, ta))
	var eff: String = meta.effect_text(id)
	draw_string(_ui, Vector2(tx, cr.position.y + 48.0 * v), eff, HORIZONTAL_ALIGNMENT_LEFT, tw, int(13 * v), Color(Toon.SUMI, 0.72 * ta))
	var pop := float(_pop[i])
	for k in mx:
		var c := Vector2(tx + 6.0 * v + k * 15.0 * v, cr.position.y + 63.0 * v)
		if k < rk:
			var rad := 5.0 * v
			if k == rk - 1 and pop > 0.0:
				rad *= 1.0 + 0.7 * sin(pop * PI)
			draw_circle(c, rad, Color(col, a))
		else:
			draw_arc(c, 4.6 * v, 0, TAU, 16, Color(Toon.SUMI, 0.3 * a), maxf(1.0, 1.5 * v), true)


## Éclaboussure d'encre : tache qui s'étale, gouttes projetées, le tout s'efface.
func _draw_splash(sp: Dictionary, u: float) -> void:
	var p: Vector2 = sp["p"]
	var k := clampf(float(sp["t"]) / 0.7, 0.0, 1.0)
	var e := _ease(k)
	var a := 1.0 - k * k
	var s := 22.0 * u
	draw_circle(p, s * (0.35 + 0.55 * e), Color(Toon.SUMI, 0.55 * a))
	var drops: Array = sp["drops"]
	for d in drops:
		var dv: Vector3 = d
		var dir := Vector2.from_angle(dv.x)
		var q := p + dir * dv.y * s * e
		draw_line(p + dir * s * 0.4 * e, q, Color(Toon.SUMI, 0.4 * a), maxf(1.0, dv.z * s * 0.5 * (1.0 - k)), true)
		draw_circle(q, dv.z * s * (1.0 - 0.5 * k), Color(Toon.SUMI, a))


# --- Petites icônes dessinées -------------------------------------------------

## Bâton d'encre : petit rectangle sumi incliné, liseré or.
func _stick(c: Vector2, s: float, a: float) -> void:
	var ang := 0.35
	var hx := s * 0.22
	var hy := s * 0.5
	var pts := PackedVector2Array()
	for q in [Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)]:
		var corner: Vector2 = q
		pts.append(c + corner.rotated(ang))
	draw_colored_polygon(pts, Color(Toon.SUMI, a))
	var outline := pts.duplicate()
	outline.append(pts[0])
	var gold := Color(Toon.GOLD, a)
	var lw := maxf(1.0, s * 0.08)
	draw_polyline(outline, gold, lw, true)
	draw_line(c + Vector2(-hx, -hy * 0.45).rotated(ang), c + Vector2(hx, -hy * 0.45).rotated(ang), gold, lw, true)


## Sceau : carré vermillon avec un filet clair intérieur.
func _seal_icon(c: Vector2, s: float, a: float) -> void:
	var r := Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s))
	draw_rect(r, Color(Toon.VERMILION, a))
	draw_rect(r.grow(-s * 0.2), Color(Toon.WASHI, 0.7 * a), false, maxf(1.0, s * 0.08))


## Vue : petite estampe (papier, cadre sumi, vague bleue).
func _print_icon(c: Vector2, s: float, a: float) -> void:
	var r := Rect2(c - Vector2(s * 0.75, s) / 2.0, Vector2(s * 0.75, s))
	draw_rect(r, Color(PAPER, a))
	draw_rect(r, Color(Toon.SUMI, a), false, maxf(1.0, s * 0.08))
	draw_arc(Vector2(r.get_center().x, r.end.y - s * 0.12), s * 0.26, PI, TAU, 10, Color(Toon.PRUSSIAN, a), maxf(1.0, s * 0.1), true)


# --- Utilitaires ---------------------------------------------------------------

func _centered(font: Font, txt: String, at: Vector2, fs: int, c: Color) -> float:
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(at.x - tw / 2.0, at.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return tw


func _brush(p0: Vector2, p1: Vector2, wdt: float, c: Color) -> void:
	var d := p1 - p0
	if d.length() < 1.0:
		return
	var n := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(p0 + d * t + n * wdt * (0.35 + 0.65 * sin(PI * minf(1.0, t * 1.2))) * (1.0 - 0.6 * t))
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		pts.append(p0 + d * t - n * wdt * (0.35 + 0.65 * sin(PI * minf(1.0, t * 1.2))) * (1.0 - 0.6 * t))
	draw_colored_polygon(pts, c)

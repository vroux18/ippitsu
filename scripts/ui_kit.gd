extends RefCounted
## Petits outils partagés par les écrans dessinés : polices, texte sans macrons, horloge réelle,
## courbe d'arrivée, texte centré, coupe de lignes, StyleBoxFlat réutilisée, pictogrammes (glyph,
## pouvoirs, figures, estampes) et aire de polygone.

const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")
const Toon = preload("res://scripts/toon.gd")
# les six figures, dans l'ordre d'affichage
const FIGURES := ["straight", "return", "zigzag", "loop", "enso", "hook"]

static var _last_ms := 0
static var _frame := -1
static var _delta := 0.0


## Les polices réduites n'ont pas les voyelles longues (ō, ū) : on les écrit sans macron.
static func plain(s: String) -> String:
	return s.replace("Ō", "O").replace("ō", "o").replace("Ū", "U").replace("ū", "u")


## Temps réel écoulé depuis l'image précédente (indépendant du ralenti et de la pause),
## le même pour tous les écrans pendant une image.
static func real_delta() -> float:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		var now := Time.get_ticks_msec()
		_delta = 0.0 if _last_ms == 0 else minf(float(now - _last_ms) / 1000.0, 0.1)
		_last_ms = now
	return _delta


## Delta d'image ramené au temps réel (s'arrête quand le jeu est figé : time_scale = 0).
static func unscaled(delta: float, cap := 0.1) -> float:
	return minf(delta / maxf(Engine.time_scale, 0.0001), cap)


static func ease_out(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


## Texte centré horizontalement sur `center.x` (ligne de base en `center.y`) ; renvoie sa largeur.
static func text(ci: CanvasItem, font: Font, txt: String, center: Vector2, fs: int, c: Color) -> float:
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, Vector2(center.x - tw / 2.0, center.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return tw


## Remet à neuf une StyleBoxFlat réutilisée : fond, coins, bordure facultative, sans ombre.
## draw_style_box dessine tout de suite : on peut la reconfigurer pour le tracé suivant.
static func box(sb: StyleBoxFlat, bg: Color, radius := 0, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2.ZERO
	return sb


## Symbole d'une figure au pinceau, dans un sceau rond de rayon r (même dessin que le HUD).
static func figure(ci: CanvasItem, shape: String, c: Vector2, r: float, a: float) -> void:
	ci.draw_circle(c, r + 2.5 * r / 30.0, Color(Toon.ui_ink, 0.85 * a))
	ci.draw_circle(c, r, Color(Toon.ui_paper, 0.95 * a))
	var ink := Color(Toon.ui_ink, a)
	var w := 4.0 * r / 30.0
	var s := r * 0.62
	match shape:
		"loop":
			var pts := PackedVector2Array()
			for i in 40:
				var t := float(i) / 39.0
				pts.append(c + Vector2.from_angle(t * TAU * 1.75) * s * (0.15 + 0.85 * t))
			ci.draw_polyline(pts, ink, w, true)
		"zigzag":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.6, -0.9) * s, c + Vector2(0.25, -0.15) * s, c + Vector2(-0.25, 0.1) * s, c + Vector2(0.6, 0.9) * s]), Color(Toon.GOLD.darkened(0.2), a), w * 1.2, true)
		"straight":
			ci.draw_line(c + Vector2(-0.95, 0.55) * s, c + Vector2(0.95, -0.55) * s, ink, w * 1.3, true)
			ci.draw_line(c + Vector2(-0.6, 0.55) * s, c + Vector2(0.95, -0.35) * s, Color(Toon.VERMILION, a * 0.8), w * 0.5, true)
		"return":
			ci.draw_arc(c + Vector2(0, -0.1) * s, s * 0.55, PI, TAU, 16, ink, w, true)
			ci.draw_line(c + Vector2(-0.55, -0.1) * s, c + Vector2(-0.55, 0.8) * s, ink, w, true)
			ci.draw_line(c + Vector2(0.55, -0.1) * s, c + Vector2(0.55, 0.6) * s, ink, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.3, 0.55) * s, c + Vector2(0.8, 0.55) * s, c + Vector2(0.55, 0.95) * s]), ink)
		"enso":
			ci.draw_arc(c, s * 0.85, -PI * 0.35, PI * 1.5, 32, ink, w * 1.5, true)
			ci.draw_circle(c + Vector2.from_angle(-PI * 0.35) * s * 0.85, w * 0.9, ink)
		"hook":
			ci.draw_line(c + Vector2(0.35, -0.9) * s, c + Vector2(0.35, 0.3) * s, ink, w, true)
			ci.draw_arc(c + Vector2(0.0, 0.3) * s, s * 0.35, 0.0, PI, 14, ink, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.35, 0.3) * s, c + Vector2(-0.6, 0.0) * s, c + Vector2(-0.2, 0.05) * s]), ink)


## Vignette d'une Vue (meta.PRINTS) : ciel en bokashi, Fuji enneigé, sol, cartouche et filet.
static func print_thumb(ci: CanvasItem, r: Rect2, p: Dictionary, u: float, a := 1.0) -> void:
	var sky: Color = p.get("sky", Toon.WASHI)
	var fuji: Color = p.get("fuji", Toon.PRUSSIAN)
	var ground: Color = p.get("ground", Toon.WOOD)
	var fx := float(p.get("fx", 0.5))
	var x0 := r.position.x
	var y0 := r.position.y
	var xe := r.end.x
	var hz := y0 + r.size.y * 0.64
	var top := sky.lerp(Toon.PRUSSIAN, 0.35)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(xe, y0), Vector2(xe, hz), Vector2(x0, hz)]),
		PackedColorArray([Color(top, a), Color(top, a), Color(sky, a), Color(sky, a)]))
	var cx := clampf(x0 + r.size.x * fx, x0 + r.size.x * 0.3, xe - r.size.x * 0.3)
	var peak := hz - r.size.y * 0.4
	var bw := r.size.x * 0.3
	var tw := r.size.x * 0.05
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - bw, hz), Vector2(cx - tw, peak), Vector2(cx + tw, peak), Vector2(cx + bw, hz)]), Color(fuji, a))
	var sd := (hz - peak) * 0.32
	var sx := tw + (bw - tw) * 0.32
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - tw, peak), Vector2(cx + tw, peak), Vector2(cx + sx, peak + sd),
		Vector2(cx + sx * 0.3, peak + sd * 0.7), Vector2(cx - sx * 0.2, peak + sd * 1.05), Vector2(cx - sx, peak + sd)]), Color(Toon.WASHI, a))
	ci.draw_rect(Rect2(Vector2(x0, hz), Vector2(r.size.x, r.end.y - hz)), Color(ground, a))
	var cart := Rect2(r.position + Vector2(3, 3) * u, Vector2(4, 12) * u)
	ci.draw_rect(cart, Color(Color("#E8D9A8"), a))
	ci.draw_rect(r, Color(Toon.SUMI, 0.7 * a), false, 1.2 * u)


# ------------------------------------------------------------------ pictogrammes des pouvoirs
# Tout est dessiné en coordonnées unité (environ -1..1, y vers le bas), mis à l'échelle du rayon r.
# glyph() : un pictogramme nommé ; `bg` sert aux découpes (yeux, reflets), ignorées s'il est transparent.

const Data = preload("res://scripts/power_data.gd")
const NONE := Color(0, 0, 0, 0)

static var _shapes := {}  # polygones unité, calculés une fois


## Nom du pictogramme d'un pouvoir (champ « icon », sinon celui de son école).
static func icon_of(id: String) -> String:
	var d: Dictionary = Data.POWERS.get(id, {})
	if d.is_empty():
		return "ink"
	return String(d.get("icon", d.get("school", "ink")))


static func power_school(id: String) -> String:
	var d: Dictionary = Data.POWERS.get(id, {})
	return String(d.get("school", "ink"))


## Couleur d'un pouvoir : celle de son élément ; les rouleaux de figure prennent l'élément de leur technique
## (boucle = vent, zigzag = foudre, retour = eau, crochet = ombre, trait droit et ensō = encre).
const FIG_COLOR_SCHOOL := {"loop": "wind", "zigzag": "bolt", "return": "water", "hook": "shadow", "straight": "ink", "enso": "ink"}


static func power_color(id: String) -> Color:
	var school := power_school(id)
	if school == "fig":
		for f in FIG_COLOR_SCHOOL.keys():
			if id.begins_with("fig_" + String(f)):
				return school_color(String(FIG_COLOR_SCHOOL[f]))
	return school_color(school)


static func school_color(school: String) -> Color:
	var sd: Dictionary = Data.SCHOOLS.get(school, {})
	return sd.get("color", Toon.SUMI)


## Nom court en français (champ « label », sinon le nom), sans macrons.
static func power_label(id: String) -> String:
	var d: Dictionary = Data.POWERS.get(id, {})
	if d.is_empty():
		return id
	return plain(String(d.get("label", d.get("name", id))))


## Pictogramme d'école seul (couleur `col`), dans un rayon r.
static func school_icon(ci: CanvasItem, school: String, c: Vector2, r: float, col: Color, a := 1.0, bg := NONE) -> void:
	glyph(ci, school, c, r, col, bg, a)


## Pictogramme propre d'un pouvoir, couleur `col` (découpes en `bg`).
static func power_glyph(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color, bg := NONE, a := 1.0) -> void:
	glyph(ci, icon_of(id), c, r, col, bg, a)


## Pastille complète : disque de la couleur d'école, pictogramme du pouvoir en papier.
static func power_icon(ci: CanvasItem, id: String, c: Vector2, r: float, a := 1.0) -> void:
	var col := power_color(id)
	ci.draw_circle(c, r, Color(col, a))
	# léger relief : lune plus claire en haut
	ci.draw_circle(c + Vector2(0, -r * 0.18), r * 0.78, Color(col.lightened(0.12), 0.5 * a))
	glyph(ci, icon_of(id), c, r * 0.64, Toon.WASHI, col, a)


## Déclencheur d'un pouvoir (champ « trig ») en petit pictogramme.
static func trigger_icon(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color, bg := NONE, a := 1.0) -> void:
	var d: Dictionary = Data.POWERS.get(id, {})
	glyph(ci, "t_" + String(d.get("trig", "always")), c, r, col, bg, a)


static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)


static func _shape(name: String) -> PackedVector2Array:
	if _shapes.has(name):
		return _shapes[name]
	var p := PackedVector2Array()
	match name:
		"flame":
			for i in 13:
				var t := PI * float(i) / 12.0
				p.append(Vector2(0, 0.3) + Vector2(cos(t), sin(t)) * 0.6)
			for i in range(1, 11):
				p.append(_bez(Vector2(-0.6, 0.3), Vector2(-0.68, -0.4), Vector2(0.1, -1.0), float(i) / 10.0))
			for i in range(1, 10):
				p.append(_bez(Vector2(0.1, -1.0), Vector2(0.72, -0.35), Vector2(0.6, 0.3), float(i) / 10.0))
		"drop":
			for i in 15:
				var t := lerpf(-0.46, PI + 0.46, float(i) / 14.0)
				p.append(Vector2(0, 0.35) + Vector2(cos(t), sin(t)) * 0.6)
			p.append(Vector2(0, -1.0))
		"heart":
			for i in 28:
				var t := TAU * float(i) / 28.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				p.append(Vector2(x, -y) / 16.0 + Vector2(0, -0.12))
		"bolt":
			p = PackedVector2Array([Vector2(0.25, -1.0), Vector2(-0.5, 0.12), Vector2(-0.05, 0.12), Vector2(-0.3, 1.0), Vector2(0.5, -0.2), Vector2(0.05, -0.2)])
		"crescent":
			for i in 17:
				var t := lerpf(0.35 * PI, 1.65 * PI, float(i) / 16.0)
				p.append(Vector2(cos(t), sin(t)))
			for j in range(1, 12):
				var f := 1.5 * PI - PI * float(j) / 12.0
				p.append(Vector2(0.44, 0) + Vector2(cos(f), sin(f)) * 0.89)
		"shield":
			p = PackedVector2Array([Vector2(-0.75, -0.8), Vector2(0.75, -0.8), Vector2(0.75, -0.15)])
			for i in range(1, 9):
				p.append(_bez(Vector2(0.75, -0.15), Vector2(0.7, 0.55), Vector2(0, 0.98), float(i) / 8.0))
			for i in range(1, 9):
				p.append(_bez(Vector2(0, 0.98), Vector2(-0.7, 0.55), Vector2(-0.75, -0.15), float(i) / 8.0))
		"great_wave":
			p = PackedVector2Array([Vector2(1, 0.85), Vector2(1, 0.1), Vector2(0.7, -0.5), Vector2(0.25, -0.85), Vector2(-0.2, -0.85),
				Vector2(-0.55, -0.55), Vector2(-0.62, -0.18), Vector2(-0.35, -0.35), Vector2(-0.05, -0.4), Vector2(0.2, -0.15),
				Vector2(0.1, 0.2), Vector2(-0.4, 0.5), Vector2(-1, 0.6), Vector2(-1, 0.85)])
		"ghost":
			for i in 13:
				var t := PI + PI * float(i) / 12.0
				p.append(Vector2(0, -0.2) + Vector2(cos(t), sin(t)) * 0.68)
			p.append_array(PackedVector2Array([Vector2(0.68, 0.85), Vector2(0.45, 0.62), Vector2(0.23, 0.88), Vector2(0, 0.62),
				Vector2(-0.23, 0.88), Vector2(-0.45, 0.62), Vector2(-0.68, 0.85)]))
		"hood":
			for i in 13:
				var t := PI + PI * float(i) / 12.0
				p.append(Vector2(0, -0.1) + Vector2(cos(t), sin(t)) * 0.8)
			p.append_array(PackedVector2Array([Vector2(0.8, 0.95), Vector2(0.4, 0.8), Vector2(0, 0.95), Vector2(-0.4, 0.8), Vector2(-0.8, 0.95)]))
		"fox":
			p = PackedVector2Array([Vector2(-0.85, -0.9), Vector2(-0.3, -0.42), Vector2(0.3, -0.42), Vector2(0.85, -0.9),
				Vector2(0.72, 0.05), Vector2(0, 0.88), Vector2(-0.72, 0.05)])
		"leaf":
			for i in 13:
				var x := -1.0 + 2.0 * float(i) / 12.0
				p.append(Vector2(x, -0.32 * sin(PI * (x + 1.0) / 2.0)))
			for i in range(11, 0, -1):
				var x := -1.0 + 2.0 * float(i) / 12.0
				p.append(Vector2(x, 0.22 * sin(PI * (x + 1.0) / 2.0)))
		"chevron":
			p = PackedVector2Array([Vector2(-0.05, -0.75), Vector2(0.4, -0.75), Vector2(0.95, 0), Vector2(0.4, 0.75), Vector2(-0.05, 0.75), Vector2(0.5, 0)])
		"bag":
			p = PackedVector2Array([Vector2(-0.55, 0.92), Vector2(-0.55, -0.32), Vector2(-0.28, -0.58), Vector2(0.28, -0.58), Vector2(0.55, -0.32), Vector2(0.55, 0.92)])
		"star4", "star5", "star8":
			var n := 4
			var inner := 0.36
			if name == "star5":
				n = 5
				inner = 0.45
			elif name == "star8":
				n = 8
				inner = 0.42
			for i in n * 2:
				var t := -PI / 2.0 + PI * float(i) / float(n)
				p.append(Vector2(cos(t), sin(t)) * (1.0 if i % 2 == 0 else inner))
	_shapes[name] = p
	return p


## Polygone plein, bord adouci d'un fin contour.
static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, col, 1.0, true)


static func _shp(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color, off := Vector2.ZERO, k := 1.0, rot := 0.0) -> void:
	_poly(ci, Transform2D(rot, Vector2(s * k, s * k), 0.0, c + off * s) * _shape(name), col)


static func _ln(ci: CanvasItem, c: Vector2, s: float, p0: Vector2, p1: Vector2, col: Color, w: float) -> void:
	ci.draw_line(c + p0 * s, c + p1 * s, col, w, true)


static func _pl(ci: CanvasItem, c: Vector2, s: float, pts: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_polyline(Transform2D(0.0, Vector2(s, s), 0.0, c) * pts, col, w, true)


static func _dot(ci: CanvasItem, c: Vector2, s: float, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c + p * s, r * s, col)


static func _arc(ci: CanvasItem, c: Vector2, s: float, p: Vector2, r: float, a0: float, a1: float, col: Color, w: float) -> void:
	ci.draw_arc(c + p * s, r * s, a0, a1, 28, col, w, true)


static func _box(ci: CanvasItem, c: Vector2, s: float, p0: Vector2, p1: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(c + p0 * s, (p1 - p0) * s), col)


static func _ellipse(ci: CanvasItem, c: Vector2, s: float, p: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var t := TAU * float(i) / 16.0
		pts.append(c + (p + Vector2(cos(t) * rx, sin(t) * ry).rotated(rot)) * s)
	_poly(ci, pts, col)


## Trait effilé de p0 (épais) à p1 (fin), largeurs en unités.
static func _taper(ci: CanvasItem, c: Vector2, s: float, p0: Vector2, p1: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := (p1 - p0).normalized()
	var n := Vector2(-d.y, d.x)
	_poly(ci, PackedVector2Array([c + (p0 + n * w0 / 2.0) * s, c + (p1 + n * w1 / 2.0) * s, c + (p1 - n * w1 / 2.0) * s, c + (p0 - n * w0 / 2.0) * s]), col)


## Arc effilé aux deux bouts (lame de vent).
static func _sweep(ci: CanvasItem, c: Vector2, s: float, p: Vector2, r: float, a0: float, a1: float, wmax: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var t := float(i) / n
		var ang := lerpf(a0, a1, t)
		pts.append(c + (p + Vector2(cos(ang), sin(ang)) * (r + wmax * sin(PI * t) / 2.0)) * s)
	for i in range(n - 1, 0, -1):
		var t := float(i) / n
		var ang := lerpf(a0, a1, t)
		pts.append(c + (p + Vector2(cos(ang), sin(ang)) * (r - wmax * sin(PI * t) / 2.0)) * s)
	_poly(ci, pts, col)


static func _head(ci: CanvasItem, c: Vector2, s: float, tip: Vector2, dir: Vector2, size: float, col: Color) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	_poly(ci, PackedVector2Array([c + tip * s, c + (tip - d * size + n * size * 0.62) * s, c + (tip - d * size - n * size * 0.62) * s]), col)


## Silhouette (tête et épaules) centrée en p, taille k.
static func _person(ci: CanvasItem, c: Vector2, s: float, p: Vector2, k: float, col: Color) -> void:
	ci.draw_circle(c + (p + Vector2(0, -0.35) * k) * s, 0.26 * k * s, col)
	var pts := PackedVector2Array()
	for i in 13:
		var t := PI + PI * float(i) / 12.0
		pts.append(c + (p + Vector2(0, 0.55) * k + Vector2(cos(t), sin(t)) * 0.5 * k) * s)
	_poly(ci, pts, col)


static func _cloud(ci: CanvasItem, c: Vector2, s: float, p: Vector2, k: float, col: Color) -> void:
	ci.draw_circle(c + (p + Vector2(-0.45, -0.25) * k) * s, 0.35 * k * s, col)
	ci.draw_circle(c + (p + Vector2(0.05, -0.45) * k) * s, 0.45 * k * s, col)
	ci.draw_circle(c + (p + Vector2(0.5, -0.25) * k) * s, 0.35 * k * s, col)
	ci.draw_rect(Rect2(c + (p + Vector2(-0.45, -0.3) * k) * s, Vector2(0.95, 0.4) * k * s), col)


## Symbole d'une figure (même dessin que UiKit.figure) en coordonnées unité, centré en `off`, taille k.
static func _fsym(ci: CanvasItem, shape: String, c: Vector2, s: float, col: Color, w: float, off := Vector2.ZERO, k := 1.0) -> void:
	var o := c + off * s
	var q := s * k
	match shape:
		"loop":
			var pts := PackedVector2Array()
			for i in 40:
				var t := float(i) / 39.0
				pts.append(Vector2.from_angle(t * TAU * 1.75) * 0.85 * (0.15 + 0.85 * t))
			_pl(ci, o, q, pts, col, w)
		"zigzag":
			_pl(ci, o, q, PackedVector2Array([Vector2(-0.6, -0.9), Vector2(0.25, -0.15), Vector2(-0.25, 0.1), Vector2(0.6, 0.9)]), col, w * 1.2)
		"straight":
			_ln(ci, o, q, Vector2(-0.95, 0.55), Vector2(0.95, -0.55), col, w * 1.3)
		"return":
			_arc(ci, o, q, Vector2(0, -0.1), 0.55, PI, TAU, col, w)
			_ln(ci, o, q, Vector2(-0.55, -0.1), Vector2(-0.55, 0.8), col, w)
			_ln(ci, o, q, Vector2(0.55, -0.1), Vector2(0.55, 0.55), col, w)
			_head(ci, o, q, Vector2(0.55, 0.95), Vector2(0, 1), 0.4, col)
		"enso":
			_arc(ci, o, q, Vector2.ZERO, 0.8, -PI * 0.35, PI * 1.45, col, w * 1.5)
			ci.draw_circle(o + Vector2.from_angle(-PI * 0.35) * 0.8 * q, w * 0.8, col)
		"hook":
			_ln(ci, o, q, Vector2(0.35, -0.9), Vector2(0.35, 0.3), col, w)
			_arc(ci, o, q, Vector2(0.0, 0.3), 0.35, 0.0, PI, col, w)
			_head(ci, o, q, Vector2(-0.45, 0.0), Vector2(-0.25, -1.0), 0.4, col)


static func _sword(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	_taper(ci, c, s, Vector2(-0.4, 0.4), Vector2(0.8, -0.8), 0.24, 0.04, col)
	_ln(ci, c, s, Vector2(-0.66, 0.16), Vector2(-0.16, 0.66), col, w * 1.1)
	_ln(ci, c, s, Vector2(-0.4, 0.4), Vector2(-0.82, 0.82), col, w * 1.2)


## Un pictogramme nommé (école, pouvoir, déclencheur « t_… », don de l'Atelier, bandeau),
## de couleur `col`, tenant dans un rayon r autour de c.
static func glyph(ci: CanvasItem, name: String, c: Vector2, r: float, col: Color, bg := NONE, a := 1.0) -> void:
	var s := r
	var w := maxf(1.2, r * 0.17)
	var k := Color(col, col.a * a)
	var b := Color(bg, bg.a * a)
	var cut := bg.a > 0.01
	match name:
		# ------------------------------------------------ écoles
		"fire":
			_shp(ci, "flame", c, s, k, Vector2(0, 0.05), 0.95)
			if cut:
				_shp(ci, "flame", c, s, b, Vector2(0.02, 0.45), 0.38)
		"water":
			_shp(ci, "drop", c, s, k, Vector2(0, 0.02), 0.95)
			if cut:
				_arc(ci, c, s, Vector2(0, 0.35), 0.36, PI * 0.6, PI * 0.95, b, w * 0.8)
		"bolt":
			_shp(ci, "bolt", c, s, k, Vector2.ZERO, 0.95)
		"wind":
			_ln(ci, c, s, Vector2(-0.95, -0.35), Vector2(0.35, -0.35), k, w)
			_arc(ci, c, s, Vector2(0.35, -0.6), 0.25, PI * 0.5, -PI * 0.9, k, w)
			_ln(ci, c, s, Vector2(-0.75, 0.05), Vector2(0.8, 0.05), k, w)
			_ln(ci, c, s, Vector2(-0.95, 0.45), Vector2(0.15, 0.45), k, w)
			_arc(ci, c, s, Vector2(0.15, 0.7), 0.25, -PI * 0.5, PI * 0.9, k, w)
		"shadow":
			_shp(ci, "crescent", c, s, k, Vector2(-0.12, 0.05), 0.85)
			_shp(ci, "star4", c, s, k, Vector2(0.55, -0.45), 0.3)
		"ink":
			_ln(ci, c, s, Vector2(0.8, -0.85), Vector2(0.12, -0.18), k, w * 1.3)
			_ln(ci, c, s, Vector2(0.18, -0.24), Vector2(-0.02, -0.04), k, w * 2.2)
			_shp(ci, "drop", c, s, k, Vector2(-0.32, 0.33), 0.52, deg_to_rad(220.0))
		# ------------------------------------------------ feu
		"blade_fire":
			_sword(ci, c, s, k, w)
			_shp(ci, "flame", c, s, k, Vector2(0.45, 0.42), 0.45)
		"claws_fire":
			for i in 3:
				var x0 := -0.5 + 0.38 * float(i)
				_taper(ci, c, s, Vector2(x0 + 0.45, -0.85), Vector2(x0 - 0.35, 0.25), 0.24, 0.04, k)
			_shp(ci, "flame", c, s, k, Vector2(0.52, 0.5), 0.42)
		"trail_fire":
			_taper(ci, c, s, Vector2(-0.95, 0.72), Vector2(0.95, 0.72), 0.18, 0.06, k)
			_shp(ci, "flame", c, s, k, Vector2(-0.45, 0.05), 0.55)
			_shp(ci, "flame", c, s, k, Vector2(0.35, -0.05), 0.65)
		"ring_fire":
			_dot(ci, c, s, Vector2.ZERO, 0.2, k)
			_arc(ci, c, s, Vector2.ZERO, 0.56, 0.0, TAU, k, w)
			for i in 8:
				var t := TAU * float(i) / 8.0 - PI / 2.0
				_poly(ci, PackedVector2Array([c + Vector2.from_angle(t - 0.2) * 0.68 * s, c + Vector2.from_angle(t) * 1.0 * s, c + Vector2.from_angle(t + 0.2) * 0.68 * s]), k)
		"spark":
			_shp(ci, "star8", c, s, k, Vector2.ZERO, 0.95)
			if cut:
				_dot(ci, c, s, Vector2.ZERO, 0.14, b)
		"wheel_fire":
			_arc(ci, c, s, Vector2(0, 0.25), 0.52, 0.0, TAU, k, w)
			for i in 6:
				_ln(ci, c, s, Vector2(0, 0.25), Vector2(0, 0.25) + Vector2.from_angle(TAU * float(i) / 6.0) * 0.52, k, w * 0.7)
			_dot(ci, c, s, Vector2(0, 0.25), 0.13, k)
			_shp(ci, "flame", c, s, k, Vector2(0, -0.52), 0.45)
		"halo_fire":
			var o := Vector2(0, 0.1)
			_arc(ci, c, s, o, 0.78, PI * 0.8, PI * 2.2, k, w)
			for t in [-PI / 2.0, -PI / 2.0 - 0.75, -PI / 2.0 + 0.75]:
				var ang := float(t)
				_poly(ci, PackedVector2Array([c + (o + Vector2.from_angle(ang - 0.22) * 0.8) * s, c + (o + Vector2.from_angle(ang) * 1.08) * s, c + (o + Vector2.from_angle(ang + 0.22) * 0.8) * s]), k)
			_person(ci, c, s, Vector2(0, 0.25), 0.75, k)
		"phoenix":
			for i in 4:
				var t := -PI / 2.0 + 0.42 * float(i)
				_shp(ci, "leaf", c, s, k, Vector2(-0.55, 0.6) + Vector2.from_angle(t) * 0.58, 0.58, t)
			_shp(ci, "flame", c, s, k, Vector2(0.55, 0.55), 0.36)
		# ------------------------------------------------ eau
		"push_wave":
			_arc(ci, c, s, Vector2(-1.15, 0), 0.5, -0.75, 0.75, k, w)
			_arc(ci, c, s, Vector2(-1.15, 0), 0.85, -0.6, 0.6, k, w)
			_ln(ci, c, s, Vector2(-0.15, 0), Vector2(0.6, 0), k, w * 1.3)
			_head(ci, c, s, Vector2(0.95, 0), Vector2(1, 0), 0.42, k)
		"heart_drop":
			_shp(ci, "heart", c, s, k, Vector2(-0.12, 0.18), 0.72)
			_shp(ci, "drop", c, s, k, Vector2(0.58, -0.55), 0.38)
		"shield":
			_shp(ci, "shield", c, s, k, Vector2.ZERO, 0.95)
			if cut:
				_arc(ci, c, s, Vector2(-0.12, -0.15), 0.26, 0.0, TAU, b, w * 0.6)
		"tide":
			_dot(ci, c, s, Vector2.ZERO, 0.2, k)
			for j in 4:
				var a0 := float(j) * PI / 2.0 + 0.25
				_arc(ci, c, s, Vector2.ZERO, 0.55, a0, a0 + PI / 2.0 - 0.5, k, w)
				_arc(ci, c, s, Vector2.ZERO, 0.9, a0 + 0.1, a0 + PI / 2.0 - 0.6, k, w)
		"whirl":
			var sp := PackedVector2Array()
			for i in 40:
				var t := float(i) / 39.0
				sp.append(Vector2.from_angle(t * TAU * 2.2) * (0.08 + 0.88 * t))
			_pl(ci, c, s, sp, k, w)
		"mirror":
			_ln(ci, c, s, Vector2(0.55, -0.9), Vector2(0.55, 0.9), k, w * 1.6)
			_ln(ci, c, s, Vector2(-0.85, -0.6), Vector2(0.38, 0.0), k, w)
			_ln(ci, c, s, Vector2(0.38, 0.0), Vector2(-0.55, 0.46), k, w)
			_head(ci, c, s, Vector2(-0.88, 0.62), Vector2(-1.2, 0.6), 0.38, k)
		"great_wave":
			_shp(ci, "great_wave", c, s, k)
		# ------------------------------------------------ foudre
		"chain_bolt":
			_dot(ci, c, s, Vector2(-0.7, 0.6), 0.22, k)
			_dot(ci, c, s, Vector2(0.7, -0.6), 0.22, k)
			_pl(ci, c, s, PackedVector2Array([Vector2(-0.55, 0.45), Vector2(-0.02, 0.0), Vector2(0.06, 0.32), Vector2(0.55, -0.45)]), k, w * 1.2)
		"speed":
			_shp(ci, "chevron", c, s, k, Vector2(0.12, 0), 0.85)
			_ln(ci, c, s, Vector2(-0.95, -0.45), Vector2(-0.3, -0.45), k, w)
			_ln(ci, c, s, Vector2(-0.8, 0), Vector2(-0.05, 0), k, w)
			_ln(ci, c, s, Vector2(-0.95, 0.45), Vector2(-0.3, 0.45), k, w)
		"battery":
			ci.draw_rect(Rect2(c + Vector2(-0.85, -0.5) * s, Vector2(1.55, 1.0) * s), k, false, w)
			_box(ci, c, s, Vector2(0.72, -0.22), Vector2(0.92, 0.22), k)
			_shp(ci, "bolt", c, s, k, Vector2(-0.08, 0), 0.36)
		"storm":
			_cloud(ci, c, s, Vector2(0, -0.2), 1.0, k)
			_shp(ci, "bolt", c, s, k, Vector2(0.05, 0.45), 0.5)
		"stun":
			_dot(ci, c, s, Vector2(0, 0.45), 0.4, k)
			var el := PackedVector2Array()
			for i in 25:
				var t := TAU * float(i) / 24.0
				el.append(Vector2(cos(t) * 0.85, -0.38 + sin(t) * 0.28))
			_pl(ci, c, s, el, k, w * 0.7)
			_shp(ci, "star4", c, s, k, Vector2(-0.6, -0.45), 0.3)
			_shp(ci, "star4", c, s, k, Vector2(0.55, -0.28), 0.25)
		"paw":
			_dot(ci, c, s, Vector2(-0.2, 0.45), 0.3, k)
			_dot(ci, c, s, Vector2(0.2, 0.45), 0.3, k)
			_dot(ci, c, s, Vector2(0, 0.28), 0.33, k)
			_dot(ci, c, s, Vector2(-0.68, -0.12), 0.17, k)
			_dot(ci, c, s, Vector2(-0.27, -0.5), 0.18, k)
			_dot(ci, c, s, Vector2(0.27, -0.5), 0.18, k)
			_dot(ci, c, s, Vector2(0.68, -0.12), 0.17, k)
		"fork_bolt":
			_pl(ci, c, s, PackedVector2Array([Vector2(0.3, -0.95), Vector2(-0.25, -0.15), Vector2(0.2, 0.05), Vector2(-0.35, 0.95)]), k, w * 1.3)
			_pl(ci, c, s, PackedVector2Array([Vector2(0.2, 0.05), Vector2(0.75, 0.3), Vector2(0.55, 0.75)]), k, w)
		"drum":
			var dp := PackedVector2Array([c + Vector2(-0.62, -0.3) * s, c + Vector2(-0.75, 0.15) * s, c + Vector2(-0.62, 0.6) * s])
			for i in range(1, 8):
				var t := PI - PI * float(i) / 8.0
				dp.append(c + Vector2(0.62 * cos(t), 0.6 + 0.2 * sin(t)) * s)
			dp.append_array(PackedVector2Array([c + Vector2(0.62, 0.6) * s, c + Vector2(0.75, 0.15) * s, c + Vector2(0.62, -0.3) * s]))
			for i in range(1, 8):
				var t := -PI * float(i) / 8.0
				dp.append(c + Vector2(0.62 * cos(t), -0.3 + 0.2 * sin(t)) * s)
			_poly(ci, dp, k)
			if cut:
				var top := PackedVector2Array()
				for i in 17:
					var t := TAU * float(i) / 16.0
					top.append(Vector2(0.5 * cos(t), -0.3 + 0.12 * sin(t)))
				_pl(ci, c, s, top, b, w * 0.6)
			_ln(ci, c, s, Vector2(0.1, -0.42), Vector2(0.75, -0.95), k, w * 0.8)
			_ln(ci, c, s, Vector2(-0.1, -0.42), Vector2(-0.75, -0.95), k, w * 0.8)
			_dot(ci, c, s, Vector2(0.75, -0.95), 0.1, k)
			_dot(ci, c, s, Vector2(-0.75, -0.95), 0.1, k)
		# ------------------------------------------------ vent
		"long_stroke":
			_taper(ci, c, s, Vector2(-0.88, 0.42), Vector2(0.95, 0.42), 0.38, 0.05, k)
			_dot(ci, c, s, Vector2(-0.88, 0.42), 0.19, k)
			_ln(ci, c, s, Vector2(-0.6, -0.42), Vector2(0.6, -0.42), k, w)
			_head(ci, c, s, Vector2(0.95, -0.42), Vector2(1, 0), 0.38, k)
			_head(ci, c, s, Vector2(-0.95, -0.42), Vector2(-1, 0), 0.38, k)
		"refill":
			_shp(ci, "drop", c, s, k, Vector2(0, 0.08), 0.45)
			var e := PI * 1.2
			var ed := Vector2(-sin(e), cos(e))
			_arc(ci, c, s, Vector2.ZERO, 0.85, -PI * 0.3, e, k, w * 0.9)
			_head(ci, c, s, Vector2.from_angle(e) * 0.85 + ed * 0.14, ed, 0.34, k)
		"feather":
			_shp(ci, "leaf", c, s, k, Vector2(0.08, -0.08), 0.92, -PI / 4.0)
			if cut:
				_ln(ci, c, s, Vector2(-0.45, 0.45), Vector2(0.55, -0.55), b, maxf(1.0, w * 0.45))
			_ln(ci, c, s, Vector2(-0.5, 0.5), Vector2(-0.92, 0.92), k, w * 0.8)
		"blades":
			_sweep(ci, c, s, Vector2(-0.15, 0.95), 0.95, -2.5, -0.7, 0.34, k)
			_sweep(ci, c, s, Vector2(0.15, 0.4), 0.95, -2.5, -0.7, 0.34, k)
		"tornado":
			_ln(ci, c, s, Vector2(-0.85, -0.75), Vector2(0.85, -0.75), k, w * 1.1)
			_ln(ci, c, s, Vector2(-0.55, -0.38), Vector2(0.7, -0.38), k, w * 1.1)
			_ln(ci, c, s, Vector2(-0.3, 0.0), Vector2(0.5, 0.0), k, w * 1.1)
			_ln(ci, c, s, Vector2(-0.1, 0.38), Vector2(0.35, 0.38), k, w * 1.1)
			_ln(ci, c, s, Vector2(0.02, 0.74), Vector2(0.22, 0.74), k, w * 1.1)
		"clock":
			_arc(ci, c, s, Vector2(0, 0.08), 0.8, 0.0, TAU, k, w)
			_ln(ci, c, s, Vector2(0, -0.72), Vector2(0, -0.98), k, w * 1.4)
			_ln(ci, c, s, Vector2(0, 0.08), Vector2(0, -0.42), k, w)
			_ln(ci, c, s, Vector2(0, 0.08), Vector2(0.38, 0.22), k, w)
			_dot(ci, c, s, Vector2(0, 0.08), 0.1, k)
		"cloud_gust":
			_cloud(ci, c, s, Vector2(-0.2, -0.3), 0.85, k)
			_ln(ci, c, s, Vector2(-0.55, 0.28), Vector2(0.9, 0.28), k, w)
			_ln(ci, c, s, Vector2(-0.25, 0.62), Vector2(0.65, 0.62), k, w)
			_arc(ci, c, s, Vector2(0.9, 0.08), 0.2, PI * 0.5, -PI * 0.7, k, w)
		# ------------------------------------------------ ombre
		"backstab":
			_person(ci, c, s, Vector2(0.38, 0.12), 0.7, k)
			var e2 := -PI - 0.75
			var dir := Vector2(sin(e2), -cos(e2))
			_arc(ci, c, s, Vector2(0.1, 0.05), 0.75, -0.15, e2, k, w)
			_head(ci, c, s, Vector2(0.1, 0.05) + Vector2.from_angle(e2) * 0.75 + dir * 0.14, dir, 0.36, k)
		"footsteps":
			_ellipse(ci, c, s, Vector2(-0.38, 0.12), 0.2, 0.32, k, -0.2)
			_dot(ci, c, s, Vector2(-0.38, 0.12) + Vector2(0, 0.5).rotated(-0.2), 0.15, k)
			_ellipse(ci, c, s, Vector2(0.38, -0.45), 0.2, 0.32, k, 0.2)
			_dot(ci, c, s, Vector2(0.38, -0.45) + Vector2(0, 0.5).rotated(0.2), 0.15, k)
		"hood":
			_shp(ci, "hood", c, s, k, Vector2.ZERO, 0.95)
			if cut:
				_ellipse(ci, c, s, Vector2(0, 0.1), 0.42, 0.48, b)
				_ellipse(ci, c, s, Vector2(-0.17, 0.06), 0.11, 0.06, k)
				_ellipse(ci, c, s, Vector2(0.17, 0.06), 0.11, 0.06, k)
		"skull":
			_dot(ci, c, s, Vector2(0, -0.15), 0.68, k)
			_box(ci, c, s, Vector2(-0.38, 0.3), Vector2(0.38, 0.82), k)
			if cut:
				_dot(ci, c, s, Vector2(-0.26, -0.08), 0.19, b)
				_dot(ci, c, s, Vector2(0.26, -0.08), 0.19, b)
				_poly(ci, PackedVector2Array([c + Vector2(0, 0.12) * s, c + Vector2(0.09, 0.3) * s, c + Vector2(-0.09, 0.3) * s]), b)
				_ln(ci, c, s, Vector2(-0.13, 0.55), Vector2(-0.13, 0.82), b, maxf(1.0, w * 0.5))
				_ln(ci, c, s, Vector2(0.13, 0.55), Vector2(0.13, 0.82), b, maxf(1.0, w * 0.5))
		"ghost":
			_shp(ci, "ghost", c, s, k, Vector2.ZERO, 0.95)
			if cut:
				_ellipse(ci, c, s, Vector2(-0.22, -0.15), 0.1, 0.15, b)
				_ellipse(ci, c, s, Vector2(0.22, -0.15), 0.1, 0.15, b)
		"hourglass":
			_ln(ci, c, s, Vector2(-0.7, -0.88), Vector2(0.7, -0.88), k, w * 1.3)
			_ln(ci, c, s, Vector2(-0.7, 0.88), Vector2(0.7, 0.88), k, w * 1.3)
			_pl(ci, c, s, PackedVector2Array([Vector2(-0.55, -0.85), Vector2(0, 0), Vector2(-0.55, 0.85)]), k, w * 0.8)
			_pl(ci, c, s, PackedVector2Array([Vector2(0.55, -0.85), Vector2(0, 0), Vector2(0.55, 0.85)]), k, w * 0.8)
			_poly(ci, PackedVector2Array([c + Vector2(-0.35, -0.52) * s, c + Vector2(0.35, -0.52) * s, c + Vector2(0, -0.08) * s]), k)
			_poly(ci, PackedVector2Array([c + Vector2(-0.45, 0.85) * s, c + Vector2(0.45, 0.85) * s, c + Vector2(0, 0.42) * s]), k)
		"clone":
			_person(ci, c, s, Vector2(-0.32, -0.02), 0.75, Color(k, k.a * 0.45))
			_person(ci, c, s, Vector2(0.25, 0.12), 0.82, k)
		"fox":
			_shp(ci, "fox", c, s, k, Vector2.ZERO, 0.95)
			if cut:
				_ln(ci, c, s, Vector2(-0.42, 0.02), Vector2(-0.14, 0.14), b, w * 0.8)
				_ln(ci, c, s, Vector2(0.42, 0.02), Vector2(0.14, 0.14), b, w * 0.8)
				_dot(ci, c, s, Vector2(0, 0.7), 0.08, b)
			_shp(ci, "flame", c, s, k, Vector2(0, -0.72), 0.26)
		# ------------------------------------------------ encre
		"heart_plus":
			_shp(ci, "heart", c, s, k, Vector2(-0.15, 0.18), 0.78)
			_ln(ci, c, s, Vector2(0.62, -0.88), Vector2(0.62, -0.32), k, w * 1.2)
			_ln(ci, c, s, Vector2(0.34, -0.6), Vector2(0.9, -0.6), k, w * 1.2)
		"amulet":
			_shp(ci, "bag", c, s, k)
			_dot(ci, c, s, Vector2(0, -0.72), 0.14, k)
			_ln(ci, c, s, Vector2(0, -0.72), Vector2(-0.25, -0.98), k, w * 0.7)
			_ln(ci, c, s, Vector2(0, -0.72), Vector2(0.25, -0.98), k, w * 0.7)
			if cut:
				_shp(ci, "star4", c, s, b, Vector2(0, 0.22), 0.32)
		"stamp":
			_dot(ci, c, s, Vector2(0, -0.68), 0.25, k)
			_box(ci, c, s, Vector2(-0.16, -0.5), Vector2(0.16, -0.05), k)
			_box(ci, c, s, Vector2(-0.62, -0.08), Vector2(0.62, 0.28), k)
			ci.draw_rect(Rect2(c + Vector2(-0.48, 0.45) * s, Vector2(0.96, 0.48) * s), k, false, maxf(1.0, w * 0.7))
		"enso":
			_arc(ci, c, s, Vector2.ZERO, 0.75, -PI * 0.35, PI * 1.45, k, w * 1.6)
			ci.draw_circle(c + Vector2.from_angle(-PI * 0.35) * 0.75 * s, w * 0.9, k)
		"one_stroke":
			_taper(ci, c, s, Vector2(-0.82, 0.55), Vector2(0.92, -0.62), 0.42, 0.05, k)
			_dot(ci, c, s, Vector2(-0.82, 0.55), 0.21, k)
			_dot(ci, c, s, Vector2(0.5, 0.38), 0.09, k)
			_dot(ci, c, s, Vector2(0.72, 0.18), 0.06, k)
		# ------------------------------------------------ figures (le symbole de la forme, et ce que le rouleau ajoute)
		"fig":
			_fsym(ci, "loop", c, s, k, w, Vector2(-0.38, -0.32), 0.62)
			_fsym(ci, "zigzag", c, s, k, w, Vector2(0.42, 0.3), 0.62)
		"fig_loop":
			_fsym(ci, "loop", c, s, k, w)
		"fig_loop_pull":
			_fsym(ci, "loop", c, s, k, w, Vector2.ZERO, 0.62)
			for i in 4:
				var dl := Vector2.from_angle(PI * 0.25 + PI * 0.5 * float(i))
				_head(ci, c, s, dl * 0.68, -dl, 0.3, k)
		"fig_zigzag":
			_fsym(ci, "zigzag", c, s, k, w)
		"fig_zigzag_long":
			_fsym(ci, "zigzag", c, s, k, w, Vector2(-0.3, 0), 0.75)
			_ln(ci, c, s, Vector2(0.15, 0.62), Vector2(0.72, 0.1), k, w * 0.7)
			_dot(ci, c, s, Vector2(0.72, 0.1), 0.17, k)
			_ln(ci, c, s, Vector2(0.72, 0.1), Vector2(0.6, -0.55), k, w * 0.7)
			_dot(ci, c, s, Vector2(0.6, -0.55), 0.17, k)
		"fig_straight":
			_fsym(ci, "straight", c, s, k, w)
		"fig_straight_double":
			_fsym(ci, "straight", c, s, k, w, Vector2(-0.12, -0.2), 0.95)
			_fsym(ci, "straight", c, s, k, w, Vector2(0.12, 0.2), 0.95)
		"fig_straight_wave":
			_fsym(ci, "straight", c, s, k, w, Vector2(-0.22, 0.13), 0.72)
			_sweep(ci, c, s, Vector2(0.15, 0.1), 0.75, -1.3, 0.25, 0.3, k)
		"fig_return":
			_fsym(ci, "return", c, s, k, w)
		"fig_return_reflect":
			_fsym(ci, "return", c, s, k, w, Vector2(-0.3, 0.1), 0.72)
			_dot(ci, c, s, Vector2(0.55, -0.15), 0.17, k)
			_ln(ci, c, s, Vector2(0.55, -0.15), Vector2(0.8, -0.6), k, w * 0.7)
			_head(ci, c, s, Vector2(0.92, -0.85), Vector2(0.45, -0.9), 0.3, k)
		"fig_return_counter":
			_shp(ci, "shield", c, s, k, Vector2(-0.2, 0.1), 0.72)
			_shp(ci, "star4", c, s, k, Vector2(0.55, -0.55), 0.4)
		"fig_enso":
			_fsym(ci, "enso", c, s, k, w)
			_dot(ci, c, s, Vector2.ZERO, 0.14, k)
		"fig_enso_big":
			_fsym(ci, "enso", c, s, k, w, Vector2.ZERO, 0.7)
			_arc(ci, c, s, Vector2.ZERO, 0.95, 0.0, TAU, Color(k, k.a * 0.6), w * 0.6)
		"fig_enso_heal":
			_fsym(ci, "enso", c, s, k, w)
			_shp(ci, "heart", c, s, k, Vector2(0, 0.04), 0.36)
		"fig_hook":
			_fsym(ci, "hook", c, s, k, w)
		"fig_hook_back":
			_fsym(ci, "hook", c, s, k, w, Vector2(-0.32, 0.05), 0.75)
			_person(ci, c, s, Vector2(0.55, 0.15), 0.55, k)
		"fig_hook_double":
			_fsym(ci, "hook", c, s, k, w, Vector2(-0.35, 0.05), 0.72)
			_fsym(ci, "hook", c, s, k, w, Vector2(0.35, 0.05), 0.72)
		# ------------------------------------------------ sanctuaire, bandeaux, Atelier
		"oni":
			_dot(ci, c, s, Vector2(0, 0.2), 0.62, k)
			_poly(ci, PackedVector2Array([c + Vector2(-0.55, -0.05) * s, c + Vector2(-0.75, -0.95) * s, c + Vector2(-0.18, -0.32) * s]), k)
			_poly(ci, PackedVector2Array([c + Vector2(0.55, -0.05) * s, c + Vector2(0.18, -0.32) * s, c + Vector2(0.75, -0.95) * s]), k)
			if cut:
				_poly(ci, PackedVector2Array([c + Vector2(-0.42, 0.02) * s, c + Vector2(-0.1, 0.16) * s, c + Vector2(-0.36, 0.24) * s]), b)
				_poly(ci, PackedVector2Array([c + Vector2(0.42, 0.02) * s, c + Vector2(0.36, 0.24) * s, c + Vector2(0.1, 0.16) * s]), b)
				_box(ci, c, s, Vector2(-0.3, 0.44), Vector2(0.3, 0.58), b)
		# malédictions du sanctuaire
		"c_dry":
			# encre sèche : goutte fendue sous un pinceau
			_shp(ci, "drop", c, s, k, Vector2(-0.2, 0.18), 0.78)
			if cut:
				_pl(ci, c, s, PackedVector2Array([Vector2(-0.3, -0.22), Vector2(-0.12, 0.05), Vector2(-0.32, 0.28), Vector2(-0.16, 0.62)]), b, maxf(1.0, w * 0.8))
			_ln(ci, c, s, Vector2(0.95, -0.95), Vector2(0.5, -0.5), k, w * 1.1)
			_taper(ci, c, s, Vector2(0.55, -0.55), Vector2(0.28, -0.28), 0.26, 0.05, k)
		"c_eye":
			# œil d'oni : amande, iris, pupille fendue, deux cornes
			var eye := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				eye.append(c + Vector2(-0.88 + 1.76 * t, 0.15 - 0.5 * sin(PI * t)) * s)
			for i in range(11, 0, -1):
				var t2 := float(i) / 12.0
				eye.append(c + Vector2(-0.88 + 1.76 * t2, 0.15 + 0.4 * sin(PI * t2)) * s)
			_poly(ci, eye, k)
			if cut:
				_dot(ci, c, s, Vector2(0, 0.12), 0.32, b)
				_ellipse(ci, c, s, Vector2(0, 0.12), 0.08, 0.26, k)
			_poly(ci, PackedVector2Array([c + Vector2(-0.62, -0.16) * s, c + Vector2(-0.8, -0.95) * s, c + Vector2(-0.3, -0.3) * s]), k)
			_poly(ci, PackedVector2Array([c + Vector2(0.62, -0.16) * s, c + Vector2(0.3, -0.3) * s, c + Vector2(0.8, -0.95) * s]), k)
		"c_heavy":
			# pas lourd : poids de fonte à anneau
			_poly(ci, PackedVector2Array([c + Vector2(-0.5, -0.22) * s, c + Vector2(0.5, -0.22) * s, c + Vector2(0.82, 0.8) * s, c + Vector2(-0.82, 0.8) * s]), k)
			_arc(ci, c, s, Vector2(0, -0.42), 0.3, PI, TAU, k, w * 1.3)
			_ln(ci, c, s, Vector2(-0.3, -0.42), Vector2(-0.3, -0.2), k, w * 1.3)
			_ln(ci, c, s, Vector2(0.3, -0.42), Vector2(0.3, -0.2), k, w * 1.3)
			if cut:
				_ln(ci, c, s, Vector2(-0.4, 0.3), Vector2(0.4, 0.3), b, maxf(1.0, w * 0.8))
		"c_haste":
			# hâte des morts : sablier qui file
			glyph(ci, "hourglass", c + Vector2(0.24, 0) * s, r * 0.78, col, bg, a)
			_ln(ci, c, s, Vector2(-0.98, -0.4), Vector2(-0.5, -0.4), k, w)
			_ln(ci, c, s, Vector2(-1.0, 0.0), Vector2(-0.42, 0.0), k, w)
			_ln(ci, c, s, Vector2(-0.98, 0.4), Vector2(-0.5, 0.4), k, w)
		"path":
			_pl(ci, c, s, PackedVector2Array([Vector2(-0.7, -0.6), Vector2(-0.1, 0), Vector2(-0.7, 0.6)]), k, w * 1.4)
			_pl(ci, c, s, PackedVector2Array([Vector2(0.0, -0.6), Vector2(0.6, 0), Vector2(0.0, 0.6)]), k, w * 1.4)
		"torii":
			_poly(ci, PackedVector2Array([c + Vector2(-1.0, -0.88) * s, c + Vector2(1.0, -0.88) * s, c + Vector2(0.9, -0.66) * s, c + Vector2(-0.9, -0.66) * s]), k)
			_box(ci, c, s, Vector2(-0.78, -0.42), Vector2(0.78, -0.28), k)
			_box(ci, c, s, Vector2(-0.6, -0.68), Vector2(-0.42, 0.95), k)
			_box(ci, c, s, Vector2(0.42, -0.68), Vector2(0.6, 0.95), k)
			_box(ci, c, s, Vector2(-0.07, -0.68), Vector2(0.07, -0.3), k)
		"star":
			_shp(ci, "star5", c, s, k, Vector2(0, 0.06), 0.98)
		"check":
			_pl(ci, c, s, PackedVector2Array([Vector2(-0.72, 0.02), Vector2(-0.2, 0.55), Vector2(0.75, -0.55)]), k, w * 1.7)
		"cross":
			_ln(ci, c, s, Vector2(-0.6, -0.6), Vector2(0.6, 0.6), k, w * 1.7)
			_ln(ci, c, s, Vector2(0.6, -0.6), Vector2(-0.6, 0.6), k, w * 1.7)
		"reroll":
			for j in 2:
				var a0 := -PI * 0.1 + PI * float(j)
				var a1 := a0 + PI * 0.75
				var dd := Vector2(-sin(a1), cos(a1))
				_arc(ci, c, s, Vector2.ZERO, 0.7, a0, a1, k, w * 1.1)
				_head(ci, c, s, Vector2.from_angle(a1) * 0.7 + dd * 0.14, dd, 0.36, k)
		"scroll":
			_box(ci, c, s, Vector2(-0.55, -0.6), Vector2(0.55, 0.6), k)
			_box(ci, c, s, Vector2(-0.75, -0.82), Vector2(0.75, -0.58), k)
			_box(ci, c, s, Vector2(-0.75, 0.58), Vector2(0.75, 0.82), k)
			if cut:
				_ln(ci, c, s, Vector2(-0.35, -0.25), Vector2(0.35, -0.25), b, maxf(1.0, w * 0.6))
				_ln(ci, c, s, Vector2(-0.35, 0.05), Vector2(0.35, 0.05), b, maxf(1.0, w * 0.6))
				_ln(ci, c, s, Vector2(-0.35, 0.33), Vector2(0.15, 0.33), b, maxf(1.0, w * 0.6))
		"coin":
			_dot(ci, c, s, Vector2.ZERO, 0.85, k)
			if cut:
				_box(ci, c, s, Vector2(-0.22, -0.22), Vector2(0.22, 0.22), b)
				_arc(ci, c, s, Vector2.ZERO, 0.62, 0.0, TAU, b, maxf(1.0, w * 0.5))
		"cards":
			var card := PackedVector2Array([Vector2(-0.4, -0.6), Vector2(0.4, -0.6), Vector2(0.4, 0.6), Vector2(-0.4, 0.6)])
			_poly(ci, Transform2D(-0.3, Vector2(s, s), 0.0, c + Vector2(-0.25, 0.02) * s) * card, Color(k, k.a * 0.55))
			_poly(ci, Transform2D(0.2, Vector2(s, s), 0.0, c + Vector2(0.22, 0.05) * s) * card, k)
			if cut:
				_shp(ci, "star4", c, s, b, Vector2(0.22, 0.05), 0.3)
		"kintsugi":
			_shp(ci, "heart", c, s, k, Vector2(0, 0.12), 0.9)
			_pl(ci, c, s, PackedVector2Array([Vector2(-0.05, -0.5), Vector2(0.12, -0.12), Vector2(-0.1, 0.2), Vector2(0.08, 0.6)]), Color(Toon.GOLD, a), maxf(1.2, w * 0.8))
		# ------------------------------------------------ déclencheurs
		"t_hit":
			_sword(ci, c, s, k, w)
		"t_stroke":
			_taper(ci, c, s, Vector2(-0.8, 0.55), Vector2(0.9, -0.55), 0.4, 0.06, k)
			_dot(ci, c, s, Vector2(-0.8, 0.55), 0.2, k)
		"t_arrive":
			_dot(ci, c, s, Vector2.ZERO, 0.22, k)
			_arc(ci, c, s, Vector2.ZERO, 0.55, 0.0, TAU, k, w)
			_arc(ci, c, s, Vector2.ZERO, 0.9, 0.0, TAU, Color(k, k.a * 0.6), w * 0.8)
		"t_kill":
			glyph(ci, "skull", c, r, col, bg, a)
		"t_dodge":
			glyph(ci, "speed", c, r, col, bg, a)
		"t_always":
			var lem := PackedVector2Array()
			for i in 33:
				var t := TAU * float(i) / 32.0
				var dn := 1.0 + sin(t) * sin(t)
				lem.append(Vector2(0.92 * cos(t) / dn, 0.92 * sin(t) * cos(t) / dn))
			_pl(ci, c, s, lem, k, w * 1.2)
		"t_hurt":
			glyph(ci, "shield", c, r, col, bg, a)
		"t_figure":
			glyph(ci, "whirl", c, r, col, bg, a)
		"t_multi":
			_ln(ci, c, s, Vector2(-0.95, 0.0), Vector2(0.95, 0.0), k, w * 0.8)
			for i in 3:
				_dot(ci, c, s, Vector2(-0.58 + 0.58 * float(i), 0.0), 0.22, k)
		"t_timer":
			glyph(ci, "clock", c, r, col, bg, a)
		"t_back":
			glyph(ci, "backstab", c, r, col, bg, a)
		"t_target":
			_arc(ci, c, s, Vector2.ZERO, 0.6, 0.0, TAU, k, w)
			_dot(ci, c, s, Vector2.ZERO, 0.15, k)
			for i in 4:
				var d2 := Vector2.from_angle(PI * 0.5 * float(i))
				_ln(ci, c, s, d2 * 0.42, d2 * 0.98, k, w)
		"t_now":
			glyph(ci, "star", c, r, col, bg, a)
		"t_luck":
			glyph(ci, "cards", c, r, col, bg, a)
		"t_school":
			glyph(ci, "stamp", c, r, col, bg, a)
		"t_once":
			_arc(ci, c, s, Vector2.ZERO, 0.82, 0.0, TAU, k, w)
			var fs := maxi(6, int(s * 1.25))
			text(ci, UI_FONT, "1", c + Vector2(0, fs * 0.36), fs, k)
		"t_touch":
			_dot(ci, c, s, Vector2.ZERO, 0.28, k)
			_arc(ci, c, s, Vector2.ZERO, 0.6, 0.0, TAU, Color(k, k.a * 0.7), w * 0.8)
			_arc(ci, c, s, Vector2.ZERO, 0.92, 0.0, TAU, Color(k, k.a * 0.4), w * 0.7)
		# ------------------------------------------------ Atelier : lignes de la Pierre à encre, monnaies
		"at_brush":
			# pinceau long : manche, virole, pointe, et le trait qui file
			_taper(ci, c, s, Vector2(0.92, -0.92), Vector2(0.12, -0.12), 0.2, 0.22, k)
			_taper(ci, c, s, Vector2(0.14, -0.14), Vector2(-0.08, 0.08), 0.32, 0.32, k)
			_taper(ci, c, s, Vector2(-0.06, 0.06), Vector2(-0.46, 0.46), 0.3, 0.03, k)
			if cut:
				_ln(ci, c, s, Vector2(0.72, -0.52), Vector2(0.52, -0.72), b, maxf(1.0, w * 0.45))
				_ln(ci, c, s, Vector2(0.47, -0.27), Vector2(0.27, -0.47), b, maxf(1.0, w * 0.45))
			_taper(ci, c, s, Vector2(-0.6, 0.7), Vector2(0.95, 0.7), 0.24, 0.04, k)
			_dot(ci, c, s, Vector2(-0.6, 0.7), 0.12, k)
		"at_ink":
			# goutte d'encre et sa flèche de recharge
			_shp(ci, "drop", c, s, k, Vector2(-0.12, 0.0), 0.86)
			if cut:
				_arc(ci, c, s, Vector2(-0.3, 0.3), 0.26, PI * 0.95, PI * 1.4, b, maxf(1.0, w * 0.6))
				_dot(ci, c, s, Vector2(0.55, 0.55), 0.44, b)
			var ik0 := -PI * 0.35
			var ik1 := PI * 1.15
			var ikd := Vector2(-sin(ik1), cos(ik1))
			_arc(ci, c, s, Vector2(0.55, 0.55), 0.27, ik0, ik1, k, w * 0.75)
			_head(ci, c, s, Vector2(0.55, 0.55) + Vector2.from_angle(ik1) * 0.27 + ikd * 0.1, ikd, 0.24, k)
		"at_heart":
			_shp(ci, "heart", c, s, k, Vector2(-0.1, 0.12), 0.82)
			if cut:
				_dot(ci, c, s, Vector2(0.58, -0.55), 0.4, b)
			_ln(ci, c, s, Vector2(0.58, -0.78), Vector2(0.58, -0.32), k, w * 1.1)
			_ln(ci, c, s, Vector2(0.35, -0.55), Vector2(0.81, -0.55), k, w * 1.1)
		"at_breath":
			# second souffle : un filet tendu, et ce qui y retombe
			var nb_rim := PackedVector2Array()
			var nb_low := PackedVector2Array()
			for i in 9:
				var nb_t := float(i) / 8.0
				var nb_y := -0.05 + 0.5 * sin(PI * nb_t)
				nb_rim.append(Vector2(-0.92 + 1.84 * nb_t, nb_y))
				nb_low.append(Vector2(-0.92 + 1.84 * nb_t, nb_y + 0.32 * sin(PI * nb_t)))
			_pl(ci, c, s, nb_rim, k, w)
			_pl(ci, c, s, nb_low, k, w * 0.6)
			for i in range(1, 8):
				_ln(ci, c, s, nb_rim[i], nb_low[i - 1], k, w * 0.5)
				_ln(ci, c, s, nb_rim[i], nb_low[i + 1], k, w * 0.5)
			_dot(ci, c, s, Vector2(-0.92, -0.05), 0.11, k)
			_dot(ci, c, s, Vector2(0.92, -0.05), 0.11, k)
			_dot(ci, c, s, Vector2(0.0, -0.62), 0.22, k)
			_ln(ci, c, s, Vector2(-0.3, -0.98), Vector2(-0.12, -0.82), k, w * 0.6)
			_ln(ci, c, s, Vector2(0.3, -0.98), Vector2(0.12, -0.82), k, w * 0.6)
		"at_purse":
			# bourse nouée, une pièce dessus
			_ellipse(ci, c, s, Vector2(0, 0.3), 0.74, 0.6, k)
			_poly(ci, PackedVector2Array([c + Vector2(-0.56, -0.86) * s, c + Vector2(0.56, -0.86) * s, c + Vector2(0.24, -0.36) * s, c + Vector2(-0.24, -0.36) * s]), k)
			_box(ci, c, s, Vector2(-0.3, -0.42), Vector2(0.3, -0.18), k)
			if cut:
				_ln(ci, c, s, Vector2(-0.3, -0.32), Vector2(0.3, -0.32), b, maxf(1.0, w * 0.55))
				_arc(ci, c, s, Vector2(0, 0.36), 0.28, 0.0, TAU, b, maxf(1.0, w * 0.55))
				_box(ci, c, s, Vector2(-0.08, 0.28), Vector2(0.08, 0.44), b)
		"at_choice":
			# une carte de plus
			var ch_card := PackedVector2Array([Vector2(-0.36, -0.55), Vector2(0.36, -0.55), Vector2(0.36, 0.55), Vector2(-0.36, 0.55)])
			_poly(ci, Transform2D(-0.28, Vector2(s, s), 0.0, c + Vector2(-0.3, 0.1) * s) * ch_card, Color(k, k.a * 0.5))
			_poly(ci, Transform2D(0.12, Vector2(s, s), 0.0, c + Vector2(0.08, 0.14) * s) * ch_card, k)
			if cut:
				_shp(ci, "star4", c, s, b, Vector2(0.08, 0.14), 0.26)
				_dot(ci, c, s, Vector2(0.6, -0.6), 0.4, b)
			_ln(ci, c, s, Vector2(0.6, -0.84), Vector2(0.6, -0.36), k, w * 1.1)
			_ln(ci, c, s, Vector2(0.36, -0.6), Vector2(0.84, -0.6), k, w * 1.1)
		"at_drop":
			_shp(ci, "drop", c, s, k, Vector2(0, 0.05), 0.95)
			if cut:
				_arc(ci, c, s, Vector2(-0.18, 0.38), 0.3, PI * 0.9, PI * 1.35, b, maxf(1.0, w * 0.7))
		"at_seal":
			_box(ci, c, s, Vector2(-0.78, -0.78), Vector2(0.78, 0.78), k)
			if cut:
				ci.draw_rect(Rect2(c + Vector2(-0.56, -0.56) * s, Vector2(1.12, 1.12) * s), b, false, maxf(1.0, w * 0.55))
				_box(ci, c, s, Vector2(-0.3, -0.36), Vector2(0.3, -0.22), b)
				_box(ci, c, s, Vector2(-0.07, -0.22), Vector2(0.07, 0.36), b)
				_box(ci, c, s, Vector2(-0.34, 0.1), Vector2(0.34, 0.24), b)
		"at_print":
			ci.draw_rect(Rect2(c + Vector2(-0.82, -0.68) * s, Vector2(1.64, 1.36) * s), k, false, maxf(1.0, w * 0.8))
			_poly(ci, PackedVector2Array([c + Vector2(-0.62, 0.5) * s, c + Vector2(-0.12, -0.3) * s, c + Vector2(0.08, -0.3) * s, c + Vector2(0.62, 0.5) * s]), k)
			_dot(ci, c, s, Vector2(0.48, -0.36), 0.12, k)
			if cut:
				_poly(ci, PackedVector2Array([c + Vector2(-0.12, -0.3) * s, c + Vector2(0.08, -0.3) * s, c + Vector2(0.215, -0.1) * s,
					c + Vector2(0.05, -0.16) * s, c + Vector2(-0.05, -0.08) * s, c + Vector2(-0.245, -0.1) * s]), b)
		"at_lock":
			_arc(ci, c, s, Vector2(0, -0.28), 0.4, PI, TAU, k, w * 1.2)
			_ln(ci, c, s, Vector2(-0.4, -0.3), Vector2(-0.4, 0.0), k, w * 1.2)
			_ln(ci, c, s, Vector2(0.4, -0.3), Vector2(0.4, 0.0), k, w * 1.2)
			_box(ci, c, s, Vector2(-0.66, -0.04), Vector2(0.66, 0.88), k)
			if cut:
				_dot(ci, c, s, Vector2(0, 0.32), 0.13, b)
				_box(ci, c, s, Vector2(-0.05, 0.36), Vector2(0.05, 0.62), b)
		_:
			if name != "ink":
				glyph(ci, "ink", c, r, col, bg, a)


## Coupe `txt` en lignes d'au plus `width` pixels, mot à mot ; les mots de `glue` (ponctuation)
## ne commencent jamais une ligne.
static func wrap(font: Font, txt: String, fs: int, width: float, glue: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in txt.split(" ", false):
		var wd := String(word)
		var trial: String = wd if cur == "" else cur + " " + wd
		if cur != "" and not (wd in glue) and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			out.append(cur)
			cur = wd
		else:
			cur = trial
	if cur != "":
		out.append(cur)
	return out


## Aire d'un polygone (formule du lacet) : sert à sauter les morceaux trop fins avant de les dessiner
## (sinon la triangulation échoue et Godot écrit une erreur).
static func poly_area(pp: PackedVector2Array) -> float:
	var a := 0.0
	for i in pp.size():
		var p0 := pp[i]
		var p1 := pp[(i + 1) % pp.size()]
		a += p0.x * p1.y - p1.x * p0.y
	return absf(a * 0.5)


## Cintre (garde-robe) : crochet, épaules du cintre et petit kimono suspendu, dans un rayon s autour de c.
static func hanger_icon(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.2, s * 0.16)
	# crochet
	ci.draw_arc(c + Vector2(0, -s * 0.72), s * 0.2, PI * 1.05, PI * 2.2, 10, col, w, true)
	ci.draw_line(c + Vector2(0, -s * 0.52), c + Vector2(0, -s * 0.36), col, w, true)
	# barre du cintre
	ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.95, -s * 0.05), c + Vector2(0, -s * 0.4), c + Vector2(s * 0.95, -s * 0.05)]), col, w, true)
	# kimono : manches et corps, col croisé
	var body := PackedVector2Array([c + Vector2(-s * 0.95, -s * 0.05), c + Vector2(-s * 0.95, s * 0.35), c + Vector2(-s * 0.5, s * 0.35),
		c + Vector2(-s * 0.5, s * 0.95), c + Vector2(s * 0.5, s * 0.95), c + Vector2(s * 0.5, s * 0.35), c + Vector2(s * 0.95, s * 0.35),
		c + Vector2(s * 0.95, -s * 0.05), c + Vector2(0, -s * 0.4)])
	ci.draw_colored_polygon(body, Color(col, col.a * 0.85))
	var hole := Color(1, 1, 1, 0.0)
	if col.v < 0.5:
		hole = Color(Toon.WASHI, col.a * 0.9)
	else:
		hole = Color(Toon.SUMI, col.a * 0.9)
	ci.draw_line(c + Vector2(-s * 0.3, -s * 0.22), c + Vector2(s * 0.12, s * 0.4), hole, w * 0.8, true)
	ci.draw_line(c + Vector2(s * 0.3, -s * 0.22), c + Vector2(-s * 0.02, s * 0.18), hole, w * 0.8, true)
	ci.draw_line(c + Vector2(-s * 0.5, s * 0.52), c + Vector2(s * 0.5, s * 0.52), hole, w * 0.9, true)


# ------------------------------------------------------------------ pinceau et papier (accueil, pause, résultats)

## Petit bruit déterministe dans -1..1 (bords irréguliers, sans aléatoire : même dessin à chaque image).
static func _wob(x: float, sd: float) -> float:
	return 0.5 * sin(x * 12.9898 + sd * 78.233) + 0.5 * sin(x * 4.1 + sd * 3.7)


## Demi-épaisseur relative (0..1) d'un coup de pinceau horizontal en t : tête ronde, queue effilée.
static func swash_half(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return maxf(0.05, pow(maxf(0.0, sin(PI * x)), 0.3) * (1.0 - 0.5 * x * x))


## Point de l'axe du coup de pinceau tenant dans r (léger arc vers le haut).
static func swash_mid(r: Rect2, t: float) -> Vector2:
	return Vector2(r.position.x + r.size.x * t, r.get_center().y - r.size.y * 0.06 * sin(PI * clampf(t, 0.0, 1.0)))


## Contour du coup de pinceau tenant dans r ; reveal (0..1) le trace de gauche à droite.
static func swash_points(r: Rect2, reveal := 1.0, sd := 0.0) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var hh := r.size.y * 0.5
	var k := clampf(reveal, 0.02, 1.0)
	var n := clampi(int(r.size.x * k / 5.0), 4, 28)
	for i in n + 1:
		var t := k * float(i) / float(n)
		var mid := swash_mid(r, t)
		var th := hh * swash_half(t)
		top.append(mid - Vector2(0, th * (1.0 + 0.05 * _wob(float(i), sd))))
		bot.append(mid + Vector2(0, th * (1.0 + 0.05 * _wob(float(i) + 0.5, sd + 1.0))))
	bot.reverse()
	top.append_array(bot)
	return top


## Trait de pinceau de p0 (épais) à p1 (effilé), largeur w.
static func brush_line(ci: CanvasItem, p0: Vector2, p1: Vector2, w: float, col: Color) -> void:
	var d := p1 - p0
	if d.length() < 1.0 or w <= 0.0:
		return
	var nrm := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var t := float(i) / float(steps)
		pts.append(p0 + d * t + nrm * w * 0.5 * (0.55 + 0.45 * sin(PI * minf(1.0, t * 1.4 + 0.15))) * (1.0 - 0.7 * t))
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		pts.append(p0 + d * t - nrm * w * 0.5 * (0.55 + 0.45 * sin(PI * minf(1.0, t * 1.4 + 0.15))) * (1.0 - 0.7 * t))
	ci.draw_colored_polygon(pts, col)


## Ensō au pinceau : anneau ouvert, épais au départ et effilé au bout ; k (0..1) le trace depuis a0.
static func enso(ci: CanvasItem, c: Vector2, r: float, w: float, col: Color, k := 1.0, a0 := -PI * 0.4) -> void:
	var sweep := TAU * 0.92 * clampf(k, 0.0, 1.0)
	if sweep < 0.05 or w <= 0.0 or r <= w:
		return
	var n := maxi(8, int(48.0 * sweep / TAU))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var dir := Vector2.from_angle(a0 + sweep * t)
		var hw := w * 0.5 * (1.0 - 0.7 * t) * (1.0 + 0.08 * _wob(float(i), 4.0))
		outer.append(c + dir * (r + hw))
		inner.append(c + dir * (r - hw))
	inner.reverse()
	outer.append_array(inner)
	ci.draw_colored_polygon(outer, col)


## Contour d'un rectangle aux bords barbés (deckle), coins nets : amp = écart, step = pas.
static func deckle_points(r: Rect2, amp: float, step: float, sd := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var idx := 0
	for e in 4:
		var p0: Vector2 = corners[e]
		var p1: Vector2 = corners[(e + 1) % 4]
		var d := p1 - p0
		var n := maxi(2, int(d.length() / maxf(step, 1.0)))
		var out := Vector2(d.y, -d.x).normalized()  # vers l'extérieur (tour dans le sens horaire)
		for i in n:
			var t := float(i) / float(n)
			var j := 0.0
			if i > 0:
				j = amp * _wob(float(idx), sd)
			pts.append(p0 + d * t + out * j)
			idx += 1
	return pts


## Feuille de washi : ombre douce, papier aux bords barbés, quelques fibres et un filet intérieur.
static func washi_sheet(ci: CanvasItem, r: Rect2, paper: Color, ink: Color, a: float, u: float, sd := 0.0) -> void:
	var pts := deckle_points(r, 1.6 * u, 6.0 * u, sd)
	ci.draw_colored_polygon(Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0, 9.0 * u)) * pts, Color(0, 0, 0, 0.1 * a))
	ci.draw_colored_polygon(Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0, 3.0 * u)) * pts, Color(0, 0, 0, 0.14 * a))
	ci.draw_colored_polygon(pts, Color(paper, a))
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Color(ink, 0.22 * a), maxf(1.0, 1.1 * u), true)
	# fibres du papier
	for i in 14:
		var p := r.position + Vector2((0.5 + 0.46 * _wob(float(i), sd + 7.0)) * r.size.x, (0.5 + 0.46 * _wob(float(i) + 2.3, sd + 9.0)) * r.size.y)
		var dv := Vector2.from_angle(_wob(float(i), sd + 11.0) * PI) * (6.0 + 5.0 * absf(_wob(float(i), sd + 13.0))) * u
		ci.draw_line(p, p + dv, Color(ink, 0.045 * a), maxf(1.0, 0.8 * u), true)
	ci.draw_rect(r.grow(-7.0 * u), Color(ink, 0.1 * a), false, maxf(1.0, 0.9 * u))


## Sceau (hanko) : bords usés, filet intérieur, caractères en colonne (chars peut être vide).
static func hanko(ci: CanvasItem, r: Rect2, chars: String, col: Color, paper: Color, a: float, u: float, sd := 0.0) -> void:
	ci.draw_colored_polygon(deckle_points(r, 0.9 * u, 4.0 * u, sd), Color(col, a))
	ci.draw_rect(r.grow(-3.0 * u), Color(paper, 0.7 * a), false, maxf(1.0, 1.2 * u))
	var n := chars.length()
	if n > 0:
		var step := (r.size.y - 6.0 * u) / float(n)
		var fs := int(minf(r.size.x * 0.64, step * 0.84))
		for i in n:
			var cy := r.position.y + 3.0 * u + step * (float(i) + 0.5)
			text(ci, TITLE_FONT, chars.substr(i, 1), Vector2(r.get_center().x, cy + fs * 0.36), fs, Color(paper, a))
	# usure : quelques points de papier
	for i in 5:
		var p := r.position + Vector2((0.5 + 0.4 * _wob(float(i), sd + 2.0)) * r.size.x, (0.5 + 0.4 * _wob(float(i) + 3.0, sd)) * r.size.y)
		ci.draw_circle(p, (0.5 + 0.5 * absf(_wob(float(i), sd + 5.0))) * u, Color(paper, 0.45 * a))


## Marges de sécurité (encoche en haut, barre de geste en bas) en pixels de l'écran `view` ; nulles sur ordinateur.
static func safe_insets(view: Vector2) -> Vector2:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return Vector2.ZERO
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var k := view.y / float(win.y)
	var top := clampf(float(safe.position.y) * k, 0.0, view.y * 0.1)
	var bot := clampf(float(win.y - safe.end.y) * k, 0.0, view.y * 0.1)
	return Vector2(top, bot)


# ------------------------------------------------------------------ libellés des rouleaux (choix de pouvoir)

# nom en clair de chaque figure tracée
const FIG_WORD := {"loop": "BOUCLE", "zigzag": "ZIGZAG", "return": "ALLER-RETOUR", "straight": "TRAIT DROIT",
	"enso": "ENSO", "hook": "CROCHET"}
# déclencheur (champ « trig ») en un ou deux mots, quand la phrase complète ne tient pas
const TRIG_WORD := {"hit": "À CHAQUE COUP", "stroke": "À CHAQUE TRAIT", "arrive": "À L'ARRIVÉE", "kill": "EN TUANT",
	"always": "PERMANENT", "dodge": "ESQUIVE", "hurt": "SI TOUCHÉ", "multi": "MULTI-TOUCHE", "target": "CIBLE",
	"timer": "MINUTERIE", "once": "1 FOIS", "now": "IMMÉDIAT", "luck": "ROULEAUX", "school": "ÉCOLE",
	"back": "DANS LE DOS", "touch": "DOIGT POSÉ", "figure": "TECHNIQUE"}


## Figure qui déclenche un pouvoir ("loop", "zigzag"…) : la sienne pour un rouleau de figure,
## sinon celle de l'unique technique requise ; "" s'il n'y en a pas.
static func trigger_figure(id: String) -> String:
	for f in Data.FIG_UNLOCK.keys():
		if id == String(Data.FIG_UNLOCK[f]) or id.begins_with(String(Data.FIG_UNLOCK[f]) + "_"):
			return String(f)
	var d: Dictionary = Data.POWERS.get(id, {})
	var needs: Array = d.get("needs", [])
	if needs.size() == 1:
		for f in Data.FIG_UNLOCK.keys():
			if String(needs[0]) == String(Data.FIG_UNLOCK[f]):
				return String(f)
	return ""


## Déclencheur en un ou deux mots (sans macrons).
static func trigger_word(id: String) -> String:
	var f := trigger_figure(id)
	if f != "":
		return String(FIG_WORD.get(f, "FIGURE"))
	var d: Dictionary = Data.POWERS.get(id, {})
	return plain(String(TRIG_WORD.get(String(d.get("trig", "always")), "PERMANENT")))


# sens des déclencheurs qui ne parlent pas d'eux-mêmes (explication des rouleaux)
const TRIG_HINT := {"back": "frappe de dos", "arrive": "fin de ton trait", "multi": "plusieurs ennemis d'un trait",
	"timer": "à intervalle régulier"}


## Déclencheur et son sens, en une courte ligne (« DANS LE DOS = frappe de dos », « ENSO = trace la figure ») ;
## "" si le mot se comprend seul.
static func trigger_hint(id: String) -> String:
	var f := trigger_figure(id)
	if f != "":
		return "%s = trace la figure" % String(FIG_WORD.get(f, "FIGURE"))
	var d: Dictionary = Data.POWERS.get(id, {})
	var trig := String(d.get("trig", ""))
	if not TRIG_HINT.has(trig):
		return ""
	return plain("%s = %s" % [String(TRIG_WORD.get(trig, "")), String(TRIG_HINT[trig])])


## Pictogramme d'une ligne de valeur (« Explosion : 3 dégâts », « Garde : 1,2 s »…), d'après ses mots.
static func stat_icon(txt: String) -> String:
	var t := txt.to_lower()
	if t.contains("cœur"):
		return "heart_plus"
	if t.contains("dégât") or t.contains("×"):
		return "t_hit"
	if t.contains("ennemi") or t.contains("cible"):
		return "t_multi"
	if t.ends_with(" s") or t.contains(" s ") or t.contains("ralenti") or t.contains("invincible"):
		return "hourglass"
	if t.ends_with(" m") or t.contains(" m ") or t.contains("portée") or t.contains("trait"):
		return "long_stroke"
	if t.contains("%"):
		return "t_luck"
	return "t_always"


## Dégâts en pourcentage d'un coup de sabre (1 dégât = 100 %) : « 0,8 dégât » -> « 80 % des dégâts ».
static var _dmg_re: RegEx = null


static func dmg_pct(txt: String) -> String:
	if _dmg_re == null:
		_dmg_re = RegEx.new()
		_dmg_re.compile("([0-9]+(?:,[0-9]+)?) dégâts?")
	var out := txt
	for m in _dmg_re.search_all(txt):
		var f := m.get_string(1).replace(",", ".").to_float()
		out = out.replace(m.get_string(0), "%d %% des dégâts" % int(roundf(f * 100.0)))
	return out

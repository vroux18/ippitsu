extends RefCounted
## Râtelier des pinceaux (maquette Depart.dc.html, validée) : la barre de bois et ses embouts, les cinq pinceaux
## pendus (manche, virole, pointe propre à chacun ; le choisi porte un cordon vermillon), et les sceaux hanko des
## aspects. Partagé par l'écran AVANT LE DÉPART (departure.gd) et l'onglet PINCEAUX de l'Atelier (refuge.gd).
##
## Repère de la maquette : un pinceau est dessiné autour de son point d'attache `o` (écran), chaque unité de la
## maquette valant `s` pixels (x et y à part : l'écran de départ resserre la hauteur) ; `k` : échelle des traits.
## Un pinceau à gagner est « au lavis » : ses couleurs posées à l'opacité `op` sur le papier `paper`.

const Gear = preload("res://scripts/gear_data.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

const SUMI := Color("#1B1A1E")
const WOOD := Color("#6B4A2B")
const WOOD_HI := Color("#8C6640")
const WOOD_DARK := Color("#4A3220")
const CORD := Color("#C8322A")
const GOLD := Color("#C49A45")
const GREY := Color("#8A8070")
const SEAL := Color("#C8322A")
const SEAL_EDGE := Color("#8E1F17")
const PAPER_HI := Color("#F7F0DF")
const DASH := Color("#B3A78F")
## Manche (couleur, demi-largeur) et forme de la pointe de chaque pinceau pendu.
const HANDLE := {"fude": [Color("#C9A86A"), 3.6], "hake": [Color("#8C6640"), 5.0], "menso": [Color("#3C3A36"), 2.6],
	"warefude": [Color("#B9A27A"), 3.6], "chi": [Color("#6E1E16"), 3.6]}
## Nom affiché et devise de chaque pinceau (maquette) ; règles et aspects restent dans gear_data.
const TAG := {"fude": ["FUDE", "LE PINCEAU DU MAÎTRE"], "hake": ["HAKE", "LE PINCEAU LARGE"],
	"menso": ["MENSO", "LE PINCEAU FIN"], "warefude": ["WAREFUDE", "LE PINCEAU FENDU"], "chi": ["CHI-FUDE", "LE CALAME DE SANG"]}
## Écart (unités de la maquette) entre deux pinceaux pendus, et demi-longueur de la barre.
const STEP := 70.0
const BAR_HW := 177.0


## [nom, devise] du pinceau `id`.
static func tag(id: String) -> Array:
	if TAG.has(id):
		return TAG[id]
	var bd: Dictionary = Gear.brush(id)
	return [String(bd["name"]), String(bd["sub"]).to_upper()]


static func _fade(c: Color, op: float, paper: Color) -> Color:
	return paper.lerp(c, op) if op < 1.0 else c


static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t


## Courbe de Bézier ajoutée à `pts` (sans son premier point).
static func _cub(pts: PackedVector2Array, p1: Vector2, p2: Vector2, p3: Vector2, n := 10) -> void:
	var p0 := pts[pts.size() - 1]
	for i in range(1, n + 1):
		pts.append(_bez(p0, p1, p2, p3, float(i) / float(n)))


## Points de la maquette (autour de `o`, à l'échelle `s`) vers l'écran.
static func _map(pts: PackedVector2Array, o: Vector2, s: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = o + pts[i] * s
	return out


## Rectangle arrondi centré en `c` (écran ; demi-largeur, demi-hauteur, rayon : unités de la maquette), tourné de
## `rot`, en points de l'écran.
static func _rrect(hw: float, hh: float, r: float, c: Vector2, s: Vector2, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [Vector2(hw - r, -hh + r), Vector2(hw - r, hh - r), Vector2(-hw + r, hh - r), Vector2(-hw + r, -hh + r)]
	for q in 4:
		for i in 5:
			var ang := -PI / 2.0 + PI / 2.0 * float(q) + PI / 2.0 * float(i) / 4.0
			pts.append(((cs[q] as Vector2) + Vector2.from_angle(ang) * r).rotated(rot))
	return _map(pts, c, s)


static func _ring(ci: CanvasItem, loop: PackedVector2Array, col: Color, w: float) -> void:
	var cl := loop.duplicate()
	cl.append(loop[0])
	ci.draw_polyline(cl, col, w, true)


## Contour en tirets le long d'une boucle (px).
static func dashed(ci: CanvasItem, loop: PackedVector2Array, col: Color, w: float, on: float, off: float) -> void:
	var acc := 0.0
	var n := loop.size()
	for i in n:
		var a := loop[i]
		var b := loop[(i + 1) % n]
		var l := a.distance_to(b)
		var t := 0.0
		while t < l:
			var ph := fmod(acc + t, on + off)
			var step := minf(l - t, (on - ph) if ph < on else (on + off - ph))
			if ph < on:
				ci.draw_line(a.lerp(b, t / l), a.lerp(b, (t + step) / l), col, w, true)
			t += maxf(step, 0.01)
		acc += l


## Pictogrammes des aspects (gabarit 32 × 32, tracés SVG comme ui_icons.gd, rasterisés par UiKit.draw_path) :
## [tracé principal, rempli ?, second tracé au trait seul]. Chacun illustre l'effet de l'aspect, lisible à ~40 px.
const ASPECT_PICTO := {
	# Fude : le trait de référence ; le trait qui sèche en gouttes ; les souffles du vent (icône elements/vent)
	"fude:0": ["M5 26 C 8 17, 15 10, 27 5 C 20 12, 13 19, 9 27 Z", true, ""],
	"fude:1": ["M8.5 13 c2.3 3.5 3.5 5.2 3.5 7 a3.5 3.5 0 0 1 -7 0 c0 -1.8 1.2 -3.5 3.5 -7 Z M23.5 13 c2.3 3.5 3.5 5.2 3.5 7 a3.5 3.5 0 0 1 -7 0 c0 -1.8 1.2 -3.5 3.5 -7 Z M16 19 c2.3 3.5 3.5 5.2 3.5 7 a3.5 3.5 0 0 1 -7 0 c0 -1.8 1.2 -3.5 3.5 -7 Z",
		true, "M4 8 C 12 4.5, 20 4.5, 28 8"],
	"fude:2": ["M4 12 H19 C25 12 26 5 21.5 5 C18.5 5 17.5 8.5 20 10 M4 19 H23 C29 19 29 27 24 27 C21 27 20.5 23.5 23 22.5", false, ""],
	# Hake : la large bande ; le mur qui arrête les projectiles ; le balai qui repousse
	"hake:0": ["M4 10 C 11 7.5, 21 7.5, 28 9 L27 23 C 20 25.5, 10 25.5, 5 24 Z", true, ""],
	"hake:1": ["M21 4 L22.5 28", false, "M3 10 H15 M3 16 H16 M3 22 H15 M11.5 6.5 L15 10 L11.5 13.5 M11.5 18.5 L15 22 L11.5 25.5"],
	"hake:2": ["M4 16 H22", false, "M17 10 L24 16 L17 22 M5 9 H10 M4 23 H9 M27 10 V22"],
	# Menso : le trait fin et son critique au centre ; l'aiguille qui déclenche la technique ; le fil qui enfile
	"menso:0": ["M5 27 L27 5", false, "M16 16 m-4.5 0 a4.5 4.5 0 1 0 9 0 a4.5 4.5 0 1 0 -9 0"],
	"menso:1": ["M26 6 L27.5 2.5 L29 6 L32.5 7.5 L29 9 L27.5 12.5 L26 9 L22.5 7.5 Z", true, "M4 28 L24 8"],
	"menso:2": ["M8 16 m-3 0 a3 3 0 1 0 6 0 a3 3 0 1 0 -6 0 M16 16 m-3 0 a3 3 0 1 0 6 0 a3 3 0 1 0 -6 0 M24 16 m-3 0 a3 3 0 1 0 6 0 a3 3 0 1 0 -6 0",
		false, "M2 16 H5 M11 16 H13 M19 16 H21 M27 16 H30"],
	# Warefude : deux lignes ; les jumelles qui s'écartent ; la tresse qui se croise
	"warefude:0": ["M5 21 L21 5 M11 27 L27 11", false, ""],
	"warefude:1": ["M4 14 C 12 14, 19 10, 28 5 M4 18 C 12 18, 19 22, 28 27", false, ""],
	"warefude:2": ["M4 10 C 10 10, 12 22, 16 22 C 20 22, 22 10, 28 10 M4 22 C 10 22, 12 10, 16 10 C 20 10, 22 22, 28 22", false, ""],
	# Calame de sang : la goutte sous le trait ; le demi-cœur rendu ; le démon
	"chi:0": ["M16 13 c3 4.5 4.5 7 4.5 9.5 a4.5 4.5 0 0 1 -9 0 c0 -2.5 1.5 -5 4.5 -9.5 Z", true, "M5 9 C 12 5, 20 5, 28 8"],
	"chi:1": ["M14 28 C 5 21, 2.5 16.5, 5 12 C 7.5 8.5, 12 9.5, 14 13 C 16 9.5, 20.5 8.5, 23 12 C 25.5 16.5, 23 21, 14 28 Z", false, "M14 13 V28 M26 4.5 V12.5 M22 8.5 H30"],
	"chi:2": ["M16 19 m-8 0 a8 8 0 1 0 16 0 a8 8 0 1 0 -16 0", false, "M10.5 13 L7 4 M21.5 13 L25 4 M11.5 18 L15 20.5 M20.5 18 L17 20.5"],
}
const PICTO_SW := 2.6  # épaisseur du trait des pictogrammes (unités du gabarit)
const LOCK_INK := Color("#6A5F50")


## Pictogramme de l'aspect `k` du pinceau `id`, centré en `c`, de `sz` px, à l'encre `col`.
static func aspect_picto(ci: CanvasItem, id: String, k: int, c: Vector2, sz: float, col: Color, a := 1.0) -> void:
	var key := "%s:%d" % [id, k]
	if not ASPECT_PICTO.has(key):
		return
	var pd: Array = ASPECT_PICTO[key]
	var filled := bool(pd[1])
	UiKit.draw_path(ci, String(pd[0]), 32, c, sz, col, PICTO_SW * (0.6 if filled else 1.0), col if filled else Color(0, 0, 0, 0), a, String(pd[2]))


## Sceau hanko d'un aspect (cartouches de l'Atelier), centré en `c` (écran), `s` px par unité (sceau de 58) :
## vermillon cerné, liseré de papier, pictogramme de l'effet en papier s'il est acquis ; contour en tirets,
## pictogramme grisé et cadenas en coin s'il reste à gagner (le cadre d'or du choisi est celui de la carte).
static func aspect_seal(ci: CanvasItem, c: Vector2, s: float, rot: float, id: String, k: int, own: bool, a := 1.0) -> void:
	var sv := Vector2(s, s)
	var outer := _rrect(29, 29, 7, c, sv, rot)
	if own:
		ci.draw_colored_polygon(outer, Color(SEAL, a))
		_ring(ci, outer, Color(SEAL_EDGE, a), maxf(1.0, s))
		_ring(ci, _rrect(24.5, 24.5, 4, c, sv, rot), Color(PAPER_HI, 0.55 * a), maxf(1.0, s))
		aspect_picto(ci, id, k, c, 46.0 * s, PAPER_HI, a)
	else:
		ci.draw_colored_polygon(outer, Color(PAPER_HI, 0.35 * a))
		dashed(ci, outer, Color(DASH, a), 1.6 * s, 5.0 * s, 4.0 * s)
		aspect_picto(ci, id, k, c, 46.0 * s, DASH, 0.9 * a)
		# cadenas en coin : petit disque de papier sur le sceau
		var lc := c + Vector2(24.0, 24.0) * s
		ci.draw_circle(lc, 11.0 * s, Color(PAPER_HI, a))
		ci.draw_arc(lc, 11.0 * s, 0.0, TAU, 24, Color(DASH, a), maxf(1.0, s), true)
		UiKit.draw_icon(ci, "interface/cadenas", lc, 17.0 * s, a, LOCK_INK)


## Barre de bois du râtelier centrée en `c` (écran, axe de la barre), embouts sombres aux deux bouts.
static func rack(ci: CanvasItem, c: Vector2, s: Vector2, k: float, a := 1.0) -> void:
	ci.draw_colored_polygon(_rrect(BAR_HW, 4.5, 4, c, s), Color(WOOD, a))
	ci.draw_colored_polygon(_rrect(BAR_HW, 1.5, 1.5, c + Vector2(0, -3) * s, s), Color(WOOD_HI, a))
	ci.draw_circle(c + Vector2(-BAR_HW + 6.0, -0.5) * s, 7.0 * k, Color(WOOD_DARK, a))
	ci.draw_circle(c + Vector2(BAR_HW - 6.0, -0.5) * s, 7.0 * k, Color(WOOD_DARK, a))


## Un pinceau pendu, attaché en `o` (écran) : crochet, cordon vermillon s'il est choisi, manche, virole, pointe.
## `opn` : acquis (sinon manche gris) ; `op` : opacité au lavis sur `paper`.
static func brush(ci: CanvasItem, id: String, o: Vector2, s: Vector2, k: float, sel: bool, opn: bool, op: float, paper: Color) -> void:
	var hd: Array = HANDLE.get(id, HANDLE["fude"])
	var hl := float(hd[1])
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var wd := _fade(WOOD_DARK, op, paper)
	ci.draw_line(P.call(0, -40), P.call(0, -26), wd, 1.5 * k, true)
	ci.draw_arc(P.call(0, -41), 2.5 * k, 0.0, TAU, 16, wd, 1.5 * k, true)
	if sel:
		var cord := _fade(CORD, op, paper)
		ci.draw_colored_polygon(_map(PackedVector2Array([Vector2(-6, -33), Vector2(0, -27), Vector2(6, -33), Vector2(0, -39)]), o, s), cord)
		ci.draw_line(P.call(-3, -27), P.call(-5, -18), cord, 1.6 * k, true)
		ci.draw_line(P.call(3, -27), P.call(5, -18), cord, 1.6 * k, true)
	var hcol := _fade(hd[0] if opn else GREY, op, paper)
	ci.draw_colored_polygon(_map(PackedVector2Array([Vector2(-hl, -26), Vector2(hl, -26), Vector2(hl + 0.4, 44), Vector2(-hl - 0.4, 44)]), o, s), hcol)
	for ny in [-6.0, 18.0]:
		ci.draw_line(P.call(-hl, ny), P.call(hl, ny), hcol.darkened(0.25), 1.6 * k, true)
	var fcol := _fade(GOLD if id == "chi" else Color("#2A2A2E"), op, paper)
	var tcol := _fade(Color("#4A0F0A") if id == "chi" else SUMI, op, paper)
	var fer: PackedVector2Array
	var tip := PackedVector2Array()
	match id:
		"hake":
			fer = PackedVector2Array([Vector2(-12, 44), Vector2(12, 44), Vector2(12, 52), Vector2(-12, 52)])
			tip.append_array([Vector2(-12, 52), Vector2(12, 52), Vector2(11, 74)])
			_cub(tip, Vector2(6, 78), Vector2(-6, 78), Vector2(-11, 74), 8)
		"menso":
			fer = PackedVector2Array([Vector2(-3.4, 44), Vector2(3.4, 44), Vector2(3.6, 50), Vector2(-3.6, 50)])
			tip.append(Vector2(-3.6, 50))
			_cub(tip, Vector2(-4, 62), Vector2(-1.5, 74), Vector2(0, 84), 10)
			_cub(tip, Vector2(1.5, 74), Vector2(4, 62), Vector2(3.6, 50), 10)
		"warefude":
			fer = PackedVector2Array([Vector2(-5, 44), Vector2(5, 44), Vector2(5.4, 51), Vector2(-5.4, 51)])
			# deux touffes (le pinceau fendu) : chacune son polygone
			var ta := PackedVector2Array([Vector2(-5.4, 51)])
			_cub(ta, Vector2(-7, 60), Vector2(-6, 68), Vector2(-4, 76), 8)
			_cub(ta, Vector2(-2, 70), Vector2(-0.6, 62), Vector2(-0.4, 54), 8)
			ta.append(Vector2(0, 51))
			var tb := PackedVector2Array([Vector2(0, 51), Vector2(0.4, 54)])
			_cub(tb, Vector2(0.6, 62), Vector2(2, 70), Vector2(4, 76), 8)
			_cub(tb, Vector2(6, 68), Vector2(7, 60), Vector2(5.4, 51), 8)
			ci.draw_colored_polygon(_map(fer, o, s), fcol)
			ci.draw_colored_polygon(_map(ta, o, s), tcol)
			ci.draw_colored_polygon(_map(tb, o, s), tcol)
			return
		_:
			fer = PackedVector2Array([Vector2(-4.6, 44), Vector2(4.6, 44), Vector2(5, 51), Vector2(-5, 51)])
			tip.append(Vector2(-5, 51))
			_cub(tip, Vector2(-8, 60), Vector2(-4, 72), Vector2(0, 80), 10)
			_cub(tip, Vector2(4, 72), Vector2(8, 60), Vector2(5, 51), 10)
	ci.draw_colored_polygon(_map(fer, o, s), fcol)
	ci.draw_colored_polygon(_map(tip, o, s), tcol)

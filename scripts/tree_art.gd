extends RefCounted
## Arbre du pinceau peint à l'encre (maquette validée « Arbre du pinceau », téléphone 390 × 844) : toute la géométrie
## est dans le repère de la maquette (abscisses 0..390, ordonnées du groupe des branches, la maquette le décale de 128).
## Quatre branches en courbes de Bézier, nœuds posés à abscisse curviligne égale (at() à partir de S0), tracés au pinceau
## effilés (stroke()) précalculés en maillages : rien n'est recalculé à chaque image (l'encre d'une branche ne se
## recalcule que lorsqu'un nœud s'apprend, et pendant l'animation de l'achat).

const GY := 128.0  # décalage vertical du groupe des branches dans la maquette
const TOP := -28.0  # bord bas du bandeau du haut (y 100 de la maquette)
const BOTTOM := 570.0  # bord haut du panneau du bas (y 698 de la maquette)
const WIDTH := 390.0
# noms des branches : LAME et VOIE comme la maquette ; ENCRE et PAPIER remontés (à 118,384 / 274,384, ils passaient
# sous les sceaux des étages 2 de LAME et VOIE une fois l'arbre tassé à la hauteur du jeu)
const BR := {
	"lame": {"P": [Vector2(188, 462), Vector2(100, 440), Vector2(22, 340), Vector2(46, 40)], "w": Vector2(12, 3.2), "lab": Vector2(66, 470)},
	"encre": {"P": [Vector2(192, 392), Vector2(140, 340), Vector2(110, 200), Vector2(140, 8)], "w": Vector2(10, 3), "lab": Vector2(113, 352)},
	"papier": {"P": [Vector2(198, 392), Vector2(250, 340), Vector2(280, 200), Vector2(250, 8)], "w": Vector2(10, 3), "lab": Vector2(277, 352)},
	"voie": {"P": [Vector2(202, 462), Vector2(290, 440), Vector2(368, 340), Vector2(344, 40)], "w": Vector2(12, 3.2), "lab": Vector2(326, 470)},
}
const S0 := {"lame": 0.14, "voie": 0.14, "encre": 0.16, "papier": 0.16}
const SEED := {"lame": 8, "encre": 15, "papier": 22, "voie": 29}  # graine du tracé (maquette : 1 + 7 par branche)
const TRUNK := [Vector2(195, 575), Vector2(192, 510), Vector2(198, 450), Vector2(195, 380)]
const ROOT := Vector2(195, 540)
const PURSE := Vector2(34, 524)  # la Bourse, hors de l'arbre : au pied, à gauche
const SUN := Vector2(318, 40)
const SUN_R := 46.0
const TWIGS := [0.32, 0.62]

static var _node_t := {}  # id -> paramètre t de la courbe
static var _trunk: ArrayMesh
static var _faint := {}  # branche -> maillage au lavis (toute la branche)
static var _ink := {}  # branche -> [t du dernier nœud appris, maillage]
static var _twigs: Array = []  # [branche, t, maillage]
static var _fibers: Array = []  # [de, à, épaisseur, opacité]
static var _ground := PackedVector2Array()
static var _enso := {}  # rayon -> maillage de l'ensō (cercle ouvert à peine tracé)


static func bez(P: Array, t: float) -> Vector2:
	var u := 1.0 - t
	var p0: Vector2 = P[0]
	var p1: Vector2 = P[1]
	var p2: Vector2 = P[2]
	var p3: Vector2 = P[3]
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


## Paramètre t de la courbe à la fraction s de sa longueur.
static func at(P: Array, s: float) -> float:
	var n := 120
	var L := PackedFloat32Array([0.0])
	var prev := bez(P, 0.0)
	for i in range(1, n + 1):
		var q := bez(P, float(i) / float(n))
		L.append(L[i - 1] + q.distance_to(prev))
		prev = q
	var tg := s * L[n]
	for i in range(1, n + 1):
		if L[i] >= tg:
			var d := L[i] - L[i - 1]
			var f := (tg - L[i - 1]) / (d if d > 0.0 else 1.0)
			return (float(i - 1) + f) / float(n)
	return 1.0


static func rnd(i: float) -> float:
	var s := sin(i * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)


## Paramètre t d'un nœud sur sa branche (étages 1..7 à abscisse curviligne égale à partir de S0).
static func node_t(b: String, tier: int) -> float:
	var key := "%s%d" % [b, tier]
	if not _node_t.has(key):
		var s0: float = S0[b]
		_node_t[key] = at(BR[b]["P"], s0 + float(tier - 1) * ((1.0 - s0) / 6.0))
	return _node_t[key]


static func node_pos(b: String, tier: int) -> Vector2:
	return bez(BR[b]["P"], node_t(b, tier))


## Trait de pinceau effilé le long de la courbe (de t0 à t1, largeur w0 -> w1, bord qui ondule) : maillage en bande.
static func stroke(P: Array, w0: float, w1: float, t0: float, t1: float, sd: int) -> ArrayMesh:
	var n := 36
	var tris := PackedVector2Array()
	var pl := Vector2.ZERO
	var pr := Vector2.ZERO
	for i in n + 1:
		var t := t0 + (t1 - t0) * float(i) / float(n)
		var a := bez(P, maxf(0.0, t - 0.01))
		var b := bez(P, minf(1.0, t + 0.01))
		var p := bez(P, t)
		var d := (b - a).normalized()
		var wob := 1.0 + 0.18 * sin(t * 23.0 + float(sd)) + 0.1 * (rnd(float(sd * 50 + i)) - 0.5)
		var w := (w0 + (w1 - w0) * t) * wob / 2.0
		var l := Vector2(p.x - d.y * w, p.y + d.x * w)
		var r := Vector2(p.x + d.y * w, p.y - d.x * w)
		if i > 0:
			tris.append_array([pl, pr, l, pr, r, l])
		pl = l
		pr = r
	return _mesh(tris)


static func _mesh(tris: PackedVector2Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = tris
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func trunk() -> ArrayMesh:
	if _trunk == null:
		_trunk = stroke(TRUNK, 30.0, 15.0, 0.0, 1.0, 3)
	return _trunk


static func faint(b: String) -> ArrayMesh:
	if not _faint.has(b):
		var w: Vector2 = BR[b]["w"]
		_faint[b] = stroke(BR[b]["P"], w.x, w.y, 0.0, 1.0, int(SEED[b]))
	return _faint[b]


## Encre pleine de la branche jusqu'au paramètre last (dernier nœud appris) ; mise en cache pour ce last.
static func ink(b: String, last: float) -> ArrayMesh:
	if last <= 0.0:
		return null
	var c: Array = _ink.get(b, [])
	if c.is_empty() or absf(float(c[0]) - last) > 0.0001:
		var w: Vector2 = BR[b]["w"]
		c = [last, stroke(BR[b]["P"], w.x, w.x + (w.y - w.x) * last, 0.0, last, int(SEED[b]))]
		_ink[b] = c
	return c[1]


## Brindilles décoratives (deux par branche) : [branche, t, maillage].
static func twigs() -> Array:
	if _twigs.is_empty():
		for b in BR:
			var P: Array = BR[b]["P"]
			for j in TWIGS.size():
				var tt: float = TWIGS[j]
				var p := bez(P, tt)
				var p3: Vector2 = P[3]
				var side := (1.0 if j % 2 == 1 else -1.0) * (-1.0 if p3.x < 195.0 else 1.0)
				var P2 := [p, p + Vector2(side * 10.0, -6.0), p + Vector2(side * 20.0, -14.0), p + Vector2(side * 26.0, -26.0)]
				_twigs.append([b, tt, stroke(P2, 3.2, 0.6, 0.0, 1.0, int(SEED[b]) + j)])
	return _twigs


## Fibres du washi : [de, à, épaisseur, opacité] (repère du groupe des branches).
static func fibers() -> Array:
	if _fibers.is_empty():
		for i in 46:
			var x := rnd(float(i)) * 390.0
			var y := 100.0 + rnd(float(i + 99)) * 600.0 - GY
			var a := rnd(float(i + 7)) * 3.1
			var l := 6.0 + rnd(float(i + 3)) * 18.0
			_fibers.append([Vector2(x, y), Vector2(x + cos(a) * l, y + sin(a) * l), 0.6 + rnd(float(i + 5)), 0.25 + 0.3 * rnd(float(i + 11))])
	return _fibers


## Sol (lavis plus soutenu au pied de l'arbre), contour fermé.
static func ground() -> PackedVector2Array:
	if _ground.is_empty():
		var segs := [
			[Vector2(0, 690), Vector2(70, 672), Vector2(130, 680), Vector2(195, 676)],
			[Vector2(195, 676), Vector2(260, 672), Vector2(320, 682), Vector2(390, 672)],
		]
		for sg in segs:
			for i in 17:
				var q: Vector2 = bez(sg, float(i) / 16.0)
				_ground.append(q - Vector2(0, GY))
		_ground.append(Vector2(390, 844 - GY))
		_ground.append(Vector2(0, 844 - GY))
	return _ground


## Bord déchiré d'un bandeau : points (x 0..1 de la largeur, décalage vertical en unités de maquette).
static func torn(top: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segs: Array
	if top:
		# bas du bandeau du haut : M0 100 C70 94 130 106 195 98 C240 92 300 104 390 96 (tracé à l'envers dans la maquette)
		segs = [[Vector2(0, 100), Vector2(70, 94), Vector2(130, 106), Vector2(195, 98)],
			[Vector2(195, 98), Vector2(240, 92), Vector2(300, 104), Vector2(390, 96)]]
	else:
		# haut du panneau du bas : M0 14 C40 6 80 16 120 9 C170 2 210 14 260 7 C310 1 350 12 390 6
		segs = [[Vector2(0, 14), Vector2(40, 6), Vector2(80, 16), Vector2(120, 9)],
			[Vector2(120, 9), Vector2(170, 2), Vector2(210, 14), Vector2(260, 7)],
			[Vector2(260, 7), Vector2(310, 1), Vector2(350, 12), Vector2(390, 6)]]
	for sg in segs:
		for i in 13:
			if i == 0 and not pts.is_empty():
				continue
			var q: Vector2 = bez(sg, float(i) / 12.0)
			pts.append(Vector2(q.x / WIDTH, q.y))
	return pts


## Ensō d'un nœud à venir (rayon r) : 86 % du cercle, à peine tracé, plus épais au milieu du geste.
static func enso(r: float) -> ArrayMesh:
	if not _enso.has(r):
		var tris := PackedVector2Array()
		var n := 40
		var a0 := deg_to_rad(-70.0)
		var span := TAU * 0.86
		var pl := Vector2.ZERO
		var pr := Vector2.ZERO
		for i in n + 1:
			var f := float(i) / float(n)
			var a := a0 + span * f
			var w := 0.25 + 0.55 * sin(PI * minf(1.0, f * 1.1))
			var d := Vector2.from_angle(a)
			var l := d * (r + w)
			var rr := d * (r - w)
			if i > 0:
				tris.append_array([pl, pr, l, pr, rr, l])
			pl = l
			pr = rr
		_enso[r] = _mesh(tris)
	return _enso[r]
